FROM node:22-alpine

# Set working directory
WORKDIR /app

# Install git and wget
RUN apk add --no-cache git wget

# Clone specific version of Staticman
RUN git clone https://github.com/eduardoboucas/staticman.git . && \
    git checkout v1.7.1

# Install dependencies
RUN npm install --production

# Create config directory
RUN mkdir -p config

# Set environment variables
ENV NODE_ENV=production
ENV PORT=8080

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S staticman -u 1001

# Change ownership
RUN chown -R staticman:nodejs /app

# Switch to non-root user
USER staticman

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:8080/ || exit 1

# Start the application
CMD ["npm", "start"]
