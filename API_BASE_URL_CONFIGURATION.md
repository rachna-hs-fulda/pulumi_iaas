# API Base URL Configuration Guide

## Overview
This guide explains how to configure the frontend API base URL to redirect requests from `/` to `/prod/` for AWS API Gateway stage deployment.

## Current Configuration

### Backend (Go/Fiber)
The backend is configured to handle requests on both paths:
- `/api/v1/*` - For direct access
- `/prod/api/v1/*` - For API Gateway stage access

This is configured in `backend/main.go`:
```go
// Add routes to both /api and /prod/api paths
addRoutes(app.Group("/api"))
addRoutes(app.Group("/prod/api"))
```

### Frontend (React/Vite)
The frontend uses a base URL variable that determines where API requests are sent:
- **Before**: `Na="api/v1"` → requests go to `/api/v1/*`
- **After**: `Na="/prod/api/v1"` → requests go to `/prod/api/v1/*`

## Manual Configuration

### Method 1: Direct File Edit
Edit the JavaScript file in `backend/dist/assets/index-*.js` and change:
```javascript
// FROM:
Na="api/v1"

// TO:
Na="/prod/api/v1"
```

### Method 2: Using the Update Script
Run the provided script to automatically update the API base URL:
```bash
# Use default stage (prod)
node update-api-base-url.js

# Use custom stage
API_STAGE=dev node update-api-base-url.js
```

## API Endpoints

After the change, all frontend API requests will be directed to:
- `GET /prod/api/v1/health` - Health check
- `POST /prod/api/v1/users` - Create user
- `POST /prod/api/v1/users/create-or-get` - Create or get user
- `GET /prod/api/v1/users/:id` - Get user by ID
- `GET /prod/api/v1/users?username=<username>` - Get user by username
- `GET /prod/api/v1/moods` - Get mood entries
- `POST /prod/api/v1/moods/user/:userId` - Create mood entry
- `PUT /prod/api/v1/moods/:id` - Update mood entry
- `DELETE /prod/api/v1/moods/:id` - Delete mood entry

## Testing

### Before Deployment
Test locally that both endpoints work:
```bash
# Test direct API access
curl http://localhost:3000/api/v1/health

# Test prod API access
curl http://localhost:3000/prod/api/v1/health
```

### After Deployment
Test the deployed API Gateway:
```bash
# Replace with your actual API Gateway URL
curl https://your-api-id.execute-api.region.amazonaws.com/prod/api/v1/health
```

## Troubleshooting

### Common Issues

1. **404 errors on API requests**
   - Ensure the backend is configured to handle both `/api` and `/prod/api` paths
   - Check that the frontend base URL matches the expected path

2. **CORS errors**
   - Ensure CORS is configured for the `/prod/api` path in the backend
   - Check that the API Gateway CORS settings allow the frontend domain

3. **Frontend not loading**
   - Verify static file serving is configured for both `/` and `/prod/` paths
   - Check that HTML file paths are correctly updated with the stage prefix

### Verification Commands
```bash
# Check current API base URL in frontend
grep -n "Na=" backend/dist/assets/index-*.js

# Check backend route configuration
grep -n "addRoutes" backend/main.go

# Test API endpoints
curl -v http://localhost:3000/prod/api/v1/health
```

## Notes

- The backend serves static files from both `/` and `/prod/` paths
- The `fix-html-paths.js` script handles updating HTML asset paths
- This configuration supports deployment on API Gateway with stage-based routing
- The change needs to be made each time the frontend is rebuilt, or should be configured in the frontend build process
