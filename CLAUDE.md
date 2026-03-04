# Observability Stack — CLAUDE.md

Guia para agentes e desenvolvedores integrarem backends nesta stack de observabilidade.

## Visão geral da stack

| Serviço | Porta | Função |
|---|---|---|
| Grafana | 3000 | Visualização (dashboards) |
| Prometheus | 9090 | Coleta e storage de métricas |
| Loki | 3100 | Aggregation de logs |
| Promtail | — | Coleta logs dos containers Docker |
| node-exporter | 9100 | Métricas do host (CPU, RAM, disco) |
| OTEL Collector | 4317 (gRPC), 4318 (HTTP) | Recebe traces/metrics/logs via OTLP e exporta para New Relic e Splunk |
| Splunk | 8000 (UI), 8088 (HEC) | Análise de logs e traces |
| load-generator | — | Gerador de carga para o `observability-demo` |
| observability-demo | 8080 | App de referência (Spring Boot + OTEL) |

Rede Docker interna: `observability`

## Credenciais e variáveis de ambiente

As credenciais sensíveis ficam no arquivo `.env` (não commitado). Copie `.env.example` para `.env` e preencha antes de subir:

```bash
cp .env.example .env
# edite .env com as chaves reais
```

Variáveis disponíveis:

| Variável | Uso |
|---|---|
| `NEW_RELIC_API_KEY` | Chave OTLP do New Relic (OTEL Collector) |
| `SPLUNK_HEC_TOKEN` | Token HEC do Splunk (OTEL Collector) |
| `SPLUNK_PASSWORD` | Senha de admin do Splunk |

## Subindo a stack

```bash
docker compose up -d
```

O `observability-demo` requer um build local em `../../IdeaProjects/observability`. Se não existir, comente ou remova o serviço `observability-demo` e `load-generator` antes de subir.

## Como integrar um backend novo

### 1. Adicionar o serviço ao `docker-compose.yml`

O serviço deve estar na rede `observability`:

```yaml
services:
  meu-backend:
    image: meu-backend:latest        # ou build: ./meu-backend
    container_name: meu-backend
    restart: unless-stopped
    ports:
      - "8081:8081"
    environment:
      # Variáveis OTEL para auto-instrumentação
      - OTEL_SERVICE_NAME=meu-backend
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
      - OTEL_EXPORTER_OTLP_PROTOCOL=grpc
      - OTEL_LOGS_EXPORTER=otlp
      - OTEL_METRICS_EXPORTER=otlp
      - OTEL_TRACES_EXPORTER=otlp
    depends_on:
      - otel-collector
    networks:
      - observability
```

### 2. Expor métricas para o Prometheus

Se o backend expõe métricas no formato Prometheus (ex: Spring Boot Actuator, Micrometer, `/metrics`), adicione um job em `prometheus/prometheus.yml`:

```yaml
scrape_configs:
  # ... jobs existentes ...

  - job_name: "meu-backend"
    metrics_path: /actuator/prometheus   # ajuste o path conforme o framework
    static_configs:
      - targets: ["meu-backend:8081"]    # nome do serviço Docker + porta
```

> Use sempre o **nome do serviço Docker** como host, nunca `localhost` ou `host.docker.internal`.

### 3. Enviar traces, métricas e logs via OTEL

O OTEL Collector escuta em:
- `otel-collector:4317` — gRPC (recomendado para JVM, Go, .NET)
- `otel-collector:4318` — HTTP/JSON (recomendado para Node.js, Python)

#### Java / Spring Boot

Adicione o agente OTEL ao Dockerfile ou entrypoint:

```dockerfile
ADD https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/latest/download/opentelemetry-javaagent.jar /app/otel-agent.jar
ENTRYPOINT ["java", "-javaagent:/app/otel-agent.jar", "-jar", "/app/app.jar"]
```

As variáveis de ambiente da seção anterior cuidam do resto.

#### Node.js

```bash
npm install @opentelemetry/auto-instrumentations-node
```

```js
// tracing.js — importe antes de tudo
require('@opentelemetry/auto-instrumentations-node/register');
```

#### Python

```bash
pip install opentelemetry-distro opentelemetry-exporter-otlp
opentelemetry-bootstrap -a install
opentelemetry-instrument python app.py
```

### 4. Logs via Promtail (automático)

O Promtail coleta automaticamente os logs de **todos** os containers Docker via socket. Não é necessária nenhuma configuração adicional — os logs aparecem no Loki com as labels `container` e `service` do compose.

Para enriquecer as labels, adicione labels Docker ao serviço:

```yaml
    labels:
      - "logging=enabled"
      - "app=meu-backend"
```

### 5. Visualizar no Grafana

Acesse `http://localhost:3000` (admin/admin na primeira vez).

Datasources a configurar manualmente (ou via provisioning em `grafana/provisioning/`):

| Datasource | URL interna |
|---|---|
| Prometheus | `http://prometheus:9090` |
| Loki | `http://loki:3100` |

Dashboards sugeridos (importar pelo ID):
- **Node Exporter Full**: `1860`
- **Spring Boot Observability**: `17175`
- **JVM Micrometer**: `4701`

## Pipelines do OTEL Collector

O collector está configurado em `otel/otel-collector-config.yml` com os seguintes exportadores:

| Sinal | Destinos |
|---|---|
| Traces | New Relic, Splunk HEC, debug |
| Metrics | New Relic, debug |
| Logs | New Relic, Splunk HEC, debug |

Para adicionar um novo exporter (ex: Jaeger, Zipkin, Tempo), edite `otel/otel-collector-config.yml` e adicione o exporter nas pipelines relevantes dentro de `service.pipelines`.

## Convenções para agentes

- Sempre use o **nome do serviço Docker** (não IP ou `localhost`) para comunicação entre containers.
- Credenciais novas vão no `.env` e no `.env.example` (com valor placeholder).
- Novos serviços entram na rede `observability`.
- Após adicionar um job no Prometheus, reinicie apenas o Prometheus: `docker compose restart prometheus`.
- Após alterar o OTEL Collector config, reinicie: `docker compose restart otel-collector`.
- Não modifique o `load-generator` — ele é específico para o `observability-demo`.
