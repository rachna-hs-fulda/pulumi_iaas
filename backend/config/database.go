package config

import (
	"fmt"
	"log"
	"os"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var DB *gorm.DB

func ConnectDB() {
	var err error

	// Get database configuration from environment variables
	host := os.Getenv("DB_HOST")
	port := os.Getenv("DB_PORT")
	user := os.Getenv("DB_USER")
	password := os.Getenv("DB_PASSWORD")
	dbname := os.Getenv("DB_NAME")

	// Validate required environment variables
	if host == "" {
		log.Fatal("DB_HOST environment variable is required")
	}
	if port == "" {
		port = "5432"
	}
	if user == "" {
		log.Fatal("DB_USER environment variable is required")
	}
	if password == "" {
		log.Fatal("DB_PASSWORD environment variable is required")
	}
	if dbname == "" {
		log.Fatal("DB_NAME environment variable is required")
	}

	// Create PostgreSQL connection string for RDS
	dsn := fmt.Sprintf("host=%s user=%s password=%s dbname=%s port=%s sslmode=require TimeZone=UTC",
		host, user, password, dbname, port)

	// Log connection attempt (without password for security)
	fmt.Printf("🔗 Connecting to RDS database at %s:%s/%s as user %s\n", host, port, dbname, user)

	// Connect to database
	DB, err = gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
	})

	if err != nil {
		log.Printf("❌ Failed to connect to RDS database: %v", err)
		log.Fatal("RDS connection failed")
	}

	fmt.Println("✅ Successfully connected to Amazon RDS PostgreSQL database!")

	// Auto-migrate database schema
	err = DB.AutoMigrate(&User{}, &MoodEntry{})
	if err != nil {
		log.Printf("❌ Failed to migrate database: %v", err)
		log.Fatal("Database migration failed")
	}

	fmt.Println("✅ Database migration completed successfully!")
}
