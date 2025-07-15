# Use the official Go image as base
FROM golang:1.24-alpine AS builder

# Set the working directory inside the container
WORKDIR /app

# Install git and ca-certificates
RUN apk add --no-cache git ca-certificates

# Set Go proxy and other environment variables
ENV GOPROXY=https://proxy.golang.org,direct
ENV GOSUMDB=sum.golang.org
ENV GO111MODULE=on

# Copy all files first to ensure go.sum is available
COPY . .

# Download dependencies with verbose output
RUN go mod download -x

# Build the Go binary for Linux
RUN CGO_ENABLED=0 GOOS=linux go build -o main .

# Use AWS Lambda Go runtime as the final image
FROM public.ecr.aws/lambda/go:1

# Copy the Lambda Web Adapter
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.8.0 /lambda-adapter /opt/extensions/lambda-adapter

# Copy the compiled binary from the builder stage
COPY --from=builder /app/main ${LAMBDA_TASK_ROOT}/main

# Copy the dist folder containing the frontend static files
COPY --from=builder /app/dist ${LAMBDA_TASK_ROOT}/dist

# Make sure the binary is executable
RUN chmod +x ${LAMBDA_TASK_ROOT}/main

# Set environment variables for Lambda Web Adapter
ENV AWS_LAMBDA_RUNTIME_API=127.0.0.1:9000
ENV AWS_LAMBDA_EXEC_WRAPPER=/opt/bootstrap
ENV _LAMBDA_SERVER_PORT=3000

# Set the handler
CMD ["main"]