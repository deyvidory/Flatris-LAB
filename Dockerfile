FROM node:18-slim

WORKDIR /app

COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

COPY . .

ENV NODE_ENV=production
ENV NODE_OPTIONS=--openssl-legacy-provider
ENV PORT=3000

RUN yarn build

EXPOSE 3000

CMD ["yarn", "start"]
