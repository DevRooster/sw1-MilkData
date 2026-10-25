# Imagen de la API de MilkData.
#
# Multi-etapa: la primera instala dependencias y la segunda copia solo el
# codigo. Asi la imagen final no arrastra el codigo fuente de las librerias ni
# sus herramientas de compilacion.

# ---------------------------------------------------------------------------
# Etapa 1: dependencias de produccion
# ---------------------------------------------------------------------------
FROM node:24-alpine AS deps

# pnpm viene incluido en la imagen oficial de Node; `corepack enable` lo activa.
RUN corepack enable

WORKDIR /app

# Se copian primero solo los manifiestos, para que la instalacion se aproveche
# mientras esos archivos no cambien.
COPY package.json pnpm-lock.yaml ./

# `--frozen-lockfile` falla si el lockfile no cuadra con package.json. Es lo que
# se quiere en una imagen: que no se instale una version distinta a la que se
# probo, sin que nadie lo note.
#
# `--ignore-scripts` desactiva los scripts postinstall. pnpm 12 se niega a
# instalar si hay scripts no aprobados, y la unica que hay en el arbol es la de
# @scarf/scarf, que solo manda telemetria. Ninguna dependencia del proyecto
# necesita compilacion nativa (bcryptjs es JavaScript puro), asi que no se
# pierde nada y la imagen no reporta el uso de la base.
RUN pnpm install --frozen-lockfile --prod --ignore-scripts

# ---------------------------------------------------------------------------
# Etapa 2: dependencias completas, para correr las pruebas
# ---------------------------------------------------------------------------
FROM node:24-alpine AS deps-dev

RUN corepack enable

WORKDIR /app

COPY package.json pnpm-lock.yaml ./

# Mismo `--ignore-scripts` que en la etapa de produccion, por el mismo motivo.
RUN pnpm install --frozen-lockfile --ignore-scripts

# ---------------------------------------------------------------------------
# Etapa 3: imagen final
# ---------------------------------------------------------------------------
FROM node:24-alpine AS runtime

# tini reapea los procesos zombis y propaga las senales. Sin el, `docker stop`
# tarda hasta 10 segundos en matar el contenedor.
RUN apk add --no-cache tini

ENV NODE_ENV=production

WORKDIR /app

# `node` (uid 1000) viene en la imagen oficial y evita correr como root: si un
# proceso de la API queda comprometido, no tiene permisos de sistema.
COPY --from=deps --chown=node:node /app/node_modules ./node_modules

COPY --chown=node:node package.json ./
COPY --chown=node:node server.js ./
COPY --chown=node:node src ./src
COPY --chown=node:node scripts ./scripts

# Las imagenes que sube la API se guardan en /app/uploads, que compose monta
# como volumen. Se crea con permisos de node para que el volumen los herede.
RUN mkdir -p /app/uploads && chown -R node:node /app/uploads

USER node

EXPOSE 3000

# Comprobación de vida: sirve para que `docker ps` diga si la API está
# respondiendo de verdad y no solo si el proceso existe.
#
# La sonda usa `wget` y no Node. Antes era `node -e "..."`, que arrancaba un
# proceso Node **completo** cada 15 segundos: 5.760 al día, para preguntarle a un
# servidor que ya se sabe que está vivo. `wget` cuesta 0,00 s, y la diferencia en
# una máquina de 7,9 GB donde Docker compite con Gradle no es cosmética.
#
# El intervalo es de 30 s y no de 15 porque nada espera a esta sonda: la
# dependencia de arranque la resuelve el healthcheck de MySQL, no este. Este solo
# informa. Bajarlo a 15 s solo servía para llenar el log de líneas iguales.
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=5 \
  CMD wget -q -O /dev/null "http://127.0.0.1:${PORT:-3000}/health" || exit 1

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "server.js"]

# ---------------------------------------------------------------------------
# Etapa opcional: para correr las pruebas dentro del contenedor
#
#   docker build --target test -t milkdata-test .
#   docker run --rm milkdata-test
# ---------------------------------------------------------------------------
FROM deps-dev AS test

COPY --chown=node:node package.json ./
COPY --chown=node:node jest.config.js ./
COPY --chown=node:node server.js ./
COPY --chown=node:node src ./src
COPY --chown=node:node scripts ./scripts
COPY --chown=node:node tests ./tests

# `deps-dev` instala como root y `WORKDIR` crea `/app` con dueño root, así que
# el usuario `node` no puede ni leer `node_modules/.bin` ni crear carpetas. Los
# tests lo necesitan de las dos formas: pnpm 12 verifica dependencias antes de
# correr un script, y `src/app.js` hace `mkdirSync('uploads')` al importarse.
USER root
RUN mkdir -p /app/uploads /app/coverage && chown -R node:node /app

USER node

# Las pruebas de integracion necesitan una MySQL real. Hay que levantar los
# servicios antes de correrlas; el README lo explica.
CMD ["pnpm", "test", "--runInBand"]