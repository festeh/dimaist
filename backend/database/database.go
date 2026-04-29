package database

import (
	"dimaist/logger"
	"time"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	gormlogger "gorm.io/gorm/logger"
)

var DB *gorm.DB

// InitDBLight connects to database without running migrations (for CLI tools)
func InitDBLight(databaseURL string, showLogs bool) error {
	logMode := gormlogger.Silent
	if showLogs {
		logMode = gormlogger.Info
	}

	var err error
	DB, err = gorm.Open(postgres.Open(databaseURL), &gorm.Config{
		PrepareStmt: false,
		Logger:      gormlogger.Default.LogMode(logMode),
	})
	if err != nil {
		return err
	}
	return nil
}

func InitDB(databaseURL string) error {

	logger.Info("Connecting to database").Send()
	var err error
	DB, err = gorm.Open(postgres.Open(databaseURL), &gorm.Config{
		PrepareStmt: false,
	})
	if err != nil {
		logger.Error("Failed to connect to database").Err(err).Send()
		return err
	}

	// Configure connection pool to prevent cached plan issues
	sqlDB, err := DB.DB()
	if err != nil {
		logger.Error("Failed to get underlying sql.DB").Err(err).Send()
		return err
	}

	// Set connection pool settings to refresh connections regularly
	sqlDB.SetMaxOpenConns(25)
	sqlDB.SetMaxIdleConns(5)
	sqlDB.SetConnMaxLifetime(5 * time.Minute)  // 5 minutes
	sqlDB.SetConnMaxIdleTime(30 * time.Second) // 30 seconds

	logger.Info("Database connected successfully").Send()

	// Clear any cached prepared statements to avoid schema mismatch errors
	if err := DB.Exec("DISCARD ALL").Error; err != nil {
		logger.Warn("Failed to discard cached plans").Err(err).Send()
	} else {
		logger.Info("Cleared cached database plans").Send()
	}

	// Migrate due_date/due_datetime to unified due + has_time columns
	if err := migrateDueFields(); err != nil {
		logger.Error("Failed to migrate due fields").Err(err).Send()
		return err
	}

	// Auto-migrate the schema
	logger.Info("Running database migrations").Send()
	err = DB.AutoMigrate(&Project{}, &Task{})
	if err != nil {
		logger.Error("Failed to run database migrations").Err(err).Send()
		return err
	}

	// Install revision column, sequence, and trigger powering /sync.
	// Must run after AutoMigrate so the column exists before the trigger
	// references it.
	if err := migrateRevision(); err != nil {
		logger.Error("Failed to migrate revision").Err(err).Send()
		return err
	}

	// Attach advisory-lock callbacks to every write so /sync can read
	// against a stable revision sequence.
	if err := RegisterSyncCallbacks(DB); err != nil {
		logger.Error("Failed to register sync callbacks").Err(err).Send()
		return err
	}

	logger.Info("Database migrations completed successfully").Send()

	// Ensure Inbox project exists
	var inboxProject Project
	result := DB.Where("name = ?", "Inbox").First(&inboxProject)
	if result.Error != nil {
		if result.Error == gorm.ErrRecordNotFound {
			logger.Info("Creating default Inbox project").Send()
			inboxProject = Project{
				Name:  "Inbox",
				Color: "gray",
				Order: 1,
			}
			if err := DB.Create(&inboxProject).Error; err != nil {
				logger.Error("Failed to create Inbox project").Err(err).Send()
				return err
			}
			logger.Info("Inbox project created successfully").Send()
		} else {
			logger.Error("Failed to check for Inbox project").Err(result.Error).Send()
			return result.Error
		}
	} else {
		logger.Info("Inbox project already exists").Send()
	}

	return nil
}
