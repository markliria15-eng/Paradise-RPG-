FROM node:20-alpine

WORKDIR /app

COPY server/package*.json ./server/
RUN cd server && npm ci --omit=dev

COPY server ./server
COPY database ./database

WORKDIR /app/server

ENV NODE_ENV=production
ENV WS_MODE=shared
ENV WS_PATH=/ws

CMD ["npm", "run", "start:prod"]
