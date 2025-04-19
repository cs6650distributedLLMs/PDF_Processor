FROM golang:1.24.2-alpine AS builder

# Set working directory
WORKDIR /app

# Copy Go module files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -o tldr ./cmd/server

# Use a minimal alpine image for the final container
FROM alpine:3.21.3

# Install ca-certificates for HTTPS requests
RUN apk --no-cache add ca-certificates

# Set working directory
WORKDIR /app

# Copy the binary from the builder stage
COPY --from=builder /app/tldr .

# Copy .env file if it exists (optional)
COPY --from=builder /app/.env .

# Expose the application port
EXPOSE ${APP_PORT:-8080}

# Run the application
CMD ["./tldr"]