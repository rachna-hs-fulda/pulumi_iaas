#!/bin/bash

# Check RDS instance status
echo "🔍 Checking RDS Instance Status"
echo "==============================="

# Load AWS credentials
if [ -f ".env.aws" ]; then
    export AWS_ACCESS_KEY_ID=$(grep aws_access_key_id .env.aws | cut -d'=' -f2)
    export AWS_SECRET_ACCESS_KEY=$(grep aws_secret_access_key .env.aws | cut -d'=' -f2)
    export AWS_SESSION_TOKEN=$(grep aws_session_token .env.aws | cut -d'=' -f2)
    export AWS_DEFAULT_REGION=$(grep region .env.aws | cut -d'=' -f2)
fi

DB_INSTANCE_ID="moodtracker-rds"

# Check if instance exists
aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ RDS instance '$DB_INSTANCE_ID' not found"
    echo "   Run './create-rds.sh' to create it first"
    exit 1
fi

# Get instance details
STATUS=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --query 'DBInstances[0].DBInstanceStatus' --output text)
ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --query 'DBInstances[0].Endpoint.Address' --output text)
PORT=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --query 'DBInstances[0].Endpoint.Port' --output text)

echo "📋 Instance Details:"
echo "   ID: $DB_INSTANCE_ID"
echo "   Status: $STATUS"
echo "   Endpoint: $ENDPOINT"
echo "   Port: $PORT"
echo ""

case $STATUS in
    "available")
        echo "✅ RDS instance is ready!"
        echo "🚀 You can now run your backend: go run main.go"
        ;;
    "creating")
        echo "⏳ RDS instance is still being created..."
        echo "   This usually takes 5-10 minutes"
        ;;
    "modifying")
        echo "🔄 RDS instance is being modified..."
        ;;
    "backing-up")
        echo "💾 RDS instance is being backed up..."
        ;;
    "stopped")
        echo "⏸️  RDS instance is stopped"
        echo "   Start it from AWS Console → RDS → Databases"
        ;;
    *)
        echo "ℹ️  RDS instance status: $STATUS"
        ;;
esac
