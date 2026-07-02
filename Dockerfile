FROM dart:3.12 AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart pub get --offline
RUN dart compile exe bin/wayfinder_aprs_gateway.dart -o /app/wayfinder_aprs_gateway

FROM debian:bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /app/wayfinder_aprs_gateway /app/wayfinder_aprs_gateway
COPY config.example.json /app/config.example.json

ENV APRS_KISS_HOST=host.docker.internal
ENV APRS_KISS_PORT=8001
ENV APRS_MAPPING_SERVER_URL=http://host.docker.internal:18082
ENV APRS_LOG_LEVEL=info

ENTRYPOINT ["/app/wayfinder_aprs_gateway"]
