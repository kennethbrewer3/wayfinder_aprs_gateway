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

Edit `.env` and set at least `APRS_MAPPING_SERVER_URL` to your Wayfinder **web
server** (port `18082`, not the Serverpod API port `18080`). Defaults assume
KISS is listening on the host at port `8001`.

| Variable | Description |
| --- | --- |
| `APRS_PACKET_SOURCE` | Input source: `kiss` (default), `simulator`, `replay`, or `aprsis` |
| `APRS_SIMULATOR_CONFIG` | Path to simulator scenario JSON when `APRS_PACKET_SOURCE=simulator` |
| `APRS_SIMULATOR_LAYER_NAME` | Wayfinder layer for simulated markers/tracks (default `APRS Simulator`) |
| `APRS_KISS_HOST` | KISS server hostname from inside the container (`host.docker.internal` reaches the SDR host) |
| `APRS_KISS_PORT` | KISS TCP port (default `8001`) |
| `APRS_MAPPING_SERVER_URL` | Wayfinder **web server** base URL (REST API, default port `18082`) |
| `APRS_AUTH_TOKEN` | Optional bearer token sent to the mapping server |
| `APRS_LOG_LEVEL` | `debug`, `info`, `warn`, or `error` |

See [`deploy/.env.example`](deploy/.env.example) for all supported variables, or start from a mode-specific example in [`deploy/env/`](deploy/env/):

- [`deploy/env/.env.kiss.example`](deploy/env/.env.kiss.example) — Direwolf/KISS with bridge networking
- [`deploy/env/.env.kiss.host-network.example`](deploy/env/.env.kiss.host-network.example) — KISS with `network_mode: host`
- [`deploy/env/.env.simulator.example`](deploy/env/.env.simulator.example) — simulator with bridge networking
- [`deploy/env/.env.simulator.host-network.example`](deploy/env/.env.simulator.host-network.example) — simulator with `network_mode: host`

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

## Simulator scenarios

When `APRS_PACKET_SOURCE=simulator`, point `APRS_SIMULATOR_CONFIG` at a JSON
file describing the stations to emit. See
[`deploy/simulator.example.json`](deploy/simulator.example.json) for a sample
with all supported station types:

| `type` | Behavior |
| --- | --- |
| `car` | Moves along `waypoints`; tracking marker with `landVehicle` mode |
| `boat` | Moves along `waypoints`; tracking marker with `watercraft` mode |
| `aircraft` | Moves along `waypoints`; tracking marker with `aircraft` mode |
| `hiker` | Moves along `waypoints`; tracking marker with `onFoot` mode |
| `train` | Moves along `waypoints`; tracking marker with `landVehicle` mode |
| `weather` | Fixed location with `weather` telemetry fields |
| `repeater` | Fixed location |

Each mobile station supports `waypoints` (or legacy `route`): the simulator
interpolates position between consecutive points at `speedKnots`. Set `"loop":
false` to stop at the final waypoint instead of repeating. Mobile updates
create or update Wayfinder markers via `/api/markers` with `isTracking: true`
when configured in the scenario.

Each station supports `callsign`, optional `comment`, and optional `speedKnots`.
Global emission interval is controlled by top-level `intervalSeconds`.

Example Docker setup:

```bash
cp deploy/env/.env.simulator.example .env
cp deploy/simulator.example.json simulator.json
docker compose up -d
```

Mount `simulator.json` into the container at the path set in
`APRS_SIMULATOR_CONFIG` (see commented volume in
[`deploy/docker-compose.yml`](deploy/docker-compose.yml)).

On startup in simulator mode, the gateway creates or reuses a Wayfinder layer
named **`APRS Simulator`** (override with `APRS_SIMULATOR_LAYER_NAME`), clears
markers and zones on that layer, and assigns all simulated updates to it.
Tracking trails inherit the marker layer on the Wayfinder server.

Set `APRS_AUTH_TOKEN` to a Wayfinder REST API key (`wf_...`); it is sent as
`Authorization: Bearer` for REST requests. You can also use
`APRS_AUTH_HEADER=X-API-Key` with an empty `APRS_AUTH_SCHEME`.

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
