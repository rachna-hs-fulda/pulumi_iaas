// MoodTracker Backend Deployment with AWS Lambda Web Adapter
// This configuration deploys a Go backend service using AWS Lambda Web Adapter
// 
// Prerequisites:
// 1. Set up your database configuration in Pulumi config or environment variables:
//    - pulumi config set dbHost <your-rds-endpoint>
//    - pulumi config set dbUser <your-db-user>
//    - pulumi config set dbPassword <your-db-password> --secret
//    - pulumi config set dbName <your-db-name>
// 
// 2. Ensure your RDS instance is accessible from Lambda (VPC configuration)
// 3. Make sure Docker is running for container image build
//
// Deployment:
// 1. pulumi up
// 2. Test the API endpoint with: curl <apiUrl>/api/v1/health

// Import the [pulumi/aws](https://pulumi.io/reference/pkg/nodejs/@pulumi/aws/index.html) package
const pulumi = require("@pulumi/pulumi");
const aws = require("@pulumi/aws");
const awsx = require("@pulumi/awsx");
const path = require("path");
const fs = require("fs");
const { createRDSInstance } = require("./createrds");

// Load AWS credentials from .env.aws file
function loadAWSCredentials() {
    const envFile = path.join(__dirname, ".env.aws");
    if (fs.existsSync(envFile)) {
        const envContent = fs.readFileSync(envFile, "utf8");
        const envVars = {};
        
        envContent.split("\n").forEach(line => {
            if (line.trim() && !line.startsWith("#")) {
                const [key, value] = line.split("=");
                if (key && value) {
                    envVars[key.trim()] = value.trim();
                }
            }
        });
        
        return envVars;
    }
    return {};
}

const awsCredentials = loadAWSCredentials();

// Configure AWS provider with credentials from .env.aws
const awsProvider = new aws.Provider("aws-provider", {
    region: awsCredentials.region || "us-east-1",
    accessKey: awsCredentials.aws_access_key_id,
    secretKey: awsCredentials.aws_secret_access_key,
    token: awsCredentials.aws_session_token,
});

// Create Pulumi config instance
const config = new pulumi.Config();

// Create RDS instance with database configuration
const rdsConfig = {
    instanceId: config.get("dbInstanceId") || "moodtracker-rds",
    dbName: config.get("dbName") || process.env.DB_NAME || "moodtracker",
    dbUser: config.get("dbUser") || process.env.DB_USER || "postgres",
    dbPassword: config.get("dbPassword") || process.env.DB_PASSWORD || "password123",
    instanceClass: config.get("dbInstanceClass") || "db.t3.micro",
    allocatedStorage: parseInt(config.get("dbAllocatedStorage") || "20"),
    engineVersion: config.get("dbEngineVersion") || "14.12",
    port: parseInt(config.get("dbPort") || "5432"),
};

console.log("Creating RDS instance with configuration:", {
    instanceId: rdsConfig.instanceId,
    dbName: rdsConfig.dbName,
    dbUser: rdsConfig.dbUser,
    instanceClass: rdsConfig.instanceClass,
    allocatedStorage: rdsConfig.allocatedStorage,
    engineVersion: rdsConfig.engineVersion,
    port: rdsConfig.port,
});

const rdsResources = createRDSInstance(awsProvider, rdsConfig);

// Create an ECR repository for the Docker image
// Simplified configuration for AWS Academy accounts
const repo = new awsx.ecr.Repository("backend-repo", {
    forceDelete: true,
}, { provider: awsProvider });

// Build and push the Docker image to ECR
const image = new awsx.ecr.Image("backend-image", {
    repositoryUrl: repo.url,
    context: "./backend",
    dockerfile: "./backend/Dockerfile",
    platform: "linux/amd64",
}, { provider: awsProvider });

// Use the existing IAM role from AWS Academy account
const lambdaRoleArn = awsCredentials.IAM_role_arn || process.env.IAM_ROLE_ARN;

if (!lambdaRoleArn) {
    throw new Error("IAM_role_arn not found in .env.aws file. Please ensure it's configured.");
}

console.log(`Using existing IAM role: ${lambdaRoleArn}`);

// Create CloudWatch Log Group for Lambda
const logGroup = new aws.cloudwatch.LogGroup("backend-lambda-logs", {
    name: pulumi.interpolate`/aws/lambda/backend-lambda`,
    retentionInDays: 7, // Keep logs for 7 days
}, { provider: awsProvider });

// Create the Lambda function using the container image
const lambdaFunction = new aws.lambda.Function("backend-lambda", {
    packageType: "Image",
    imageUri: image.imageUri,
    role: lambdaRoleArn, // Use the ARN directly
    timeout: 60, // Increased timeout for database operations
    memorySize: 1024, // Increased memory for better performance
    environment: {
        variables: {
            AWS_LAMBDA_EXEC_WRAPPER: "/opt/bootstrap",
            LAMBDA_SERVER_PORT: "3000",
            PORT: "3000",
            APP_PORT: "3000",
            // Database configuration from RDS instance
            DB_HOST: rdsResources.outputs.rdsEndpoint,
            DB_PORT: rdsResources.outputs.rdsPort,
            DB_USER: rdsResources.outputs.rdsUsername,
            DB_PASSWORD: rdsConfig.dbPassword,
            DB_NAME: rdsResources.outputs.rdsDbName,
        },
    },
    // VPC configuration to access RDS
    vpcConfig: {
        subnetIds: rdsResources.outputs.subnetIds,
        securityGroupIds: [rdsResources.outputs.lambdaSecurityGroupId],
    },
}, { 
    provider: awsProvider,
    dependsOn: [
        rdsResources.rdsInstance,
        rdsResources.rdsSecurityGroup,
        rdsResources.lambdaSecurityGroup,
        rdsResources.dbSubnetGroup
    ]
});

// Create an API Gateway REST API
const api = new aws.apigateway.RestApi("backend-api", {
    description: "Backend API using Lambda Web Adapter",
}, { provider: awsProvider });

// Create a resource for the API Gateway (catch-all proxy)
const proxyResource = new aws.apigateway.Resource("proxy-resource", {
    restApi: api.id,
    parentId: api.rootResourceId,
    pathPart: "{proxy+}",
}, { provider: awsProvider });

// Create a method for the proxy resource
const proxyMethod = new aws.apigateway.Method("proxy-method", {
    restApi: api.id,
    resourceId: proxyResource.id,
    httpMethod: "ANY",
    authorization: "NONE",
}, { provider: awsProvider });

// Create a root method for the API Gateway
const rootMethod = new aws.apigateway.Method("root-method", {
    restApi: api.id,
    resourceId: api.rootResourceId,
    httpMethod: "ANY",
    authorization: "NONE",
}, { provider: awsProvider });

// Create Lambda permission for API Gateway to invoke the function
const lambdaPermission = new aws.lambda.Permission("lambda-permission", {
    action: "lambda:InvokeFunction",
    function: lambdaFunction.name,
    principal: "apigateway.amazonaws.com",
    sourceArn: pulumi.interpolate`${api.executionArn}/*/*`,
}, { provider: awsProvider });

// Create integration for the proxy method
const proxyIntegration = new aws.apigateway.Integration("proxy-integration", {
    restApi: api.id,
    resourceId: proxyResource.id,
    httpMethod: proxyMethod.httpMethod,
    integrationHttpMethod: "POST",
    type: "AWS_PROXY",
    uri: pulumi.interpolate`arn:aws:apigateway:${awsCredentials.region || "us-east-1"}:lambda:path/2015-03-31/functions/${lambdaFunction.arn}/invocations`,
}, { provider: awsProvider });

// Create integration for the root method
const rootIntegration = new aws.apigateway.Integration("root-integration", {
    restApi: api.id,
    resourceId: api.rootResourceId,
    httpMethod: rootMethod.httpMethod,
    integrationHttpMethod: "POST",
    type: "AWS_PROXY",
    uri: pulumi.interpolate`arn:aws:apigateway:${awsCredentials.region || "us-east-1"}:lambda:path/2015-03-31/functions/${lambdaFunction.arn}/invocations`,
}, { provider: awsProvider });

// Deploy the API
const deployment = new aws.apigateway.Deployment("api-deployment", {
    restApi: api.id,
    stageName: "prod",
}, {
    dependsOn: [proxyIntegration, rootIntegration],
    provider: awsProvider,
});

// Add CORS configuration for the API
const corsMethod = new aws.apigateway.Method("cors-method", {
    restApi: api.id,
    resourceId: proxyResource.id,
    httpMethod: "OPTIONS",
    authorization: "NONE",
}, { provider: awsProvider });

const corsIntegration = new aws.apigateway.Integration("cors-integration", {
    restApi: api.id,
    resourceId: proxyResource.id,
    httpMethod: corsMethod.httpMethod,
    type: "MOCK",
    requestTemplates: {
        "application/json": '{"statusCode": 200}',
    },
}, { provider: awsProvider });

const corsMethodResponse = new aws.apigateway.MethodResponse("cors-method-response", {
    restApi: api.id,
    resourceId: proxyResource.id,
    httpMethod: corsMethod.httpMethod,
    statusCode: "200",
    responseParameters: {
        "method.response.header.Access-Control-Allow-Headers": true,
        "method.response.header.Access-Control-Allow-Methods": true,
        "method.response.header.Access-Control-Allow-Origin": true,
    },
}, { provider: awsProvider });

const corsIntegrationResponse = new aws.apigateway.IntegrationResponse("cors-integration-response", {
    restApi: api.id,
    resourceId: proxyResource.id,
    httpMethod: corsMethod.httpMethod,
    statusCode: corsMethodResponse.statusCode,
    responseParameters: {
        "method.response.header.Access-Control-Allow-Headers": "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
        "method.response.header.Access-Control-Allow-Methods": "'GET,POST,PUT,DELETE,OPTIONS'",
        "method.response.header.Access-Control-Allow-Origin": "'*'",
    },
}, {
    dependsOn: [corsIntegration],
    provider: awsProvider,
});

// For AWS Academy accounts, we'll skip S3 static hosting due to permission restrictions
// You can serve static files through the Lambda function or use a different approach

// Export the URLs and other useful information
const region = awsCredentials.region || "us-east-1";
exports.apiUrl = pulumi.interpolate`https://${api.id}.execute-api.${region}.amazonaws.com/prod`;
exports.lambdaFunctionName = lambdaFunction.name;
exports.lambdaFunctionArn = lambdaFunction.arn;
exports.ecrRepositoryUrl = repo.url;
exports.containerImageUri = image.imageUri;
exports.region = region;
exports.iamRoleArn = lambdaRoleArn;

// Export RDS information
exports.rdsEndpoint = rdsResources.outputs.rdsEndpoint;
exports.rdsPort = rdsResources.outputs.rdsPort;
exports.rdsUsername = rdsResources.outputs.rdsUsername;
exports.rdsDbName = rdsResources.outputs.rdsDbName;
exports.rdsSecurityGroupId = rdsResources.outputs.rdsSecurityGroupId;
exports.lambdaSecurityGroupId = rdsResources.outputs.lambdaSecurityGroupId;
exports.vpcId = rdsResources.outputs.vpcId;
exports.subnetIds = rdsResources.outputs.subnetIds;

// Export example API endpoints
exports.healthCheckUrl = pulumi.interpolate`https://${api.id}.execute-api.${region}.amazonaws.com/prod/api/v1/health`;
exports.usersApiUrl = pulumi.interpolate`https://${api.id}.execute-api.${region}.amazonaws.com/prod/api/v1/users`;
exports.moodsApiUrl = pulumi.interpolate`https://${api.id}.execute-api.${region}.amazonaws.com/prod/api/v1/moods`;

// Export database connection string (for testing purposes)
exports.dbConnectionString = pulumi.interpolate`postgresql://${rdsResources.outputs.rdsUsername}:${rdsConfig.dbPassword}@${rdsResources.outputs.rdsEndpoint}:${rdsResources.outputs.rdsPort}/${rdsResources.outputs.rdsDbName}?sslmode=require`;
