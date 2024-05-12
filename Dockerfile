# Image size ~ 400MB
FROM node:21-alpine3.18 as builder

WORKDIR /app

RUN corepack enable && corepack prepare pnpm@latest --activate
ENV PNPM_HOME=/usr/local/bin
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD true
COPY . .

COPY package*.json *-lock.yaml ./

RUN apk add --no-cache --virtual .gyp \
    chromium \
    python3 \
    make \
    g++ \
    && apk add --no-cache git \
    && pnpm install && pnpm run build \
    && apk del .gyp
RUN npm install puppeteer@22.8.0
RUN addgroup -S pptruser && adduser -S -G pptruser pptruser \
    && mkdir -p /home/pptruser/Downloads /app \
    && chown -R pptruser:pptruser /home/pptruser \
    && chown -R pptruser:pptruser /app

# Run everything after as non-privileged user.
USER pptruser
FROM node:21-alpine3.18 as deploy

WORKDIR /app

ARG PORT
ENV PORT $PORT
EXPOSE $PORT
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD true
COPY --from=builder /app/assets ./assets
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/*.json /app/*-lock.yaml ./

RUN corepack enable && corepack prepare pnpm@latest --activate 
ENV PNPM_HOME=/usr/local/bin

RUN addgroup -S pptruser && adduser -S -G pptruser pptruser \
    && mkdir -p /home/pptruser/Downloads /app \
    && chown -R pptruser:pptruser /home/pptruser \
    && chown -R pptruser:pptruser /app

# Run everything after as non-privileged user.
USER pptruser
RUN npm cache clean --force && pnpm install --production --ignore-scripts \
    && addgroup -g 1001 -S nodejs && adduser -S -u 1001 nodejs \
    && rm -rf $PNPM_HOME/.npm $PNPM_HOME/.node-gyp
RUN npm install puppeteer@22.8.0
CMD ["npm", "start"]