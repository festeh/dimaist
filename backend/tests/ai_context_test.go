package main

import (
	"testing"
	"time"

	"dimaist/database"
	"dimaist/logger"
	"github.com/stretchr/testify/assert"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

// loadRecentTasks function for testing (copied from ai_text.go)
func loadRecentTasks(limit int) ([]database.Task, error) {
	var tasks []database.Task

	// Get date 30 days ago for filtering completed tasks
	thirtyDaysAgo := time.Now().AddDate(0, 0, -30)

	result := database.DB.Preload("Project").
		Where("deleted_at IS NULL").
		Where("completed_at IS NULL OR completed_at > ?", thirtyDaysAgo).
		Order("updated_at DESC").
		Limit(limit).
		Find(&tasks)

	if result.Error != nil {
		return nil, result.Error
	}

	logger.Info("Loaded recent tasks").Int("count", len(tasks)).Send()
	return tasks, nil
}

// setupTestDB creates an in-memory SQLite database for testing
func setupTestDB() (*gorm.DB, error) {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		return nil, err
	}

	// Run migrations
	err = db.AutoMigrate(&database.Project{}, &database.Task{}, &database.Audio{})
	if err != nil {
		return nil, err
	}

	return db, nil
}

// createTestTasks creates various test tasks with different states
func createTestTasks(db *gorm.DB) error {
	now := time.Now()
	thirtyDaysAgo := now.AddDate(0, 0, -30)
	fortyDaysAgo := now.AddDate(0, 0, -40)
	fiveDaysAgo := now.AddDate(0, 0, -5)

	// Create a test project
	project := database.Project{
		Name:  "Test Project",
		Color: "blue",
		Order: 1,
	}
	if err := db.Create(&project).Error; err != nil {
		return err
	}

	tasks := []database.Task{
		// Active task (should be included)
		{
			Description: "Active task",
			ProjectID:   &project.ID,
			CreatedAt:   now,
			UpdatedAt:   now,
		},
		// Recently completed task (should be included)
		{
			Description: "Recently completed task",
			ProjectID:   &project.ID,
			CompletedAt: &fiveDaysAgo,
			CreatedAt:   now,
			UpdatedAt:   now,
		},
		// Old completed task (should be excluded)
		{
			Description: "Old completed task",
			ProjectID:   &project.ID,
			CompletedAt: &fortyDaysAgo,
			CreatedAt:   now,
			UpdatedAt:   now,
		},
		// Deleted task (should be excluded)
		{
			Description: "Deleted task",
			ProjectID:   &project.ID,
			DeletedAt:   &thirtyDaysAgo,
			CreatedAt:   now,
			UpdatedAt:   now,
		},
		// Recently completed task exactly 30 days ago (should be excluded)
		{
			Description: "Task completed exactly 30 days ago",
			ProjectID:   &project.ID,
			CompletedAt: &thirtyDaysAgo,
			CreatedAt:   now,
			UpdatedAt:   now,
		},
	}

	for _, task := range tasks {
		if err := db.Create(&task).Error; err != nil {
			return err
		}
	}

	return nil
}

func TestLoadRecentTasks_FiltersByCompletionDate(t *testing.T) {
	// Setup test database
	testDB, err := setupTestDB()
	assert.NoError(t, err)

	// Create test tasks
	err = createTestTasks(testDB)
	assert.NoError(t, err)

	// Backup original DB and replace with test DB
	originalDB := database.DB
	database.DB = testDB
	defer func() {
		database.DB = originalDB
	}()

	// Call loadRecentTasks
	tasks, err := loadRecentTasks(100)
	assert.NoError(t, err)

	// We should have 2 tasks: 1 active + 1 recently completed
	assert.Len(t, tasks, 2)

	// Check task descriptions to verify correct filtering
	descriptions := make(map[string]bool)
	for _, task := range tasks {
		descriptions[task.Description] = true
	}

	// Should include active and recently completed tasks
	assert.True(t, descriptions["Active task"], "Active task should be included")
	assert.True(t, descriptions["Recently completed task"], "Recently completed task should be included")

	// Should not include old completed, deleted, or exactly 30-day-old tasks
	assert.False(t, descriptions["Old completed task"], "Old completed task should be excluded")
	assert.False(t, descriptions["Deleted task"], "Deleted task should be excluded")
	assert.False(t, descriptions["Task completed exactly 30 days ago"], "Task completed exactly 30 days ago should be excluded")
}

func TestLoadRecentTasks_ExcludesDeletedTasks(t *testing.T) {
	// Setup test database
	testDB, err := setupTestDB()
	assert.NoError(t, err)

	// Backup original DB and replace with test DB
	originalDB := database.DB
	database.DB = testDB
	defer func() {
		database.DB = originalDB
	}()

	// Create a test project
	project := database.Project{
		Name:  "Test Project",
		Color: "blue",
		Order: 1,
	}
	err = testDB.Create(&project).Error
	assert.NoError(t, err)

	now := time.Now()
	deletedTime := now.AddDate(0, 0, -1)

	// Create tasks with different deletion states
	tasks := []database.Task{
		// Active non-deleted task
		{
			Description: "Active task",
			ProjectID:   &project.ID,
			CreatedAt:   now,
			UpdatedAt:   now,
		},
		// Deleted task
		{
			Description: "Deleted task",
			ProjectID:   &project.ID,
			DeletedAt:   &deletedTime,
			CreatedAt:   now,
			UpdatedAt:   now,
		},
	}

	for _, task := range tasks {
		err := testDB.Create(&task).Error
		assert.NoError(t, err)
	}

	// Call loadRecentTasks
	loadedTasks, err := loadRecentTasks(100)
	assert.NoError(t, err)

	// Should only have 1 task (the non-deleted one)
	assert.Len(t, loadedTasks, 1)
	assert.Equal(t, "Active task", loadedTasks[0].Description)
}

func TestLoadRecentTasks_IncludesRecentlyCompletedTasks(t *testing.T) {
	// Setup test database
	testDB, err := setupTestDB()
	assert.NoError(t, err)

	// Backup original DB and replace with test DB
	originalDB := database.DB
	database.DB = testDB
	defer func() {
		database.DB = originalDB
	}()

	// Create a test project
	project := database.Project{
		Name:  "Test Project",
		Color: "blue",
		Order: 1,
	}
	err = testDB.Create(&project).Error
	assert.NoError(t, err)

	now := time.Now()
	oneDayAgo := now.AddDate(0, 0, -1)
	twentyNineDaysAgo := now.AddDate(0, 0, -29)

	// Create recently completed tasks
	tasks := []database.Task{
		{
			Description: "Task completed 1 day ago",
			ProjectID:   &project.ID,
			CompletedAt: &oneDayAgo,
			CreatedAt:   now,
			UpdatedAt:   now,
		},
		{
			Description: "Task completed 29 days ago",
			ProjectID:   &project.ID,
			CompletedAt: &twentyNineDaysAgo,
			CreatedAt:   now,
			UpdatedAt:   now,
		},
	}

	for _, task := range tasks {
		err := testDB.Create(&task).Error
		assert.NoError(t, err)
	}

	// Call loadRecentTasks
	loadedTasks, err := loadRecentTasks(100)
	assert.NoError(t, err)

	// Should have both recently completed tasks
	assert.Len(t, loadedTasks, 2)

	descriptions := make(map[string]bool)
	for _, task := range loadedTasks {
		descriptions[task.Description] = true
	}

	assert.True(t, descriptions["Task completed 1 day ago"])
	assert.True(t, descriptions["Task completed 29 days ago"])
}
