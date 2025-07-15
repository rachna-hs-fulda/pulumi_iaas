#!/bin/bash

# Destroy Amazon RDS PostgreSQL Server and Associated Resources
# This script completely removes the RDS instance and cleans up all resources

echo "🗑️  Destroying Amazon RDS PostgreSQL Server"
echo "==========================================="

# Warning message
echo "⚠️  WARNING: This will permanently delete your RDS database!"
echo "   - All data will be lost"
echo "   - This action cannot be undone"
echo "   - Associated resources will be cleaned up"
echo ""

# Confirmation prompt
read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirmation
if [ "$confirmation" != "yes" ]; then
    echo "❌ Operation cancelled"
    exit 0
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

# Resource identifiers
DB_INSTANCE_ID="moodtracker-rds"
SG_NAME="moodtracker-rds-sg"
SUBNET_GROUP_NAME="moodtracker-subnet-group"

echo ""
echo "🔍 Checking existing resources..."

# Check if RDS instance exists
echo "   Checking RDS instance..."
RDS_EXISTS=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null)
if [ "$RDS_EXISTS" = "None" ] || [ "$RDS_EXISTS" = "" ]; then
    echo "   ℹ️  RDS instance '$DB_INSTANCE_ID' not found"
    RDS_EXISTS=""
else
    echo "   ✅ Found RDS instance: $DB_INSTANCE_ID (Status: $RDS_EXISTS)"
fi

# Check if security group exists
echo "   Checking security group..."
SG_ID=$(aws ec2 describe-security-groups --group-names $SG_NAME --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)
if [ "$SG_ID" = "None" ] || [ "$SG_ID" = "" ]; then
    echo "   ℹ️  Security group '$SG_NAME' not found"
    SG_ID=""
else
    echo "   ✅ Found security group: $SG_ID"
fi

# Check if subnet group exists
echo "   Checking DB subnet group..."
SUBNET_EXISTS=$(aws rds describe-db-subnet-groups --db-subnet-group-name $SUBNET_GROUP_NAME --query 'DBSubnetGroups[0].DBSubnetGroupName' --output text 2>/dev/null)
if [ "$SUBNET_EXISTS" = "None" ] || [ "$SUBNET_EXISTS" = "" ]; then
    echo "   ℹ️  DB subnet group '$SUBNET_GROUP_NAME' not found"
    SUBNET_EXISTS=""
else
    echo "   ✅ Found DB subnet group: $SUBNET_GROUP_NAME"
fi

# If no resources found, exit
if [ "$RDS_EXISTS" = "" ] && [ "$SG_ID" = "" ] && [ "$SUBNET_EXISTS" = "" ]; then
    echo ""
    echo "ℹ️  No MoodTracker RDS resources found to delete"
    echo "   Everything is already clean!"
    exit 0
fi

echo ""
echo "🗑️  Starting resource cleanup..."

# Step 1: Delete RDS instance
if [ "$RDS_EXISTS" != "" ]; then
    echo ""
    echo "1️⃣  Deleting RDS instance..."
    echo "   Instance: $DB_INSTANCE_ID"
    echo "   Status: $RDS_EXISTS"
    
    if [ "$RDS_EXISTS" = "available" ] || [ "$RDS_EXISTS" = "stopped" ]; then
        aws rds delete-db-instance \
            --db-instance-identifier $DB_INSTANCE_ID \
            --skip-final-snapshot \
            --delete-automated-backups
        
        if [ $? -eq 0 ]; then
            echo "   ✅ RDS deletion initiated"
            echo "   ⏳ Waiting for RDS instance to be deleted..."
            echo "      This may take 5-10 minutes..."
            
            # Wait for the instance to be deleted
            aws rds wait db-instance-deleted --db-instance-identifier $DB_INSTANCE_ID
            
            if [ $? -eq 0 ]; then
                echo "   ✅ RDS instance deleted successfully"
            else
                echo "   ⚠️  Timeout waiting for RDS deletion, but process continues..."
            fi
        else
            echo "   ❌ Failed to delete RDS instance"
        fi
    else
        echo "   ⚠️  RDS instance is in '$RDS_EXISTS' state"
        echo "      You may need to stop it first or wait for current operation to complete"
    fi
fi

# Step 2: Delete DB subnet group
if [ "$SUBNET_EXISTS" != "" ]; then
    echo ""
    echo "2️⃣  Deleting DB subnet group..."
    echo "   Subnet group: $SUBNET_GROUP_NAME"
    
    aws rds delete-db-subnet-group --db-subnet-group-name $SUBNET_GROUP_NAME
    
    if [ $? -eq 0 ]; then
        echo "   ✅ DB subnet group deleted successfully"
    else
        echo "   ⚠️  Failed to delete DB subnet group (may be in use)"
    fi
fi

# Step 3: Delete security group
if [ "$SG_ID" != "" ]; then
    echo ""
    echo "3️⃣  Deleting security group..."
    echo "   Security group: $SG_ID ($SG_NAME)"
    
    # First, try to delete any rules (if they exist)
    aws ec2 describe-security-groups --group-ids $SG_ID --query 'SecurityGroups[0].IpPermissions' --output text > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "   🔄 Removing security group rules..."
        aws ec2 revoke-security-group-ingress --group-id $SG_ID --protocol tcp --port 5432 --source-group $SG_ID > /dev/null 2>&1
        
        # Get current IP and try to remove the rule
        CURRENT_IP=$(curl -s https://checkip.amazonaws.com)
        if [ "$CURRENT_IP" != "" ]; then
            aws ec2 revoke-security-group-ingress --group-id $SG_ID --protocol tcp --port 5432 --cidr ${CURRENT_IP}/32 > /dev/null 2>&1
        fi
    fi
    
    # Now delete the security group
    aws ec2 delete-security-group --group-id $SG_ID
    
    if [ $? -eq 0 ]; then
        echo "   ✅ Security group deleted successfully"
    else
        echo "   ⚠️  Failed to delete security group (may be in use by other resources)"
    fi
fi

# Step 4: Clean up .env file
echo ""
echo "4️⃣  Cleaning up .env file..."
if [ -f ".env" ]; then
    # Create backup
    cp .env .env.backup
    
    # Reset database configuration to placeholders
    sed -i.tmp "s|DB_HOST=.*|DB_HOST=your-rds-endpoint.amazonaws.com|" .env
    sed -i.tmp "s|DB_PORT=.*|DB_PORT=5432|" .env
    
    # Clean up temporary file
    rm .env.tmp
    
    echo "   ✅ .env file reset to placeholder values"
    echo "   📁 Original backed up as .env.backup"
else
    echo "   ℹ️  .env file not found"
fi

echo ""
echo "🎉 Cleanup completed!"
echo "====================="
echo ""
echo "✅ Resources cleaned up:"
if [ "$RDS_EXISTS" != "" ]; then
    echo "   - RDS instance: $DB_INSTANCE_ID"
fi
if [ "$SUBNET_EXISTS" != "" ]; then
    echo "   - DB subnet group: $SUBNET_GROUP_NAME"
fi
if [ "$SG_ID" != "" ]; then
    echo "   - Security group: $SG_NAME"
fi
echo "   - .env file reset to placeholders"
echo ""
echo "💡 To create a new RDS instance:"
echo "   ./create-rds.sh"
echo ""
echo "🗂️  If you need to restore your .env file:"
echo "   mv .env.backup .env"
