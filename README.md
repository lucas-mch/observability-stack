# Observability Stack

Self-hosted observability environment for SRE study.

## Services

| Service | URL | Credentials |
|---|---|---|
| Grafana | http://localhost:3000 | admin / admin |
| Prometheus | http://localhost:9090 | - |
| Loki | http://localhost:3100 | - |
| Node Exporter | http://localhost:9100 | - |
| Splunk | http://localhost:8000 | admin / changeme123 |
| Splunk HEC | http://localhost:8088 | - |

## Architecture

```
[Node Exporter] --metrics--> [Prometheus] --datasource--> [Grafana]
[Docker Logs]   --scrape-->  [Promtail]   --push-->       [Loki] --datasource--> [Grafana]
[Any Source]    --HEC/Fwd--> [Splunk]
```

## Quick Start

```bash
docker compose up -d
```

## Post-Setup: Grafana Datasources

1. Open Grafana at http://localhost:3000
2. Go to Connections > Data Sources > Add data source
3. Add **Prometheus**: URL = `http://prometheus:9090`
4. Add **Loki**: URL = `http://loki:3100`

## Post-Setup: Grafana Dashboards

Import community dashboards via Dashboard > Import:
- **Node Exporter Full**: ID `1860`
- **Docker Container Monitoring**: ID `893`

## Splunk Free License

Limited to 500MB/day indexing. HEC (HTTP Event Collector) is exposed on port 8088
for sending events programmatically from applications.

## Volumes

All data is persisted in Docker named volumes. To reset:

```bash
docker compose down -v
```
