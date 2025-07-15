package handlers

import (
	"time"

	"github.com/MoodJourney/backend/config"
	"github.com/gofiber/fiber/v2"
)

// GetMoodEntries retrieves all mood entries for a user
func GetMoodEntries(c *fiber.Ctx) error {
	userID := c.Query("user_id")
	date := c.Query("date") // Expected format: YYYY-MM-DD

	var entries []config.MoodEntry
	query := config.DB

	// Filter by user ID if provided
	if userID != "" {
		query = query.Where("user_id = ?", userID)
	}

	// Filter by date if provided
	if date != "" {
		// Parse the date and create start and end of day
		parsedDate, err := time.Parse("2006-01-02", date)
		if err != nil {
			return c.Status(400).JSON(fiber.Map{
				"error": "Invalid date format. Use YYYY-MM-DD",
			})
		}

		startOfDay := parsedDate
		endOfDay := parsedDate.Add(24 * time.Hour)

		query = query.Where("created_at >= ? AND created_at < ?", startOfDay, endOfDay)
	}

	result := query.Find(&entries)
	if result.Error != nil {
		return c.Status(500).JSON(fiber.Map{
			"error": "Failed to retrieve mood entries",
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"data":    entries,
	})
}

// CreateMoodEntry creates a new mood entry
func CreateMoodEntry(c *fiber.Ctx) error {
	userID := c.Params("userId")
	var entry config.MoodEntry

	if err := c.BodyParser(&entry); err != nil {
		return c.Status(400).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	// Validate required fields
	if userID == "" {
		return c.Status(400).JSON(fiber.Map{
			"error": "User ID is required",
		})
	}

	// Validate mood rating
	if entry.MoodRating < 1 || entry.MoodRating > 10 {
		return c.Status(400).JSON(fiber.Map{
			"error": "Mood rating must be between 1 and 10",
		})
	}

	// Set user ID and timestamps
	entry.UserID = userID
	entry.CreatedAt = time.Now()
	entry.UpdatedAt = time.Now()

	// Save to database
	result := config.DB.Create(&entry)
	if result.Error != nil {
		return c.Status(500).JSON(fiber.Map{
			"error": "Failed to create mood entry",
		})
	}

	return c.Status(201).JSON(fiber.Map{
		"success": true,
		"data":    entry,
	})
}

// UpdateMoodEntry updates an existing mood entry
func UpdateMoodEntry(c *fiber.Ctx) error {
	id := c.Params("id")

	var entry config.MoodEntry
	result := config.DB.First(&entry, id)
	if result.Error != nil {
		return c.Status(404).JSON(fiber.Map{
			"error": "Mood entry not found",
		})
	}

	// Parse request body
	var updateData config.MoodEntry
	if err := c.BodyParser(&updateData); err != nil {
		return c.Status(400).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	// Validate mood rating if provided
	if updateData.MoodRating != 0 && (updateData.MoodRating < 1 || updateData.MoodRating > 10) {
		return c.Status(400).JSON(fiber.Map{
			"error": "Mood rating must be between 1 and 10",
		})
	}

	// Update fields
	if updateData.MoodRating != 0 {
		entry.MoodRating = updateData.MoodRating
	}
	if updateData.DayHightlight != "" {
		entry.DayHightlight = updateData.DayHightlight
	}
	if updateData.DreamType != "" {
		entry.DreamType = updateData.DreamType
	}
	if updateData.DreamNotes != "" {
		entry.DreamNotes = updateData.DreamNotes
	}
	if updateData.SleepStartTime != 0 {
		entry.SleepStartTime = updateData.SleepStartTime
	}
	if updateData.SleepEndTime != 0 {
		entry.SleepEndTime = updateData.SleepEndTime
	}
	entry.UpdatedAt = time.Now()

	// Save to database
	result = config.DB.Save(&entry)
	if result.Error != nil {
		return c.Status(500).JSON(fiber.Map{
			"error": "Failed to update mood entry",
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"data":    entry,
	})
}

// DeleteMoodEntry deletes a mood entry
func DeleteMoodEntry(c *fiber.Ctx) error {
	id := c.Params("id")

	var entry config.MoodEntry
	result := config.DB.First(&entry, id)
	if result.Error != nil {
		return c.Status(404).JSON(fiber.Map{
			"error": "Mood entry not found",
		})
	}

	// Soft delete
	result = config.DB.Delete(&entry)
	if result.Error != nil {
		return c.Status(500).JSON(fiber.Map{
			"error": "Failed to delete mood entry",
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Mood entry deleted successfully",
	})
}
