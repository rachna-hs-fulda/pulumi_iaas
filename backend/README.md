# MoodTracker Backend

A Go-based backend service for the MoodTracker application, built with Fiber framework and connected to Amazon RDS PostgreSQL.

## Features

- RESTful API for mood tracking
- User management
- PostgreSQL database with GORM ORM
- AWS RDS integration
- Mood statistics and analytics
- CORS support
- Environment-based configuration

## Prerequisites

- Go 1.24.3 or higher
- AWS CLI configured
- Amazon Academy Lab account
- PostgreSQL (for local testing)

## Project Structure

```
backend/
├── cmd/
│   └── test-db/        # Database connection test
├── config/
│   ├── database.go     # Database connection configuration
│   └── models.go       # Database models
├── handlers/
│   ├── mood.go         # Mood entry handlers
│   └── user.go         # User handlers
├── .env                # Environment variables
├── .env.aws            # AWS credentials
├── main.go             # Application entry point
├── create-rds.sh       # Create RDS instance script
├── check-rds.sh        # Check RDS status script
├── destroy-rds.sh      # Destroy RDS instance script
├── setup-rds.sh        # Legacy RDS setup script
└── README.md
```

## Database Setup

### Option 1: Automated RDS Creation (Recommended)

1. Ensure your database credentials are configured in `.env`
2. Run the RDS creation script:
   ```bash
   ./create-rds.sh
   ```
3. Check when it's ready:
   ```bash
   ./check-rds.sh
   ```

4. When done, clean up resources:
   ```bash
   ./destroy-rds.sh
   ```

### Option 2: Manual RDS Setup

1. Create an RDS PostgreSQL instance in AWS Console
2. Note down the endpoint, port, username, and password
3. Update the `.env` file with your database details:
   ```
   DB_HOST=your-rds-endpoint.amazonaws.com
   DB_PORT=5432
   DB_USER=your-db-username
   DB_PASSWORD=your-db-password
   DB_NAME=moodtracker
   ```

## Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   go mod download
   ```

3. Set up environment variables:
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

4. Run the application:
   ```bash
   go run main.go
   ```

## API Endpoints

### Health Check
- `GET /api/v1/health` - Check if the API is running

### User Management
- `POST /api/v1/users` - Create a new user
- `GET /api/v1/users/:id` - Get user by ID
- `GET /api/v1/users?username=<username>` - Get user by username

### Mood Tracking
- `GET /api/v1/moods?user_id=<user_id>` - Get mood entries for a user
- `POST /api/v1/moods` - Create a new mood entry
- `PUT /api/v1/moods/:id` - Update a mood entry
- `DELETE /api/v1/moods/:id` - Delete a mood entry
- `GET /api/v1/moods/stats?user_id=<user_id>&days=30` - Get mood statistics

## API Examples

### Create a User
```bash
curl -X POST http://localhost:3000/api/v1/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "johndoe",
    "email": "john@example.com"
  }'
```

### Create a Mood Entry
```bash
curl -X POST http://localhost:3000/api/v1/moods \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "1",
    "mood_rating": 8,
    "notes": "Feeling great today!",
    "tags": "happy,productive"
  }'
```

### Get Mood Statistics
```bash
curl "http://localhost:3000/api/v1/moods/stats?user_id=1&days=30"
```

## Database Models

### User
- `id` (Primary Key)
- `username` (Unique)
- `email` (Unique)
- `created_at`
- `updated_at`
- `deleted_at`

### MoodEntry
- `id` (Primary Key)
- `user_id` (Foreign Key)
- `mood_rating` (1-10 scale)
- `notes` (Optional)
- `tags` (JSON string)
- `created_at`
- `updated_at`
- `deleted_at`

## Environment Variables

```bash
# AWS Configuration
aws_access_key_id=your-access-key
aws_secret_access_key=your-secret-key
aws_session_token=your-session-token
region=us-east-1

# Database Configuration
DB_HOST=your-rds-endpoint.amazonaws.com
DB_PORT=5432
DB_USER=your-db-username
DB_PASSWORD=your-db-password
DB_NAME=moodtracker

# Application Configuration
APP_PORT=3000
APP_ENV=development
```

## Security Group Configuration

For AWS Academy Lab, ensure your RDS security group allows:
- **Inbound Rule**: PostgreSQL (port 5432) from your IP or VPC
- **Outbound Rule**: All traffic (default)

## Development

### Running in Development Mode
```bash
go run main.go
```

### Building for Production
```bash
go build -o moodtracker-backend main.go
```

### Running with Air (Hot Reload)
```bash
# Install Air
go install github.com/air-verse/air@latest

# Run with hot reload
air
```

## Testing

Test the database connection:
```bash
go run cmd/test-db/main.go
```

Test the API health:
```bash
curl http://localhost:3000/api/v1/health
```

Expected health response:
```json
{
  "status": "healthy",
  "message": "MoodTracker API is running"
}
```

## Troubleshooting

### Database Connection Issues
1. Check your `.env` file has correct database credentials
2. Verify RDS instance is running and accessible
3. Check security group rules allow port 5432
4. Ensure AWS Academy Lab session is active

### AWS Credentials Issues
1. Check `.env.aws` file has valid credentials
2. Verify AWS Academy Lab session hasn't expired
3. Run `aws sts get-caller-identity` to test credentials

### Common Errors
- **"Failed to connect to database"**: Check database credentials and network connectivity
- **"Access denied"**: Verify AWS credentials and permissions
- **"Connection timeout"**: Check security group rules and network connectivity

## License

This project is licensed under the MIT License.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request
