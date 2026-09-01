# syntax=docker/dockerfile:1
#
# Dois estagios: o SDK do Flutter some na imagem final. O Railway (e o
# docker run local) so ve o Caddy servindo build/web na $PORT.
#
# API_BASE_URL e de build, nao de runtime: o dart-define entra no JS
# compilado. Sem ela o AppConfig cairia em 10.0.2.2 e o site nao falaria
# com ninguem. Nao inclua /api/v1 -- o AppConfig ja concatena o prefixo.

ARG FLUTTER_VERSION=3.44.8

FROM debian:bookworm-slim AS build

ARG FLUTTER_VERSION

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      unzip \
      xz-utils \
      zip \
 && rm -rf /var/lib/apt/lists/*

ENV FLUTTER_HOME=/opt/flutter \
    PUB_CACHE=/root/.pub-cache \
    FLUTTER_SUPPRESS_ANALYTICS=true
ENV PATH="${FLUTTER_HOME}/bin:${FLUTTER_HOME}/bin/cache/dart-sdk/bin:${PATH}"

# SDK oficial do canal stable. A versao e ARG para o Railway poder
# sobrescrever sem editar o Dockerfile.
RUN curl -fsSL -o /tmp/flutter.tar.xz \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
 && tar -xf /tmp/flutter.tar.xz -C /opt \
 && rm /tmp/flutter.tar.xz \
 && git config --global --add safe.directory "${FLUTTER_HOME}" \
 && flutter config --no-analytics --enable-web \
 && flutter precache --web

WORKDIR /app
COPY . .

ARG API_BASE_URL

RUN test -n "$API_BASE_URL" \
 || { echo "API_BASE_URL is required (base URL only, without /api/v1)." >&2; exit 1; }

RUN case "$API_BASE_URL" in \
      */api/v1|*/api/v1/) \
        echo "API_BASE_URL must not include /api/v1; AppConfig already appends it." >&2; \
        exit 1 ;; \
    esac

RUN flutter pub get \
 && flutter build web --release --dart-define=API_BASE_URL="$API_BASE_URL"

FROM caddy:2-alpine

COPY Caddyfile /etc/caddy/Caddyfile
COPY --from=build /app/build/web /usr/share/caddy

# Documentacao: o processo escuta $PORT (padrao 8080 no Caddyfile).
EXPOSE 8080
