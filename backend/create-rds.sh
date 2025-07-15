#!/bin/bash

# Create Amazon RDS PostgreSQL Server for MoodTracker
# This script creates an RDS instance using your .env configuration

echo "🎯 Creating Amazon RDS PostgreSQL Server"
echo "========================================"

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

# Read database configuration from .env file
if [ -f ".env" ]; then
    DB_USER=$(grep DB_USER .env | cut -d'=' -f2)
    DB_PASSWORD=$(grep DB_PASSWORD .env | cut -d'=' -f2)
    DB_NAME=$(grep DB_NAME .env | cut -d'=' -f2)
    echo "✅ Database configuration loaded from .env"
else
    echo "❌ .env file not found. Please ensure your environment configuration exists."
    exit 1
fi

# RDS Configuration
DB_INSTANCE_ID="moodtracker-rds"
DB_CLASS="db.t3.micro"
ALLOCATED_STORAGE="20"
ENGINE_VERSION="14.12"

echo ""
echo "📋 RDS Configuration:"
echo "   Instance ID: $DB_INSTANCE_ID"
echo "   Database Name: $DB_NAME"
echo "   Username: $DB_USER"
echo "   Instance Class: $DB_CLASS"
echo "   Storage: ${ALLOCATED_STORAGE}GB"
echo "   Engine: PostgreSQL $ENGINE_VERSION"
echo ""

# Check if RDS instance already exists
echo "🔍 Checking if RDS instance already exists..."
aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "⚠️  RDS instance '$DB_INSTANCE_ID' already exists!"
    echo "   To delete it first, run: aws rds delete-db-instance --db-instance-identifier $DB_INSTANCE_ID --skip-final-snapshot"
    exit 1
fi

# Get VPC information
echo "🔍 Getting VPC information..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)
if [ "$VPC_ID" = "None" ] || [ "$VPC_ID" = "" ]; then
    VPC_ID=$(aws ec2 describe-vpcs --query 'Vpcs[0].VpcId' --output text)
fi
echo "   Using VPC: $VPC_ID"

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
        echo "   Added access rule for your IP: $CURRENT_IP"
    fi
fi
echo "   Using security group: $SG_ID"

# Get or create DB subnet group
echo "🔍 Setting up DB subnet group..."
SUBNET_GROUP_NAME="moodtracker-subnet-group"
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
        --db-subnet-group-description "Subnet group for MoodTracker RDS" \
        --subnet-ids $SUBNETS > /dev/null 2>&1
fi
echo "   Using DB subnet group: $SUBNET_GROUP_NAME"

# Create RDS instance
echo ""
echo "🚀 Creating RDS PostgreSQL instance..."
echo "   This will take 5-10 minutes..."

aws rds create-db-instance \
    --db-instance-identifier $DB_INSTANCE_ID \
    --db-instance-class $DB_CLASS \
    --engine postgres \
    --engine-version $ENGINE_VERSION \
    --allocated-storage $ALLOCATED_STORAGE \
    --db-name $DB_NAME \
    --master-username $DB_USER \
    --master-user-password $DB_PASSWORD \
    --db-subnet-group-name $SUBNET_GROUP_NAME \
    --vpc-security-group-ids $SG_ID \
    --backup-retention-period 0 \
    --storage-encrypted \
    --publicly-accessible \
    --storage-type gp2 \
    --no-auto-minor-version-upgrade \
    --no-deletion-protection

if [ $? -eq 0 ]; then
    echo "✅ RDS instance creation initiated successfully!"
    echo ""
    echo "⏳ Waiting for RDS instance to be available..."
    echo "   Status: Creating (this takes 5-10 minutes)"
    echo "   You can check progress in AWS Console → RDS → Databases"
    
    # Wait for the instance to be available
    aws rds wait db-instance-available --db-instance-identifier $DB_INSTANCE_ID
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ RDS instance is now available!"
        
        # Get the endpoint
        ENDPOINT=$(aws rds describe-db-instances \
            --db-instance-identifier $DB_INSTANCE_ID \
            --query 'DBInstances[0].Endpoint.Address' \
            --output text)
        PORT=$(aws rds describe-db-instances \
            --db-instance-identifier $DB_INSTANCE_ID \
            --query 'DBInstances[0].Endpoint.Port' \
            --output text)
        
        echo ""
        echo "🎉 RDS Server Created Successfully!"
        echo "================================="
        echo "   Endpoint: $ENDPOINT"
        echo "   Port: $PORT"
        echo "   Database: $DB_NAME"
        echo "   Username: $DB_USER"
        echo "   Password: $DB_PASSWORD"
        echo ""
        
        # Update .env file with the endpoint
        if [ -f ".env" ]; then
            # Create backup
            cp .env .env.backup
            
            # Update DB_HOST with the actual endpoint
            sed -i.tmp "s|DB_HOST=.*|DB_HOST=$ENDPOINT|" .env
            sed -i.tmp "s|DB_PORT=.*|DB_PORT=$PORT|" .env
            
            # Clean up temporary file
            rm .env.tmp
            
            echo "✅ Updated .env file with RDS endpoint"
            echo "   (Original backed up as .env.backup)"
        fi
        
        echo ""
        echo "🎯 Next Steps:"
        echo "   1. Your .env file has been updated with the RDS endpoint"
        echo "   2. Run your backend: go run main.go"
        echo "   3. Test the API: curl http://localhost:3000/api/v1/health"
        echo ""
        echo "🔗 Connection Details:"
        echo "   host=$ENDPOINT user=$DB_USER password=$DB_PASSWORD dbname=$DB_NAME port=$PORT sslmode=require"
        
    else
        echo "❌ Timeout waiting for RDS instance to be available"
        echo "   Check AWS Console → RDS → Databases for current status"
    fi
    
else
    echo "❌ Failed to create RDS instance"
    echo ""
    echo "🔧 Common Issues:"
    echo "   - AWS Academy Lab session expired"
    echo "   - Insufficient permissions"
    echo "   - Instance name already exists"
    echo "   - VPC/subnet configuration problems"
    echo ""
    echo "💡 To delete an existing instance:"
    echo "   aws rds delete-db-instance --db-instance-identifier $DB_INSTANCE_ID --skip-final-snapshot"
fi
