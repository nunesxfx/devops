<div align="center">

# 🔮 Crystal DevOps Demo

**Sistema de demonstração DevOps em Crystal Lang**
Pipelines CI/CD · Deployments Blue-Green · Métricas Prometheus · Dashboard em tempo real

[![Node.js](https://img.shields.io/badge/Node.js-≥18-green?logo=node.js)](https://nodejs.org)
[![Crystal](https://img.shields.io/badge/Crystal-1.14-purple?logo=crystal)](https://crystal-lang.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue)](LICENSE)
[![Tests](https://img.shields.io/badge/Tests-62%20passing-brightgreen)](#-testes)

</div>

---

## 📋 Pré-requisitos

Só é necessário **Node.js ≥ 18** para rodar a demonstração.

> Verifique com: `node --version`  
> Download: https://nodejs.org

---

## 🚀 Início Rápido (após fork/clone)

```cmd
git clone https://github.com/SEU-USUARIO/crystal-devops-demo.git
cd crystal-devops-demo

npm start
```

Abra o dashboard: **`dashboard\index.html`** no navegador

---

## 🧪 Rodar os Testes

```cmd
npm test
```

Resultado esperado:
```
Total:  62 tests
Passed: 62 ✅
Failed: 0
Rate:   100.0%

🎉 All tests passed! Crystal DevOps API is healthy.
```

---

## 📡 Endpoints da API

A API roda em `http://localhost:3000`

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| GET | `/` | Info geral + versão Crystal |
| GET | `/health` | Health check (Kubernetes-ready) |
| GET | `/ready` | Readiness probe |
| GET | `/live` | Liveness probe |
| GET | `/metrics` | Métricas JSON completas |
| GET | `/metrics/prometheus` | Formato Prometheus |
| GET | `/pipeline` | Lista todos os pipelines |
| `POST` | `/pipeline/run` | Trigga novo pipeline CI/CD |
| GET | `/pipeline/:id` | Status de um pipeline |
| GET | `/pipeline/stats/summary` | Stats com grade (A+, A, B...) |
| GET | `/deploy` | Lista deployments |
| `POST` | `/deploy` | Trigga deploy blue-green |
| GET | `/deploy/:id` | Status de um deployment |

### Exemplos com curl

```cmd
REM Health check
curl http://localhost:3000/health

REM Métricas
curl http://localhost:3000/metrics

REM Trigger pipeline
curl -X POST http://localhost:3000/pipeline/run ^
  -H "Content-Type: application/json" ^
  -d "{\"branch\":\"main\",\"inject_failure\":false}"

REM Deploy blue-green
curl -X POST http://localhost:3000/deploy ^
  -H "Content-Type: application/json" ^
  -d "{\"app_name\":\"my-app\",\"version\":\"v2.0.0\",\"environment\":\"production\",\"strategy\":\"blue-green\"}"

REM Injetar falha (para demo)
curl -X POST http://localhost:3000/pipeline/run ^
  -H "Content-Type: application/json" ^
  -d "{\"branch\":\"buggy/feature\",\"inject_failure\":true}"
```

---

## 🏗️ Arquitetura

```
crystal-devops-demo/
│
├── 📂 src/                          # Código Crystal Lang (produção)
│   ├── main.cr                      # Entry point (Kemal HTTP Server)
│   ├── routes/
│   │   ├── health.cr                # /health, /ready, /live
│   │   ├── metrics.cr               # /metrics, /metrics/prometheus
│   │   ├── pipeline.cr              # CI/CD pipeline endpoints
│   │   └── deploy.cr                # Deployment endpoints
│   ├── models/
│   │   ├── deployment.cr            # Deployment struct + enum
│   │   └── pipeline_run.cr          # PipelineRun + stages
│   └── services/
│       ├── pipeline_service.cr      # Async (Crystal Fibers)
│       └── metrics_service.cr       # Thread-safe (Atomic)
│
├── 📂 spec/                         # Crystal unit tests
│   ├── health_spec.cr
│   └── pipeline_spec.cr
│
├── 📂 dashboard/
│   └── index.html                   # Dashboard web em tempo real
│
├── 📂 .github/workflows/
│   └── ci.yml                       # GitHub Actions CI/CD completo
│
├── server.js                        # API server (Node.js — para demo)
├── test.js                          # Suite de 62 testes de integração
├── package.json                     # npm scripts
├── Dockerfile                       # Multi-stage Crystal → Alpine (~50MB)
├── docker-compose.yml               # Crystal API + Nginx
└── shard.yml                        # Dependências Crystal (Kemal)
```

---

## 💎 Por que Crystal?

Crystal é uma linguagem compilada com sintaxe Ruby-like e performance próxima de C.

| Feature | Crystal | Ruby | Go | Java |
|---------|---------|------|----|------|
| Performance | ⚡ C-like | 🐌 | ⚡ | ✅ |
| Sintaxe | 💎 Elegante | 💎 | 😐 Verbosa | 😓 Verbosa |
| Type Safety | ✅ Compile-time | ❌ Runtime | ✅ | ✅ |
| Binário único | ✅ | ❌ | ✅ | ❌ JVM |
| Docker image | ~50MB | ~500MB | ~15MB | ~300MB |
| Concorrência | 🔮 Fibers | 🔮 | Goroutines | Threads |

---

## 🐳 Em produção: Docker + Crystal

```bash
# Build e start com Crystal nativo
docker-compose up -d --build

# Testes dentro do container
docker-compose exec crystal-api crystal spec --verbose
```

O `Dockerfile` usa multi-stage build:
1. **Stage 1 (builder)**: `crystallang/crystal:1.14-build` — compila o binário
2. **Stage 2 (runtime)**: `alpine:3.19` — imagem final ~50MB

---

## 🎭 Demo Flow (Apresentação)

1. `npm start` → Servidor no ar
2. Abrir `dashboard\index.html`
3. **"▶ Trigger Pipeline"** → ver 6 stages rodando em tempo real
4. **"✕ Inject Failure"** → falha no stage "Unit Tests" + stages skipped
5. **"🚀 Deploy"** → blue-green com health checks automáticos
6. `npm test` → 62 testes passando ao vivo
7. Mostrar `src/main.cr` → elegância Crystal vs Python/Java
8. Mostrar `Dockerfile` → multi-stage, segurança, ~50MB
9. Mostrar `.github/workflows/ci.yml` → CI/CD completo

---

## 📁 Scripts disponíveis

| Comando | Ação |
|---------|------|
| `npm start` | Inicia o servidor na porta 3000 |
| `npm test` | Roda os 62 testes de integração |
| `npm run dev` | Servidor com hot-reload (Node ≥ 18.11) |
| `start.bat` | Iniciar via CMD (Windows) |
| `run-tests.bat` | Testes rápidos via CMD (Windows) |

---

## 📜 Licença

MIT — livre para usar na apresentação, modificar e distribuir.
