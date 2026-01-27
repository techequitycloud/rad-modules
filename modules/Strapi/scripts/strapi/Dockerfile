FROM node:20-alpine as build
# Installing libvips-dev for sharp Compatibility
RUN apk update && apk add --no-cache build-base gcc autoconf automake zlib-dev libpng-dev nasm bash vips-dev
WORKDIR /opt/app
COPY package.json package-lock.json* ./
RUN npm install
COPY . .
ENV NODE_ENV=production
RUN npm run build

FROM node:20-alpine
# Installing libvips-dev for sharp Compatibility
RUN apk update && apk add --no-cache vips-dev
WORKDIR /opt/app

# Install production dependencies
COPY package.json package-lock.json* ./
RUN npm install --omit=dev && npm cache clean --force

# Copy source files
COPY . .

# Copy build artifacts
COPY --from=build /opt/app/build ./build
COPY --from=build /opt/app/.strapi ./.strapi

# Set ownership
RUN chown -R node:node /opt/app

# Switch to node user
USER node

ENV NODE_ENV=production
EXPOSE 1337
CMD ["npm", "run", "start"]
