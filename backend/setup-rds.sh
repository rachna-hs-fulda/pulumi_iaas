#!/bin/bash

# MoodTracker RDS Setup Script for AWS Academy Lab
# This script helps you create and configure an RDS PostgreSQL instance

echo "🎯 MoodTracker RDS Setup for AWS Academy Lab"
echo "============================================="

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it first."
    exit 1
fi

# Load AWS credentials from .env.aws
if [ -f ".env.aws" ]; then
    export AWS_ACCESS_KEY_ID=$(grep aws_access_key_id .env.aws | cut -d'=' -f2)
    export AWS_SECRET_ACCESS_KEY=$(grep aws_secret_access_key .env.aws | cut -d'=' -f2)
    export AWS_SESSION_TOKEN=$(grep aws_session_token .env.aws | cut -d'=' -f2)
    export AWS_DEFAULT_REGION=$(grep region .env.aws | cut -d'=' -f2)
    echo "✅ AWS credentials loaded from .env.aws"
else
    echo "❌ .env.aws file not found. Please ensure your AWS credentials are configured."
    exit 1
fi

# Test AWS credentials
echo "🔍 Testing AWS credentials..."
aws sts get-caller-identity > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ AWS credentials are invalid or expired. Please check your .env.aws file."
    exit 1
fi
echo "✅ AWS credentials are valid"

# Configuration (matches database.go defaults)
DB_INSTANCE_ID="moodtracker-db"
DB_NAME="moodtracker"  # Matches default in database.go
DB_USERNAME="postgres"  # Standard PostgreSQL username
DB_PASSWORD="MoodTracker123!"
DB_CLASS="db.t3.micro"  # Free tier eligible
ALLOCATED_STORAGE="20"
ENGINE_VERSION="14.12"  # Stable PostgreSQL version

echo ""
echo "📋 Database Configuration:"
echo "   Instance ID: $DB_INSTANCE_ID"
echo "   Database Name: $DB_NAME"
echo "   Username: $DB_USERNAME"
echo "   Instance Class: $DB_CLASS"
echo "   Storage: ${ALLOCATED_STORAGE}GB"
echo "   Engine Version: $ENGINE_VERSION"
echo ""

# Get VPC information for AWS Academy Lab
echo "🔍 Getting VPC information..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)
if [ "$VPC_ID" = "None" ] || [ "$VPC_ID" = "" ]; then
    VPC_ID=$(aws ec2 describe-vpcs --query 'Vpcs[0].VpcId' --output text)
fi
echo "   Using VPC: $VPC_ID"

# Get subnet group (required for RDS)
echo "🔍 Checking for DB subnet group..."
SUBNET_GROUP_NAME="default"
aws rds describe-db-subnet-groups --db-subnet-group-name $SUBNET_GROUP_NAME > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "   Creating DB subnet group..."
    # Get subnets from different AZs
    SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].SubnetId' --output text)
    if [ "$SUBNETS" = "" ]; then
        echo "❌ No subnets found in VPC $VPC_ID"
        exit 1
    fi
    
    # Create subnet group
    aws rds create-db-subnet-group \
        --db-subnet-group-name $SUBNET_GROUP_NAME \
        --db-subnet-group-description "Default subnet group for MoodTracker" \
        --subnet-ids $SUBNETS > /dev/null 2>&1
fi
echo "   Using DB subnet group: $SUBNET_GROUP_NAME"

# Create or get security group
echo "🔍 Setting up security group..."
SG_NAME="moodtracker-rds-sg"
SG_ID=$(aws ec2 describe-security-groups --group-names $SG_NAME --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)

if [ "$SG_ID" = "None" ] || [ "$SG_ID" = "" ]; then
    echo "   Creating security group..."
    SG_ID=$(aws ec2 create-security-group \
        --group-name $SG_NAME \
        --description "Security group for MoodTracker RDS" \
        --vpc-id $VPC_ID \
        --query 'GroupId' --output text)
    
    # Add rule to allow PostgreSQL access from anywhere in VPC
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 5432 \
        --source-group $SG_ID > /dev/null 2>&1
    
    # Add rule to allow access from current IP
    CURRENT_IP=$(curl -s https://checkip.amazonaws.com)
    if [ "$CURRENT_IP" != "" ]; then
        aws ec2 authorize-security-group-ingress \
            --group-id $SG_ID \
            --protocol tcp \
            --port 5432 \
            --cidr ${CURRENT_IP}/32 > /dev/null 2>&1
        echo "   Added access rule for your current IP: $CURRENT_IP"
    fi
fi
echo "   Using security group: $SG_ID"

# Create RDS instance
echo "🚀 Creating RDS PostgreSQL instance..."
aws rds create-db-instance \
    --db-instance-identifier $DB_INSTANCE_ID \
    --db-instance-class $DB_CLASS \
    --engine postgres \
    --engine-version $ENGINE_VERSION \
    --allocated-storage $ALLOCATED_STORAGE \
    --db-name $DB_NAME \
    --master-username $DB_USERNAME \
    --master-user-password $DB_PASSWORD \
    --db-subnet-group-name $SUBNET_GROUP_NAME \
    --vpc-security-group-ids $SG_ID \
    --backup-retention-period 7 \
    --storage-encrypted \
    --publicly-accessible \
    --storage-type gp2 \
    --no-auto-minor-version-upgrade \
    --deletion-protection false

if [ $? -eq 0 ]; then
    echo "✅ RDS instance creation initiated successfully!"
    echo ""
    echo "⏳ Waiting for RDS instance to be available (this may take 5-10 minutes)..."
    echo "   You can check the status in AWS Console → RDS → Databases"
    
    # Wait for the instance to be available
    aws rds wait db-instance-available --db-instance-identifier $DB_INSTANCE_ID
    
    if [ $? -eq 0 ]; then
        echo "✅ RDS instance is now available!"
        
        # Get the endpoint
        ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --query 'DBInstances[0].Endpoint.Address' --output text)
        PORT=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --query 'DBInstances[0].Endpoint.Port' --output text)
        
        echo ""
        echo "🎉 Database connection details:"
        echo "   Endpoint: $ENDPOINT"
        echo "   Port: $PORT"
        echo "   Database: $DB_NAME"
        echo "   Username: $DB_USERNAME"
        echo "   Password: $DB_PASSWORD"
        echo "   SSL Mode: require (as configured in database.go)"
        echo ""
        
        # Update .env file with database details
        if [ -f ".env" ]; then
            # Create backup
            cp .env .env.backup
            
            # Update database configuration
            sed -i.tmp "s|DB_HOST=.*|DB_HOST=$ENDPOINT|" .env
            sed -i.tmp "s|DB_PORT=.*|DB_PORT=$PORT|" .env
            sed -i.tmp "s|DB_USER=.*|DB_USER=$DB_USERNAME|" .env
            sed -i.tmp "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASSWORD|" .env
            sed -i.tmp "s|DB_NAME=.*|DB_NAME=$DB_NAME|" .env
            
            # Clean up temporary file
            rm .env.tmp
            
            echo "✅ .env file updated with database connection details!"
            echo "   (Original backed up as .env.backup)"
        else
            echo "⚠️  .env file not found. Please create it with the database details above."
        fi
        
        echo ""
        echo "🔧 Next steps:"
        echo "   1. Test the database connection: go run main.go"
        echo "   2. Check API health: curl http://localhost:3000/api/v1/health"
        echo "   3. The database will auto-migrate tables on first connection"
        echo "   4. Security group allows access from your current IP: $(curl -s https://checkip.amazonaws.com)"
        echo ""
        echo "🔗 Connection string format (for reference):"
        echo "   host=$ENDPOINT user=$DB_USERNAME password=$DB_PASSWORD dbname=$DB_NAME port=$PORT sslmode=require"
        
    else
        echo "❌ Timeout waiting for RDS instance. Check AWS Console for status."
    fi
    
else
    echo "❌ Failed to create RDS instance. Please check the error above and try again."
    echo ""
    echo "🔧 Common issues:"
    echo "   - AWS Academy Lab session expired"
    echo "   - Insufficient permissions"
    echo "   - Instance with same name already exists"
    echo "   - VPC/subnet configuration issues"
fi
