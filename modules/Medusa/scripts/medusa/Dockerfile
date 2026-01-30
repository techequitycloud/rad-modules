FROM node:18-alpine AS build

WORKDIR /app/medusa

RUN apk add --no-cache python3 make g++

COPY package.json yarn.lock ./

RUN yarn install --frozen-lockfile

COPY . .

RUN yarn build

FROM node:18-alpine

WORKDIR /app/medusa

RUN apk add --no-cache tini

COPY package.json yarn.lock ./

RUN yarn install --production --frozen-lockfile && yarn cache clean

COPY --from=build /app/medusa/dist ./dist
COPY --from=build /app/medusa/medusa-config.js ./
COPY --from=build /app/medusa/tsconfig.json ./
COPY --from=build /app/medusa/data ./data

EXPOSE 9000

RUN chown -R node:node /app/medusa
USER node

ENTRYPOINT ["/sbin/tini", "--"]

CMD ["yarn", "start"]
