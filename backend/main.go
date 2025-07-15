package main

import (
	"log"
	"os"

	"github.com/MoodJourney/backend/config"
	"github.com/MoodJourney/backend/handlers"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/logger"
)

func main() {
	// Load environment variables - commenting for docker run
	// if err := godotenv.Load(); err != nil {
	// 	log.Fatal("Error loading .env file")
	// }

	// Connect to RDS database
	config.ConnectDB()

	// Initialize Fiber app
	app := fiber.New()

	// Middleware
	app.Use(logger.New())
	app.Use(cors.New())

	// Serve static files from dist directory
	// Handle both root path and /prod path for API Gateway stage compatibility
	app.Static("/", "./dist")
	app.Static("/prod", "./dist")

	// Create a function to add routes to both API groups
	addRoutes := func(apiGroup fiber.Router) {
		v1 := apiGroup.Group("/v1")

		// Health check
		v1.Get("/health", func(c *fiber.Ctx) error {
			return c.JSON(fiber.Map{
				"status":  "healthy",
				"message": "MoodTracker API is running",
			})
		})

		// User routes
		users := v1.Group("/users")
		users.Post("/", handlers.CreateUser)
		users.Post("/create-or-get", handlers.CreateOrGetUser)
		users.Get("/:id", handlers.GetUser)
		users.Get("/", handlers.GetUserByUsername)

		// Mood entry routes
		moods := v1.Group("/moods")
		moods.Get("/", handlers.GetMoodEntries)
		moods.Post("/user/:userId", handlers.CreateMoodEntry)
		moods.Put("/:id", handlers.UpdateMoodEntry)
		moods.Delete("/:id", handlers.DeleteMoodEntry)
	}

	// Add routes to both /api and /prod/api paths
	addRoutes(app.Group("/api"))
	addRoutes(app.Group("/prod/api"))

	// Get port from environment or use default
	port := os.Getenv("APP_PORT")
	if port == "" {
		port = "3000"
	}

	log.Printf("Server starting on port %s", port)
	log.Fatal(app.Listen(":" + port))
}
