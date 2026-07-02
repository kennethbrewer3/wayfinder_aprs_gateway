# Wayfinder APRS Gateway

Dart service that connects to a KISS TCP server (for example Direwolf on an SDR
host), parses APRS packets, and forwards position reports to a Wayfinder mapping
server.

## Docker Compose on the SDR host

Use this when the radio/KISS stack runs on the same machine as Docker. You only
need a small compose file and environment variables; the image is built and
published from this repository.

### 1. Create a directory on the SDR machine

```bash
mkdir -p ~/wayfinder-aprs-gateway
cd ~/wayfinder-aprs-gateway
```

### 2. Add `docker-compose.yml`

```yaml
services:
  wayfinder-aprs-gateway:
    image: ghcr.io/kennethbrewer3/wayfinder_aprs_gateway:latest
    restart: unless-stopped
    extra_hosts:
      - "host.docker.internal:host-gateway"
    env_file:
      - .env
```

Or copy the file from this repo:

```bash
curl -fsSLO https://raw.githubusercontent.com/kennethbrewer3/wayfinder_aprs_gateway/main/deploy/docker-compose.yml
curl -fsSLO https://raw.githubusercontent.com/kennethbrewer3/wayfinder_aprs_gateway/main/deploy/.env.example
cp .env.example .env
```

### 3. Configure `.env`

Edit `.env` and set at least `APRS_MAPPING_SERVER_URL`. Defaults assume KISS is
listening on the host at port `8001`.

| Variable | Description |
| --- | --- |
| `APRS_KISS_HOST` | KISS server hostname from inside the container (`host.docker.internal` reaches the SDR host) |
| `APRS_KISS_PORT` | KISS TCP port (default `8001`) |
| `APRS_MAPPING_SERVER_URL` | HTTP endpoint that accepts position reports |
| `APRS_AUTH_TOKEN` | Optional bearer token sent to the mapping server |
| `APRS_LOG_LEVEL` | `debug`, `info`, `warn`, or `error` |

See [`deploy/.env.example`](deploy/.env.example) for all supported variables.

### 4. Start the gateway

```bash
docker compose pull
docker compose up -d
docker compose logs -f
```

### KISS on localhost with host networking

If you prefer the container to share the host network stack (KISS on
`127.0.0.1`), add `network_mode: host` to the service and set
`APRS_KISS_HOST=127.0.0.1` in `.env`. Remove `extra_hosts` when using host
networking.

## Development

Build and run from source on a dev machine:

```bash
docker compose up --build
```

Configuration can also come from a JSON file; see [`config.example.json`](config.example.json).

```bash
dart pub get
dart run wayfinder_aprs_gateway
```

Run tests:

```bash
dart test
```

## Systemd (non-Docker)

A sample unit file is in [`deploy/wayfinder-aprs-gateway.service`](deploy/wayfinder-aprs-gateway.service).
