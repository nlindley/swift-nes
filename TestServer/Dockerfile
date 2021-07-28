FROM node:16.6.1-alpine3.14
RUN apk add dumb-init

ENV NODE_ENV production

WORKDIR /usr/src/app
COPY package.json yarn.lock ./
RUN yarn install --production --frozen-lockfile
COPY --chown=node:node . .

EXPOSE 3000

USER node
CMD [ "dumb-init", "node", "." ]
