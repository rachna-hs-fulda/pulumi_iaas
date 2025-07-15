package config

import (
	"time"

	"gorm.io/gorm"
)

// MoodEntry represents a mood tracking entry
type MoodEntry struct {
	ID             uint           `json:"id" gorm:"primaryKey"`
	UserID         string         `json:"user_id" gorm:"not null"`
	MoodRating     int            `json:"mood_rating" gorm:"not null"` // 1-10 scale
	DayHightlight  string         `json:"day_highlight"`
	DreamType      string         `json:"dream_type"`
	DreamNotes     string         `json:"dream_notes"`
	SleepStartTime int            `json:"sleep_start_time"`
	SleepEndTime   int            `json:"sleep_end_time"`
	CreatedAt      time.Time      `json:"created_at"`
	UpdatedAt      time.Time      `json:"updated_at"`
	DeletedAt      gorm.DeletedAt `json:"deleted_at" gorm:"index"`
}

// User represents a user in the system
type User struct {
	ID        uint           `json:"id" gorm:"primaryKey"`
	Username  string         `json:"username" gorm:"unique;not null"`
	Email     string         `json:"email" gorm:"unique;not null"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `json:"deleted_at" gorm:"index"`
}
