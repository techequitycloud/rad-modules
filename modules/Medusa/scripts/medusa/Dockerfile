FROM node:20-alpine

WORKDIR /app/medusa

# Install system dependencies
RUN apk add --no-cache python3 make g++ git

# Copy package files
COPY package.json ./

# Install dependencies (fresh install, ignoring lockfile to fix corruption)
RUN yarn install

# Copy all project files
COPY . .

# Build the application
RUN yarn build

# Create user and set permissions
RUN addgroup -S node && adduser -S node -G node || true
RUN chown -R node:node /app/medusa

# Switch to non-root user
USER node

# Expose port
EXPOSE 9000

# Start Medusa server
CMD ["yarn", "start"]
