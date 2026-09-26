# syntax=docker/dockerfile:1.7
# Sample multi-stage Dockerfile.
ARG NODE_VERSION=20
ARG ALPINE_VERSION=3.20

FROM node:${NODE_VERSION}-alpine${ALPINE_VERSION} AS deps
WORKDIR /app

ENV NPM_CONFIG_FUND=false \
    NPM_CONFIG_AUDIT=false

COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev

FROM deps AS build
COPY . .
RUN npm ci && npm run build && npm prune --omit=dev

FROM node:${NODE_VERSION}-alpine${ALPINE_VERSION} AS runtime
LABEL org.opencontainers.image.source="https://github.com/blaccorek/vscode-bnw-colors-theme" \
      org.opencontainers.image.licenses="MIT" \
      maintainer="blaccorek"

ARG UID=10001
ENV NODE_ENV=production \
    PORT=8080 \
    PATH="/app/node_modules/.bin:${PATH}"

RUN apk add --no-cache tini curl \
 && addgroup -S app -g ${UID} \
 && adduser -S app -G app -u ${UID}

WORKDIR /app
COPY --from=build --chown=app:app /app/node_modules ./node_modules
COPY --from=build --chown=app:app /app/dist ./dist
COPY --chown=app:app package.json ./

USER app
EXPOSE 8080/tcp
VOLUME ["/tmp"]

HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 \
    CMD curl -fsS "http://localhost:${PORT}/healthz" || exit 1

STOPSIGNAL SIGTERM
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "dist/server.js"]
