# Build stage
FROM node:18-slim AS builder

WORKDIR /app

# Copy package files for better caching
COPY package*.json ./
COPY frontend/package*.json ./frontend/

# Install dependencies
RUN npm ci
RUN cd frontend && npm ci

# Copy application files
COPY . .

# Build the application
RUN npm run build
RUN cd frontend && npm run build

# Production stage
FROM node:18-slim AS production

# Create a non-root user
RUN apt-get update && apt-get install -y --no-install-recommends dumb-init \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -r pulse && useradd -r -g pulse pulse

WORKDIR /app

# Define build arguments with defaults
ARG NODE_ENV=production
ARG LOG_LEVEL=info
ARG ENABLE_DEV_TOOLS=false
ARG PORT=7654
ARG NODE_TLS_REJECT_UNAUTHORIZED=0

# Set environment variables from build arguments
ENV NODE_ENV=${NODE_ENV}
ENV LOG_LEVEL=${LOG_LEVEL}
ENV ENABLE_DEV_TOOLS=${ENABLE_DEV_TOOLS}
ENV PORT=${PORT}
ENV DOCKER_CONTAINER=true
ENV NODE_TLS_REJECT_UNAUTHORIZED=${NODE_TLS_REJECT_UNAUTHORIZED}

# Copy only necessary files from builder stage
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/frontend/dist ./frontend/dist
COPY --from=builder /app/start-pulse.sh ./

# Install only production dependencies
RUN npm ci --only=production

# Make the startup script executable
RUN chmod +x start-pulse.sh && chown -R pulse:pulse /app

# Switch to non-root user
USER pulse

# Expose the backend port
EXPOSE ${PORT}

# Use dumb-init as entrypoint to handle signals properly
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

# Start the application
CMD ["node", "dist/server.js"]

# Development stage for local development
FROM node:18 AS development

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY frontend/package*.json ./frontend/

# Install dependencies
RUN npm ci
RUN cd frontend && npm ci

# Copy application files
COPY . .

# Make the startup script executable
RUN chmod +x start-pulse.sh

# Define build arguments with defaults
ARG NODE_ENV=development
ARG LOG_LEVEL=debug
ARG ENABLE_DEV_TOOLS=true
ARG PORT=7654
ARG VITE_PORT=9513
ARG NODE_TLS_REJECT_UNAUTHORIZED=0

# Set environment variables from build arguments
ENV NODE_ENV=${NODE_ENV}
ENV LOG_LEVEL=${LOG_LEVEL}
ENV ENABLE_DEV_TOOLS=${ENABLE_DEV_TOOLS}
ENV PORT=${PORT}
ENV VITE_PORT=${VITE_PORT}
ENV DOCKER_CONTAINER=true
ENV NODE_TLS_REJECT_UNAUTHORIZED=${NODE_TLS_REJECT_UNAUTHORIZED}

# Expose the backend and frontend ports
EXPOSE ${PORT} ${VITE_PORT}

# Start both the backend and frontend (using the start-pulse.sh script)
CMD ["./start-pulse.sh"] 