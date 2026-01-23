FROM node:18-alpine

# Installing libvips-dev for sharp Compatibility
RUN apk update && apk add --no-cache build-base gcc autoconf automake zlib-dev libpng-dev nasm bash vips-dev

WORKDIR /opt/app

# Set ownership to node user
RUN chown -R node:node /opt/app

# Switch to node user
USER node

COPY --chown=node:node package.json ./
RUN npm install

COPY --chown=node:node . .

ENV NODE_ENV=production
RUN npm run build

EXPOSE 1337
CMD ["npm", "run", "start"]
