package handlers

import (
	"time"

	"github.com/MoodJourney/backend/config"
	"github.com/gofiber/fiber/v2"
)

// CreateUser creates a new user
func CreateUser(c *fiber.Ctx) error {
	var user config.User

	if err := c.BodyParser(&user); err != nil {
		return c.Status(400).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	// Validate required fields
	if user.Username == "" || user.Email == "" {
		return c.Status(400).JSON(fiber.Map{
			"error": "Username and email are required",
		})
	}

	// Set timestamps
	user.CreatedAt = time.Now()
	user.UpdatedAt = time.Now()

	// Save to database
	result := config.DB.Create(&user)
	if result.Error != nil {
		// Check if it's a unique constraint violation
		if result.Error.Error() == "UNIQUE constraint failed: users.username" ||
			result.Error.Error() == "UNIQUE constraint failed: users.email" {
			return c.Status(409).JSON(fiber.Map{
				"error": "User with this username or email already exists",
			})
		}
		return c.Status(500).JSON(fiber.Map{
			"error": "Failed to create user",
		})
	}

	return c.Status(201).JSON(fiber.Map{
		"success": true,
		"data":    user,
	})
}

// GetUser retrieves a user by ID
func GetUser(c *fiber.Ctx) error {
	id := c.Params("id")

	var user config.User
	result := config.DB.First(&user, id)
	if result.Error != nil {
		return c.Status(404).JSON(fiber.Map{
			"error": "User not found",
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"data":    user,
	})
}

// GetUserByUsername retrieves a user by username
func GetUserByUsername(c *fiber.Ctx) error {
	username := c.Query("username")
	if username == "" {
		return c.Status(400).JSON(fiber.Map{
			"error": "username is required",
		})
	}

	var user config.User
	result := config.DB.Where("username = ?", username).First(&user)
	if result.Error != nil {
		return c.Status(404).JSON(fiber.Map{
			"error": "User not found",
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"data":    user,
	})
}

// CreateOrGetUser creates a new user or returns existing user
func CreateOrGetUser(c *fiber.Ctx) error {
	var user config.User

	if err := c.BodyParser(&user); err != nil {
		return c.Status(400).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	// Validate required fields
	if user.Username == "" || user.Email == "" {
		return c.Status(400).JSON(fiber.Map{
			"error": "Username and email are required",
		})
	}

	// Check if user already exists by username
	var existingUser config.User
	result := config.DB.Where("username = ?", user.Username).First(&existingUser)

	if result.Error == nil {
		// User exists, return it
		return c.Status(200).JSON(fiber.Map{
			"success": true,
			"data":    existingUser,
			"message": "User already exists",
		})
	}

	// User doesn't exist, create new one
	user.CreatedAt = time.Now()
	user.UpdatedAt = time.Now()

	result = config.DB.Create(&user)
	if result.Error != nil {
		return c.Status(500).JSON(fiber.Map{
			"error": "Failed to create user",
		})
	}

	return c.Status(201).JSON(fiber.Map{
		"success": true,
		"data":    user,
		"message": "User created successfully",
	})
}
