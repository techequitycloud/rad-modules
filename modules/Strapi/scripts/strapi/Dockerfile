FROM node:18-alpine as build
# Installing libvips-dev for sharp Compatibility
RUN apk update && apk add --no-cache build-base gcc autoconf automake zlib-dev libpng-dev nasm bash vips-dev
WORKDIR /opt/app
COPY package.json package-lock.json* ./
RUN npm install
COPY . .
ENV NODE_ENV=production
RUN npm run build

FROM node:18-alpine
# Installing libvips-dev for sharp Compatibility
RUN apk update && apk add --no-cache vips-dev tini
WORKDIR /opt/app

# Install production dependencies
COPY package.json package-lock.json* ./
# Install build tools for sharp, install deps, then remove build tools to keep image small
RUN apk add --no-cache build-base gcc autoconf automake zlib-dev libpng-dev nasm bash && \
    npm install --omit=dev && \
    npm cache clean --force && \
    apk del build-base gcc autoconf automake zlib-dev libpng-dev nasm bash

# Copy source files
COPY . .

# Create public folder (required by Strapi at runtime)
RUN mkdir -p public/uploads

# Copy build artifacts
COPY --from=build /opt/app/build ./build
COPY --from=build /opt/app/.strapi ./.strapi

# Set ownership
RUN chown -R node:node /opt/app

# Switch to node user
USER node

ENV NODE_ENV=production
EXPOSE 1337
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "node_modules/@strapi/strapi/bin/strapi.js", "start"]
