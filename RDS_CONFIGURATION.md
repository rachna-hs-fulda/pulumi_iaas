# RDS Database Configuration Example

This file shows how to configure the RDS database creation for the MoodTracker application.

## Default Configuration

If you don't specify any configuration, the deployment will use these defaults:

```javascript
{
    instanceId: "moodtracker-rds",
    dbName: "moodtracker",
    dbUser: "postgres",
    dbPassword: "password123",
    instanceClass: "db.t3.micro",
    allocatedStorage: 20,
    engineVersion: "14.12",
    port: 5432
}
```

## Custom Configuration

You can customize the database configuration using Pulumi config:

```bash
# Database instance configuration
pulumi config set dbInstanceId "my-custom-db"
pulumi config set dbInstanceClass "db.t3.small"
pulumi config set dbAllocatedStorage "50"
pulumi config set dbEngineVersion "15.4"

# Database connection details
pulumi config set dbName "myapp"
pulumi config set dbUser "myuser"
pulumi config set dbPassword "my-secure-password-123" --secret
pulumi config set dbPort "5432"
```

## Environment Variables

Alternatively, you can set environment variables before running `pulumi up`:

```bash
export DB_NAME="moodtracker"
export DB_USER="postgres"
export DB_PASSWORD="secure-password"
export DB_PORT="5432"
```

## Security Considerations

1. **Always use secrets** for database passwords:
   ```bash
   pulumi config set dbPassword "your-password" --secret
   ```

2. **Use strong passwords** for production deployments

3. **The RDS instance is created with**:
   - Storage encryption enabled
   - SSL/TLS required for connections
   - Security groups configured for Lambda access
   - Public accessibility enabled (can be changed in createrds.js)

## Network Configuration

The RDS instance is automatically configured with:
- Default VPC
- Subnet group across multiple availability zones
- Security group allowing Lambda access
- Security group allowing external access (port 5432)

## Cost Optimization

For AWS Academy accounts, the configuration uses:
- `db.t3.micro` instance class (free tier eligible)
- 20GB storage minimum
- No backup retention to reduce costs
- General Purpose (gp2) storage type

## Troubleshooting

If you encounter issues:

1. **Check RDS status**: Look in AWS Console → RDS → Databases
2. **Verify security groups**: Ensure Lambda can access RDS
3. **Check VPC configuration**: Ensure subnets are properly configured
4. **Review logs**: Check CloudWatch logs for connection errors

## Connection String Format

The deployment outputs a complete connection string:
```
postgresql://username:password@endpoint:port/database?sslmode=require
```

You can use this to test the connection manually or in your application.
