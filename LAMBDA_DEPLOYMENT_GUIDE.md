# AWS Lambda Web Adapter Deployment Guide (AWS Academy Account)

This guide explains how to deploy the MoodTracker backend using AWS Lambda Web Adapter through Pulumi with AWS Academy account constraints.

## Architecture Overview

The deployment creates:
- **RDS PostgreSQL Instance**: Managed database for the application
- **VPC and Security Groups**: Network configuration for secure database access
- **ECR Repository**: Stores the containerized Go backend
- **Lambda Function**: Runs the Go backend using AWS Lambda Web Adapter with VPC access
- **API Gateway**: Provides HTTP endpoints routing to Lambda
- **S3 Bucket**: Serves static files from the `www` folder

## Prerequisites

1. **AWS Academy Lab** active and configured
2. **Docker** installed and running
3. **Pulumi CLI** installed
4. **Node.js** and npm/pnpm installed
5. **AWS credentials** configured in `.env.aws` file

**Note**: The RDS instance will be created automatically as part of the deployment process. You no longer need to run the `create-rds.sh` script separately.

## AWS Academy Account Considerations

AWS Academy accounts have certain limitations:
- Cannot create or modify IAM roles
- Limited permissions for some AWS services
- Session-based credentials with expiration
- Pre-configured LabRole with necessary permissions

This deployment is configured to work within these constraints by:
- Using the existing LabRole from your `.env.aws` file
- Configuring AWS provider with your session credentials
- Using simplified resource configurations

## Setup Steps

### 1. Ensure AWS Academy Lab is Active

Make sure your AWS Academy lab is active and the `.env.aws` file contains:
```bash
aws_access_key_id=YOUR_ACCESS_KEY
aws_secret_access_key=YOUR_SECRET_KEY
aws_session_token=YOUR_SESSION_TOKEN
IAM_role_arn=arn:aws:iam::ACCOUNT_ID:role/LabRole
region=us-east-1
```

### 2. Configure Database Connection

The RDS instance will be created automatically, but you can customize the database configuration:

```bash
# Optional: Customize database configuration
pulumi config set dbInstanceId "moodtracker-rds"
pulumi config set dbName "moodtracker"
pulumi config set dbUser "postgres"
pulumi config set dbPassword "your-secure-password" --secret
pulumi config set dbInstanceClass "db.t3.micro"
pulumi config set dbAllocatedStorage "20"
pulumi config set dbEngineVersion "14.12"
pulumi config set dbPort "5432"
```

If you don't set these values, the deployment will use sensible defaults.

### 3. Install Dependencies

```bash
npm install
# or
pnpm install
```

### 4. Deploy

```bash
pulumi up
```

This will:
- Read AWS credentials from `.env.aws`
- Use the existing LabRole for Lambda function
- **Create RDS PostgreSQL instance** with proper VPC configuration
- **Create security groups** for database access
- Build and push the Docker image to ECR
- Create the Lambda function with the container image and VPC access
- Set up API Gateway routing
- Deploy static files to S3

**Note**: The RDS instance creation takes 5-10 minutes. The deployment will wait for the database to be available before proceeding.

**Note**: If you get credential errors, ensure your AWS Academy lab session hasn't expired and refresh the credentials in `.env.aws`.

### 5. Test the Deployment

After deployment, test the API:

```bash
# Health check
curl https://<api-gateway-url>/api/v1/health

# Example API endpoints
curl https://<api-gateway-url>/api/v1/users
curl https://<api-gateway-url>/api/v1/moods
```

## Key Features

### AWS Lambda Web Adapter Integration

The Dockerfile includes the AWS Lambda Web Adapter:
```dockerfile
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.9.1 /lambda-adapter /opt/extensions/lambda-adapter
```

### Environment Configuration

The Lambda function is configured with:
- `AWS_LAMBDA_EXEC_WRAPPER=/opt/bootstrap` - Enables Lambda Web Adapter
- `PORT=3000` - Application port
- Database connection environment variables

### Performance Optimization

- **Memory**: 1024 MB for better performance
- **Timeout**: 60 seconds for database operations
- **Image Platform**: linux/amd64 for compatibility

## API Endpoints

Once deployed, your API will be available at:
- `GET /api/v1/health` - Health check
- `POST /api/v1/users` - Create user
- `POST /api/v1/users/create-or-get` - Create or get user
- `GET /api/v1/users/:id` - Get user by ID
- `GET /api/v1/users?username=<username>` - Get user by username
- `GET /api/v1/moods` - Get mood entries
- `POST /api/v1/moods/user/:userId` - Create mood entry
- `PUT /api/v1/moods/:id` - Update mood entry
- `DELETE /api/v1/moods/:id` - Delete mood entry

## Static Files

Static files from the `www` folder are served from S3:
- Access via the `staticUrl` output
- Files are publicly accessible

## Outputs

The deployment provides these outputs:
- `apiUrl`: API Gateway endpoint URL
- `staticUrl`: S3 static website URL
- `lambdaFunctionName`: Lambda function name
- `rdsEndpoint`: RDS instance endpoint
- `rdsPort`: RDS instance port
- `rdsUsername`: RDS username
- `rdsDbName`: Database name
- `dbConnectionString`: Full database connection string
- `vpcId`: VPC ID where resources are deployed
- `subnetIds`: Subnet IDs used for RDS

## Troubleshooting

### AWS Academy Specific Issues

1. **Credential Expiration**
   - AWS Academy sessions expire after a few hours
   - Refresh credentials in `.env.aws` from AWS Academy console
   - Re-run `pulumi up` after credential refresh

2. **Permission Denied Errors**
   - Ensure your AWS Academy lab is active
   - Check that LabRole has necessary permissions
   - Some services may be restricted in AWS Academy

3. **Region Mismatch**
   - AWS Academy typically uses `us-east-1`
   - Ensure region in `.env.aws` matches your lab region

### Common Issues

1. **Database Connection Errors**
   - Ensure RDS is accessible from Lambda
   - Check VPC configuration if RDS is in a VPC
   - Verify security group rules

2. **Container Build Failures**
   - Ensure Docker is running
   - Check Dockerfile syntax
   - Verify Go module dependencies

3. **Lambda Timeout**
   - Increase timeout if database operations are slow
   - Optimize database queries
   - Consider connection pooling

### Monitoring

- Check Lambda logs in CloudWatch
- Monitor API Gateway metrics
- Use X-Ray for distributed tracing (if enabled)

## AWS Academy Session Management

Since AWS Academy uses temporary credentials:

1. **Session Refresh**: When your session expires, update `.env.aws` with new credentials
2. **Automatic Cleanup**: Resources may be automatically cleaned up when lab ends
3. **Cost Monitoring**: AWS Academy provides limited credits, monitor usage

## Clean Up

To remove all resources:

```bash
pulumi destroy
```

**Important**: Clean up resources before your AWS Academy lab session ends to avoid potential issues.

## Security Considerations

- Database credentials are stored as Pulumi secrets
- Security groups should restrict access to necessary ports
- Consider using VPC endpoints for enhanced security
- Enable CloudTrail for audit logging

## Cost Optimization

- Lambda pricing is based on requests and execution time
- API Gateway pricing per million requests
- S3 storage costs for static files
- ECR repository storage costs

Monitor usage and adjust resources as needed.
