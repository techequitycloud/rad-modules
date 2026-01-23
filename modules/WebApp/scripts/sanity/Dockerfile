# Stage 1: Build
FROM node:18-alpine AS builder
WORKDIR /app

# Install dependencies
COPY package.json ./
RUN npm install

# Copy source
COPY . .

# Build the static site
# We set dummy values for build time if needed by some plugins, but usually not required for static build
ENV SANITY_STUDIO_PROJECT_ID=placeholder
ENV SANITY_STUDIO_DATASET=placeholder
RUN npm run build

# Stage 2: Serve
FROM nginx:alpine

# Copy build output (Sanity build output is in 'dist')
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy Nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Sanity Studio runs on 8080 in this container
EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
