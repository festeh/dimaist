package database

import "time"

// SoftDelete marks a record as deleted by setting deleted_at and updated_at timestamps.
// The model must have DeletedAt and UpdatedAt fields.
// Returns the number of rows affected and any error.
func SoftDelete(model any, id uint) (int64, error) {
	now := time.Now()
	result := DB.Model(model).Where("id = ?", id).Updates(map[string]any{
		"deleted_at": now,
		"updated_at": now,
	})
	return result.RowsAffected, result.Error
}
