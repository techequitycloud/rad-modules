FROM node:18-alpine

WORKDIR /app/medusa

COPY package.json .

RUN yarn install

COPY . .

RUN yarn build

EXPOSE 9000

RUN chown -R node:node /app/medusa
USER node

CMD ["yarn", "start"]
