ARG NODE_VERSION=18.18.0

# ---- RUNTIME BUILD -----------------------------------------------------------
FROM node:${NODE_VERSION}-alpine as build

WORKDIR /server-build

RUN apk add --no-cache python3 make gcc g++ libc-dev sqlite-dev

COPY . /server-build

ENV CI=true
ENV NODE_ENV=development
RUN PNPM_VERSION=$(node -p 'require("./package.json").engines.pnpm'); npm i -g pnpm@$PNPM_VERSION
RUN pnpm install --config.build-from-source=sqlite --config.sqlite=/usr/local
#-RUN pnpm install sqlite3@^5.0.0;
RUN pnpm install image-size simple-git
RUN pnpm install development

# ---- RUNTIME IMAGE ----------------------------------------------------------
ARG NODE_VERSION
FROM node:${NODE_VERSION}-alpine

WORKDIR /app
LABEL maintainer="ferdium"

# TODO: Shouldn't we set 'NODE_ENV=production' when running in production mode?
ENV \
  NODE_ENV=production \
  HOST=0.0.0.0 \
  PORT=3333 \
  DATA_DIR="/data"

COPY --from=build /server-build /app

RUN apk add --no-cache sqlite-libs curl su-exec python3 make g++ py3-pip git py3-pip

RUN \
  PNPM_VERSION=$(node -p 'require("./package.json").engines.pnpm'); npm i -g pnpm@$PNPM_VERSION; \
  npm i -g @adonisjs/cli

HEALTHCHECK --start-period=5s --interval=30s --retries=5 --timeout=3s CMD curl -sSf http://localhost:${PORT}/health

COPY docker/entrypoint.sh /entrypoint.sh
COPY docker/.env /app/.env

ENTRYPOINT ["/entrypoint.sh"]
