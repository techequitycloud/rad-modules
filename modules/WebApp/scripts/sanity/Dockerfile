# Stage 1: Build
FROM node:18-alpine AS builder
WORKDIR /app

# Accept build arguments for optional build-time configuration
# If provided, these will be statically embedded by Sanity's build process
# If not provided, defaults to 'placeholder-project-id' which will be replaced at runtime
ARG SANITY_STUDIO_PROJECT_ID=placeholder-project-id
ARG SANITY_STUDIO_DATASET=production

# Install dependencies
COPY package.json ./
RUN npm install

# Copy source
COPY . .

# Build the static site
# Sanity will statically replace process.env.SANITY_STUDIO_* during build
ENV SANITY_STUDIO_PROJECT_ID=${SANITY_STUDIO_PROJECT_ID}
ENV SANITY_STUDIO_DATASET=${SANITY_STUDIO_DATASET}
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
