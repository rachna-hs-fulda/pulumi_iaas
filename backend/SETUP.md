# MoodTracker Backend - Quick Setup Guide

## 🚀 Quick Start

Your backend is now configured to connect to Amazon RDS! Here's what you need to do:

### Step 1: Create Your RDS Database

#### Option A: Automated RDS Creation (Recommended)
```bash
# Create RDS instance using your .env configuration
./create-rds.sh

# Check if RDS is ready
./check-rds.sh
```

#### Option B: Manual Setup
1. Go to AWS Console → RDS
2. Create a new PostgreSQL database instance
3. Update your `.env` file with the endpoint details

#### 🗑️ Cleanup (When Done)
```bash
# Completely destroy RDS instance and all resources
./destroy-rds.sh
```

### Step 2: Configure Security Groups

In AWS Console → EC2 → Security Groups:
1. Find your RDS security group
2. Add inbound rule: PostgreSQL (port 5432) from your IP or VPC

### Step 3: Start Your Application

```bash
# Start the backend server
go run main.go

# Or with hot reload
air
```

### Step 4: Test Your Database Connection

# Test health endpoint
curl http://localhost:3000/api/v1/health
```

## 📋 What's Been Set Up

### Database Models
- **User**: Stores user information
- **MoodEntry**: Tracks mood entries with ratings, notes, and tags

### API Endpoints
- `GET /api/v1/health` - Health check
- `POST /api/v1/users` - Create user
- `GET /api/v1/users/:id` - Get user by ID
- `POST /api/v1/moods` - Create mood entry
- `GET /api/v1/moods?user_id=X` - Get mood entries
- `GET /api/v1/moods/stats?user_id=X` - Get mood statistics

### Features
- ✅ PostgreSQL database with GORM
- ✅ AWS RDS integration
- ✅ Environment-based configuration
- ✅ CORS support
- ✅ Error handling
- ✅ Auto-migration
- ✅ Soft deletes
- ✅ Mood statistics

## 🔧 Troubleshooting

### "Failed to connect to database"
1. Check your `.env` file has correct credentials
2. Verify RDS instance is running
3. Check security group allows port 5432
4. Ensure AWS Academy session is active

### "Access denied"
1. Verify AWS credentials in `.env.aws`
2. Check if AWS Academy session expired
3. Run `aws sts get-caller-identity` to test

### "Connection timeout"
1. Check security group rules
2. Verify RDS endpoint URL
3. Ensure you're connecting from allowed IP

## 🎯 Next Steps

1. **Set up your RDS database** using the automated script
2. **Configure security groups** to allow database access
3. **Test the API endpoints** using curl or Postman
4. **Build your frontend** to connect to these endpoints

Backend is now ready to handle mood tracking data with Amazon RDS! 🎉

## 🧹 Cleanup

When you're done with your project and want to clean up all AWS resources:

```bash
# This will permanently delete:
# - RDS database instance
# - Security groups
# - DB subnet groups
# - Reset .env file to placeholders
./destroy-rds.sh
```

⚠️ **Warning**: This action cannot be undone and will permanently delete all your data!
