const aws = require("@pulumi/aws");
const pulumi = require("@pulumi/pulumi");

/**
 * Creates an RDS PostgreSQL instance based on the configuration from create-rds.sh
 * This function handles VPC setup, security groups, subnet groups, and RDS instance creation
 * @param {aws.Provider} provider - AWS provider configured with credentials
 * @param {Object} config - Configuration object containing database settings
 * @returns {Object} - Object containing RDS instance and related resources
 */
function createRDSInstance(provider, config = {}) {
    // Default configuration based on create-rds.sh
    const dbConfig = {
        instanceId: config.instanceId || "moodtracker-rds",
        dbName: config.dbName || "moodtracker",
        dbUser: config.dbUser || "postgres",
        dbPassword: config.dbPassword || "password123",
        instanceClass: config.instanceClass || "db.t3.micro",
        allocatedStorage: config.allocatedStorage || 20,
        engineVersion: config.engineVersion || "14.12",
        port: config.port || 5432,
        ...config
    };

    // Get the default VPC
    const vpc = aws.ec2.getVpc({
        default: true,
    }, { provider });

    // Get all subnets in the VPC for the subnet group
    const subnets = aws.ec2.getSubnets({
        filters: [{
            name: "vpc-id",
            values: [vpc.then(v => v.id)],
        }],
    }, { provider });

    // Create security group for RDS
    const rdsSecurityGroup = new aws.ec2.SecurityGroup("moodtracker-rds-sg", {
        name: "moodtracker-rds-sg",
        description: "Security group for MoodTracker RDS",
        vpcId: vpc.then(v => v.id),
        
        ingress: [
            {
                protocol: "tcp",
                fromPort: dbConfig.port,
                toPort: dbConfig.port,
                cidrBlocks: ["0.0.0.0/0"], // Allow from anywhere - adjust as needed
                description: "PostgreSQL access",
            },
        ],
        
        egress: [
            {
                protocol: "-1",
                fromPort: 0,
                toPort: 0,
                cidrBlocks: ["0.0.0.0/0"],
            },
        ],
        
        tags: {
            Name: "moodtracker-rds-sg",
            Project: "MoodTracker",
        },
    }, { provider });

    // Create DB subnet group
    const dbSubnetGroup = new aws.rds.SubnetGroup("moodtracker-subnet-group", {
        name: "moodtracker-subnet-group",
        description: "Subnet group for MoodTracker RDS",
        subnetIds: subnets.then(s => s.ids),
        
        tags: {
            Name: "moodtracker-subnet-group",
            Project: "MoodTracker",
        },
    }, { provider });

    // Create RDS instance
    const rdsInstance = new aws.rds.Instance("moodtracker-rds", {
        identifier: dbConfig.instanceId,
        instanceClass: dbConfig.instanceClass,
        engine: "postgres",
        engineVersion: dbConfig.engineVersion,
        allocatedStorage: dbConfig.allocatedStorage,
        storageType: "gp2",
        storageEncrypted: true,
        
        // Database configuration
        dbName: dbConfig.dbName,
        username: dbConfig.dbUser,
        password: dbConfig.dbPassword,
        port: dbConfig.port,
        
        // Network configuration
        dbSubnetGroupName: dbSubnetGroup.name,
        vpcSecurityGroupIds: [rdsSecurityGroup.id],
        publiclyAccessible: true,
        
        // Backup and maintenance
        backupRetentionPeriod: 0, // No backups for cost savings
        backupWindow: "03:00-04:00",
        maintenanceWindow: "sun:04:00-sun:05:00",
        autoMinorVersionUpgrade: false,
        deletionProtection: false,
        
        // Skip final snapshot for easier cleanup
        skipFinalSnapshot: true,
        
        tags: {
            Name: "moodtracker-rds",
            Project: "MoodTracker",
            Environment: "development",
        },
    }, { 
        provider,
        dependsOn: [dbSubnetGroup, rdsSecurityGroup]
    });

    // Create a Lambda security group that can access RDS
    const lambdaSecurityGroup = new aws.ec2.SecurityGroup("moodtracker-lambda-sg", {
        name: "moodtracker-lambda-sg",
        description: "Security group for MoodTracker Lambda functions",
        vpcId: vpc.then(v => v.id),
        
        egress: [
            {
                protocol: "-1",
                fromPort: 0,
                toPort: 0,
                cidrBlocks: ["0.0.0.0/0"],
            },
        ],
        
        tags: {
            Name: "moodtracker-lambda-sg",
            Project: "MoodTracker",
        },
    }, { provider });

    // Add ingress rule to RDS security group to allow Lambda access
    const rdsIngressRule = new aws.ec2.SecurityGroupRule("rds-lambda-ingress", {
        type: "ingress",
        fromPort: dbConfig.port,
        toPort: dbConfig.port,
        protocol: "tcp",
        sourceSecurityGroupId: lambdaSecurityGroup.id,
        securityGroupId: rdsSecurityGroup.id,
        description: "Allow Lambda functions to access RDS",
    }, { provider });

    return {
        rdsInstance,
        rdsSecurityGroup,
        lambdaSecurityGroup,
        dbSubnetGroup,
        vpc,
        subnets,
        dbConfig,
        
        // Outputs for use in other resources
        outputs: {
            rdsEndpoint: rdsInstance.endpoint.apply(endpoint => endpoint.split(':')[0]),
            rdsPort: rdsInstance.port,
            rdsUsername: rdsInstance.username,
            rdsDbName: rdsInstance.dbName,
            rdsSecurityGroupId: rdsSecurityGroup.id,
            lambdaSecurityGroupId: lambdaSecurityGroup.id,
            dbSubnetGroupName: dbSubnetGroup.name,
            vpcId: vpc.then(v => v.id),
            subnetIds: subnets.then(s => s.ids),
        }
    };
}

module.exports = {
    createRDSInstance
};
