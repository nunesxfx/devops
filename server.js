/**
 * 🔮 Crystal DevOps Demo — API Server (Node.js Mock)
 *
 * Este servidor Node.js implementa a mesma API que seria executada
 * pelo código Crystal compilado. Para a apresentação, demonstra:
 *   - Os MESMOS endpoints definidos no código Crystal
 *   - A mesma lógica de pipeline, deploy e métricas
 *   - Comportamento idêntico ao servidor Kemal (Crystal)
 *
 * Em produção: substituído pelo binário Crystal compilado via Docker.
 */

const http = require('http');
const crypto = require('crypto');
const url = require('url');

// ─── Configuration ────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
const CRYSTAL_VERSION = '1.14.0'; // Simulates Crystal runtime version
const START_TIME = Date.now();

// ─── In-Memory Store (mirrors Crystal structs) ────────────────────────────────
const store = {
  pipelines: [],
  deployments: [],
  metrics: {
    requestCount: 0,
    errorCount: 0,
    responseTimes: [],
  },
};

// ─── Utility Functions ────────────────────────────────────────────────────────
function randomHex(bytes) {
  return crypto.randomBytes(bytes).toString('hex').slice(0, bytes * 2);
}

function recordRequest(durationMs, success = true) {
  store.metrics.requestCount++;
  if (!success) store.metrics.errorCount++;
  store.metrics.responseTimes.push(durationMs);
  if (store.metrics.responseTimes.length > 1000) {
    store.metrics.responseTimes = store.metrics.responseTimes.slice(-1000);
  }
}

function uptimeSeconds() {
  return Math.floor((Date.now() - START_TIME) / 1000);
}

function avgResponseTime() {
  const times = store.metrics.responseTimes;
  if (!times.length) return 0;
  return parseFloat((times.reduce((a, b) => a + b, 0) / times.length).toFixed(2));
}

function p99ResponseTime() {
  const sorted = [...store.metrics.responseTimes].sort((a, b) => a - b);
  if (!sorted.length) return 0;
  const idx = Math.ceil(sorted.length * 0.99) - 1;
  return sorted[Math.max(0, idx)];
}

function formatUptime(seconds) {
  const d = Math.floor(seconds / 86400);
  const h = Math.floor((seconds % 86400) / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  return `${d}d ${h}h ${m}m ${s}s`;
}

function reqPerMinute() {
  const uptime = uptimeSeconds();
  if (!uptime) return 0;
  return parseFloat((store.metrics.requestCount / (uptime / 60)).toFixed(2));
}

// ─── Pipeline Logic ───────────────────────────────────────────────────────────
function createDefaultStages() {
  return [
    { name: '🔍 Lint & Format', duration_ms: 800,  status: 'pending', logs: [] },
    { name: '🏗️  Build',         duration_ms: 2500, status: 'pending', logs: [] },
    { name: '🧪 Unit Tests',    duration_ms: 1800, status: 'pending', logs: [] },
    { name: '🔒 Security Scan', duration_ms: 1200, status: 'pending', logs: [] },
    { name: '📦 Package',       duration_ms: 900,  status: 'pending', logs: [] },
    { name: '🚀 Deploy',        duration_ms: 1500, status: 'pending', logs: [] },
  ];
}

const STAGE_LOGS = [
  ['  → crystal tool format --check src/', '  → ameba src/ — 0 issues found'],
  ['  → shards install', '  → crystal build --release src/main.cr', '  → Binary size: 4.2MB | Build time: 2.5s'],
  ['  → crystal spec --verbose', '  → 24 examples, 0 failures, 0 errors'],
  ['  → trivy image crystal:1.14-alpine', '  → 0 critical, 0 high CVEs found'],
  ['  → docker build --tag crystal-devops-demo', '  → Image size: 52MB (multi-stage optimized)'],
  ['  → kubectl set image deploy/app', '  → Rollout complete — 3/3 pods healthy'],
];

async function executePipeline(run, injectFailure) {
  run.status = 'running';

  for (let i = 0; i < run.stages.length; i++) {
    const stage = run.stages[i];
    stage.status = 'running';
    stage.logs.push(`[${new Date().toISOString()}] Starting stage: ${stage.name}`);

    await new Promise(r => setTimeout(r, stage.duration_ms));

    // Inject failure at Unit Tests (index 2)
    if (injectFailure && i === 2) {
      stage.status = 'failed';
      stage.logs.push(`[${new Date().toISOString()}] ❌ FAILED: 3 tests failed`);
      stage.logs.push('  - spec/pipeline_spec.cr:42 — Expected 200, got 500');
      stage.logs.push('  - spec/health_spec.cr:18 — Connection refused');
      run.status = 'failed';
      run.finished_at = new Date().toISOString();
      run.stages.slice(i + 1).forEach(s => s.status = 'skipped');
      return;
    }

    stage.status = 'success';
    stage.logs.push(`[${new Date().toISOString()}] ✅ Completed in ${stage.duration_ms}ms`);
    (STAGE_LOGS[i] || []).forEach(l => stage.logs.push(l));
  }

  run.status = 'success';
  run.finished_at = new Date().toISOString();
}

function triggerPipeline({ pipeline_name = 'crystal-devops-demo', branch = 'main', inject_failure = false } = {}) {
  const run = {
    id: `run-${randomHex(8)}`,
    pipeline_name,
    branch,
    commit_sha: randomHex(4),
    triggered_by: 'push',
    status: 'queued',
    stages: createDefaultStages(),
    started_at: new Date().toISOString(),
    finished_at: null,
  };
  store.pipelines.unshift(run);

  // Async execution (mirrors Crystal fiber)
  executePipeline(run, inject_failure).catch(console.error);
  return run;
}

// ─── Deployment Logic ─────────────────────────────────────────────────────────
async function simulateDeployment(dep) {
  dep.status = 'running';
  dep.logs.push(`[${new Date().toISOString()}] 🚀 Starting ${dep.strategy} deployment`);
  dep.logs.push(`[${new Date().toISOString()}] 📦 Pulling image: ${dep.app_name}:${dep.version}`);

  await new Promise(r => setTimeout(r, 1000));

  dep.status = 'healthchecking';
  dep.logs.push(`[${new Date().toISOString()}] 🔍 Running health checks...`);

  for (let i = 0; i < 3; i++) {
    await new Promise(r => setTimeout(r, 800));
    dep.health_checks_passed++;
    dep.logs.push(`[${new Date().toISOString()}] ✅ Health check ${i + 1}/3 passed`);
  }

  await new Promise(r => setTimeout(r, 500));
  dep.status = 'success';
  dep.finished_at = new Date().toISOString();
  dep.logs.push(`[${new Date().toISOString()}] 🎉 Deployment successful! ${dep.version} is live.`);
  dep.logs.push(`[${new Date().toISOString()}] 💙 Blue-green switch complete — 100% traffic routed.`);
}

// ─── Router ───────────────────────────────────────────────────────────────────
function router(req, res, pathname, body) {
  const start = Date.now();

  // CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Content-Type', 'application/json');

  if (req.method === 'OPTIONS') {
    res.writeHead(204); res.end(); return;
  }

  const send = (code, data) => {
    const json = JSON.stringify(data, null, 2);
    recordRequest(Date.now() - start, code < 400);
    res.writeHead(code);
    res.end(json);
  };

  // ── GET / ────────────────────────────────────────────────────────────────
  if (req.method === 'GET' && pathname === '/') {
    return send(200, {
      service: '🔮 Crystal DevOps Demo',
      version: '1.0.0',
      language: `Crystal ${CRYSTAL_VERSION}`,
      description: 'High-performance DevOps demonstration system',
      endpoints: {
        health:           'GET /health',
        metrics:          'GET /metrics',
        metrics_prom:     'GET /metrics/prometheus',
        pipeline_list:    'GET /pipeline',
        pipeline_trigger: 'POST /pipeline/run',
        pipeline_status:  'GET /pipeline/:id',
        pipeline_stats:   'GET /pipeline/stats/summary',
        deploy_list:      'GET /deploy',
        deploy_trigger:   'POST /deploy',
        deploy_status:    'GET /deploy/:id',
      },
      uptime: uptimeSeconds(),
    });
  }

  // ── GET /health ──────────────────────────────────────────────────────────
  if (req.method === 'GET' && pathname === '/health') {
    return send(200, {
      status: 'healthy',
      service: 'crystal-devops-demo',
      version: '1.0.0',
      language: `Crystal ${CRYSTAL_VERSION}`,
      uptime_seconds: uptimeSeconds(),
      timestamp: new Date().toISOString(),
      checks: { api: '✅ UP', memory: '✅ OK', fiber: '✅ 3 active' },
    });
  }

  if (req.method === 'GET' && pathname === '/ready') {
    return send(200, { ready: true, timestamp: new Date().toISOString() });
  }

  if (req.method === 'GET' && pathname === '/live') {
    return send(200, { alive: true });
  }

  // ── GET /metrics ─────────────────────────────────────────────────────────
  if (req.method === 'GET' && pathname === '/metrics') {
    const uptime = uptimeSeconds();
    const total = store.metrics.requestCount;
    const errors = store.metrics.errorCount;
    return send(200, {
      uptime_seconds:      uptime,
      uptime_human:        formatUptime(uptime),
      total_requests:      total,
      error_count:         errors,
      error_rate_pct:      total > 0 ? parseFloat(((errors / total) * 100).toFixed(2)) : 0,
      avg_response_ms:     avgResponseTime(),
      p99_response_ms:     p99ResponseTime(),
      requests_per_minute: reqPerMinute(),
      crystal_version:     CRYSTAL_VERSION,
      language:            'Crystal',
      memory_mb:           parseFloat((18.5 + uptime / 36000).toFixed(2)),
    });
  }

  // ── GET /metrics/prometheus ──────────────────────────────────────────────
  if (req.method === 'GET' && pathname === '/metrics/prometheus') {
    const uptime = uptimeSeconds();
    const prom = [
      '# HELP crystal_uptime_seconds Application uptime in seconds',
      '# TYPE crystal_uptime_seconds gauge',
      `crystal_uptime_seconds ${uptime}`,
      '',
      '# HELP crystal_requests_total Total HTTP requests',
      '# TYPE crystal_requests_total counter',
      `crystal_requests_total ${store.metrics.requestCount}`,
      '',
      '# HELP crystal_errors_total Total HTTP errors',
      '# TYPE crystal_errors_total counter',
      `crystal_errors_total ${store.metrics.errorCount}`,
      '',
      '# HELP crystal_response_time_avg_ms Average response time',
      '# TYPE crystal_response_time_avg_ms gauge',
      `crystal_response_time_avg_ms ${avgResponseTime()}`,
      '',
      '# HELP crystal_response_time_p99_ms P99 response time',
      '# TYPE crystal_response_time_p99_ms gauge',
      `crystal_response_time_p99_ms ${p99ResponseTime()}`,
    ].join('\n');
    recordRequest(Date.now() - start);
    res.setHeader('Content-Type', 'text/plain; version=0.0.4');
    res.writeHead(200);
    res.end(prom);
    return;
  }

  // ── GET /pipeline ────────────────────────────────────────────────────────
  if (req.method === 'GET' && pathname === '/pipeline') {
    const success = store.pipelines.filter(r => r.status === 'success').length;
    const failure = store.pipelines.filter(r => r.status === 'failed').length;
    return send(200, {
      total: store.pipelines.length,
      success_count: success,
      failure_count: failure,
      runs: store.pipelines.slice(0, 20),
    });
  }

  // ── GET /pipeline/stats/summary ──────────────────────────────────────────
  if (req.method === 'GET' && pathname === '/pipeline/stats/summary') {
    const total = store.pipelines.length;
    const success = store.pipelines.filter(r => r.status === 'success').length;
    const failure = store.pipelines.filter(r => r.status === 'failed').length;
    const rate = total > 0 ? parseFloat(((success / total) * 100).toFixed(1)) : 0;
    const grade = rate >= 95 ? 'A+ 🏆' : rate >= 85 ? 'A  ✅' : rate >= 70 ? 'B  ⚠️' : rate >= 50 ? 'C  🟡' : 'F  ❌';
    return send(200, { total_runs: total, success, failures: failure, success_rate: rate, grade });
  }

  // ── POST /pipeline/run ───────────────────────────────────────────────────
  if (req.method === 'POST' && pathname === '/pipeline/run') {
    const params = body || {};
    const run = triggerPipeline({
      pipeline_name: params.pipeline_name || 'crystal-devops-demo',
      branch: params.branch || 'main',
      inject_failure: !!params.inject_failure,
    });
    return send(202, {
      message: 'Pipeline triggered successfully',
      run_id: run.id,
      status: run.status,
      poll_url: `/pipeline/${run.id}`,
    });
  }

  // ── GET /pipeline/:id ────────────────────────────────────────────────────
  const pipelineMatch = pathname.match(/^\/pipeline\/([^/]+)$/);
  if (req.method === 'GET' && pipelineMatch) {
    const run = store.pipelines.find(r => r.id === pipelineMatch[1]);
    if (!run) return send(404, { error: 'Pipeline run not found', id: pipelineMatch[1] });

    const durationMs = run.finished_at
      ? new Date(run.finished_at) - new Date(run.started_at)
      : null;

    return send(200, {
      ...run,
      total_duration_ms: durationMs,
      passed_stages: run.stages.filter(s => s.status === 'success').length,
      total_stages: run.stages.length,
    });
  }

  // ── GET /deploy ──────────────────────────────────────────────────────────
  if (req.method === 'GET' && pathname === '/deploy') {
    return send(200, {
      total: store.deployments.length,
      deployments: store.deployments.slice(0, 20),
    });
  }

  // ── POST /deploy ─────────────────────────────────────────────────────────
  if (req.method === 'POST' && pathname === '/deploy') {
    const params = body || {};
    const dep = {
      id: `deploy-${randomHex(8)}`,
      app_name: params.app_name || 'crystal-devops-demo',
      version: params.version || `v1.0.${Math.floor(Math.random() * 100)}`,
      environment: params.environment || 'production',
      strategy: params.strategy || 'blue-green',
      status: 'pending',
      started_at: new Date().toISOString(),
      finished_at: null,
      health_checks_passed: 0,
      health_checks_total: 3,
      success_rate: 0,
      logs: [],
    };
    store.deployments.unshift(dep);
    simulateDeployment(dep).catch(console.error);

    return send(202, {
      message: 'Deployment initiated',
      deployment_id: dep.id,
      strategy: dep.strategy,
      poll_url: `/deploy/${dep.id}`,
    });
  }

  // ── GET /deploy/:id ──────────────────────────────────────────────────────
  const deployMatch = pathname.match(/^\/deploy\/([^/]+)$/);
  if (req.method === 'GET' && deployMatch) {
    const dep = store.deployments.find(d => d.id === deployMatch[1]);
    if (!dep) return send(404, { error: 'Deployment not found', id: deployMatch[1] });
    return send(200, {
      ...dep,
      success_rate: dep.health_checks_total > 0
        ? parseFloat(((dep.health_checks_passed / dep.health_checks_total) * 100).toFixed(2))
        : 0,
    });
  }

  // ── 404 ──────────────────────────────────────────────────────────────────
  return send(404, { error: 'Not Found', path: pathname });
}

// ─── HTTP Server ──────────────────────────────────────────────────────────────
const server = http.createServer((req, res) => {
  const parsed = url.parse(req.url, true);
  const pathname = parsed.pathname;

  let body = '';
  req.on('data', chunk => { body += chunk; });
  req.on('end', () => {
    let parsed_body = null;
    try { parsed_body = body ? JSON.parse(body) : null; } catch {}
    router(req, res, pathname, parsed_body);
  });
});

// ─── Startup ──────────────────────────────────────────────────────────────────
server.listen(PORT, () => {
  console.log('\n' + '═'.repeat(55));
  console.log('  🔮 Crystal DevOps Demo — API Server');
  console.log('  (Running via Node.js — Production: Crystal binary)');
  console.log('═'.repeat(55));
  console.log(`  🌐 API:       http://localhost:${PORT}`);
  console.log(`  📊 Dashboard: http://localhost:8080  (open index.html)`);
  console.log(`  💡 Language:  Crystal ${CRYSTAL_VERSION} (simulated)`);
  console.log(`  ⏱  Started:   ${new Date().toISOString()}`);
  console.log('═'.repeat(55));
  console.log('  Endpoints:');
  console.log(`    GET  /health        → Health check`);
  console.log(`    GET  /metrics       → Metrics snapshot`);
  console.log(`    POST /pipeline/run  → Trigger CI/CD pipeline`);
  console.log(`    POST /deploy        → Trigger blue-green deploy`);
  console.log('═'.repeat(55) + '\n');

  // Seed demo data after 1 second
  setTimeout(async () => {
    console.log('🌱 Seeding demo data...');
    const branches = ['main', 'develop', 'feature/crystal-perf'];
    for (const branch of branches) {
      triggerPipeline({ branch });
      await new Promise(r => setTimeout(r, 300));
    }
    console.log('✅ Demo data seeded! 3 pipelines running...\n');
  }, 1000);
});

server.on('error', err => {
  if (err.code === 'EADDRINUSE') {
    console.error(`❌ Port ${PORT} is already in use. Try: npx kill-port ${PORT}`);
  } else {
    console.error('Server error:', err);
  }
  process.exit(1);
});

// Graceful shutdown
process.on('SIGTERM', () => { server.close(() => process.exit(0)); });
process.on('SIGINT',  () => { console.log('\n👋 Shutting down Crystal DevOps Demo'); server.close(() => process.exit(0)); });
