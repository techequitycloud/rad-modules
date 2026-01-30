FROM node:22-alpine AS build

WORKDIR /app/medusa

# Install build dependencies for native modules
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    git

# Copy dependency files
COPY package.json yarn.lock ./

# Install dependencies with frozen lockfile
RUN yarn install --frozen-lockfile

# Copy application files
COPY . .

# Create data directory (in case it's missing from source)
RUN mkdir -p data

# Build the application
RUN yarn build

# Production stage
FROM node:22-alpine

WORKDIR /app/medusa

# Install tini for proper signal handling
RUN apk add --no-cache tini

# Copy dependency files
COPY package.json yarn.lock ./

# Install production dependencies only
RUN yarn install --production --frozen-lockfile && \
    yarn cache clean

# Copy built artifacts from build stage
COPY --from=build /app/medusa/dist ./dist
COPY --from=build /app/medusa/medusa-config.js ./
COPY --from=build /app/medusa/tsconfig.json ./
COPY --from=build /app/medusa/data ./data

# Set proper permissions
RUN chown -R node:node /app/medusa

# Switch to non-root user
USER node

# Expose Medusa port
EXPOSE 9000

# Use tini as entrypoint
ENTRYPOINT ["/sbin/tini", "--"]

# Start Medusa server
CMD ["yarn", "start"]
