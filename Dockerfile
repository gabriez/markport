# ── Stage 1: Build & Vendor extraction ─────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Instalar dependencias para scripts de descarga/extracción si hiciera falta
RUN apk add --no-cache curl ca-certificates

# Copiar paquetes y scripts necesarios para bajar el bundle de Obsidian
COPY scripts/ scripts/
COPY src/config/ src/config/
COPY src/runtime-server/server/package*.json src/runtime-server/server/
COPY src/client-mobile/ src/client-mobile/

# 1. Bajar el APK de Obsidian 1.12.7 y extraer los assets en vendor/obsidian-mobile
RUN node scripts/update-obsidian-mobile.js --version 1.12.7 && \
    node scripts/patch-obsidian-mobile.js

# 2. Instalar dependencias del runtime-server
WORKDIR /app/src/runtime-server/server
RUN npm ci --omit=dev

# ── Stage 2: Runtime ──────────────────────────────────────────────────────────
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV HOST=0.0.0.0
ENV PORT=3000
ENV VAULT_PATH=/app/user-data/vault
ENV VAULT_REGISTRY=/app/user-data/registry.json

# Copiar el código fuente necesario
COPY src/ src/
COPY --from=builder /app/vendor/ vendor/
COPY --from=builder /app/src/runtime-server/server/node_modules/ src/runtime-server/server/node_modules/

# Crear directorio para la persistencia del vault con permisos adecuados
RUN mkdir -p /app/user-data/vault && chown -R node:node /app/user-data

USER node

EXPOSE 3000

WORKDIR /app/src/runtime-server/server
CMD ["node", "index.js"]
