/**
 * 🔮 Crystal DevOps Demo — Integration Test Suite (Node.js)
 * Tests all API endpoints and verifies responses
 */

const http = require('http');

const BASE_URL = 'http://localhost:3000';
let PASS = 0;
let FAIL = 0;

// ── Colors ────────────────────────────────────────────────────────────────────
const C = {
  reset:  '\x1b[0m',
  bold:   '\x1b[1m',
  green:  '\x1b[32m',
  red:    '\x1b[31m',
  cyan:   '\x1b[36m',
  purple: '\x1b[35m',
  yellow: '\x1b[33m',
};

function header(msg) {
  console.log(`\n${C.bold}${C.purple}=== ${msg} ===${C.reset}`);
}

function pass(test) {
  PASS++;
  console.log(`  ${C.green}PASS${C.reset} - ${test}`);
}

function fail(test, detail = '') {
  FAIL++;
  console.log(`  ${C.red}FAIL${C.reset} - ${test}${detail ? `\n       ${C.red}${detail}${C.reset}` : ''}`);
}

// ── HTTP Helpers ──────────────────────────────────────────────────────────────
function request(method, path, body = null) {
  return new Promise((resolve, reject) => {
    const opts = {
      hostname: 'localhost',
      port: 3000,
      path,
      method,
      headers: { 'Content-Type': 'application/json' },
    };

    const req = http.request(opts, (res) => {
      let data = '';
      res.on('data', chunk => { data += chunk; });
      res.on('end', () => {
        let parsed = null;
        try { parsed = JSON.parse(data); } catch { parsed = data; }
        resolve({ status: res.statusCode, data: parsed, raw: data });
      });
    });

    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

function assertStatus(name, actual, expected = 200) {
  if (actual === expected) {
    pass(`${name} returns HTTP ${expected}`);
    return true;
  }
  fail(`${name} returns HTTP ${expected}`, `Got ${actual}`);
  return false;
}

function assertField(name, obj, field, expectedVal = null) {
  if (!obj || typeof obj !== 'object') {
    fail(name, 'Response is null or not an object');
    return;
  }
  if (!(field in obj)) {
    fail(name, `Missing field: "${field}"`);
    return;
  }
  if (expectedVal !== null && obj[field] !== expectedVal) {
    fail(name, `Expected "${field}" = "${expectedVal}", got "${obj[field]}"`);
    return;
  }
  pass(name);
}

function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

// ── Test Suites ───────────────────────────────────────────────────────────────

async function testRoot() {
  header('1. ROOT ENDPOINT');
  const { status, data } = await request('GET', '/');
  assertStatus('GET /', status);
  assertField('  Has "service" field',   data, 'service');
  assertField('  Has "version" field',   data, 'version');
  assertField('  Has "language" field',  data, 'language');
  assertField('  Has "endpoints" field', data, 'endpoints');
  assertField('  Has "uptime" field',    data, 'uptime');
}

async function testHealth() {
  header('2. HEALTH CHECKS');

  const { status: s1, data: health } = await request('GET', '/health');
  assertStatus('GET /health', s1);
  assertField('  status = "healthy"',    health, 'status', 'healthy');
  assertField('  Has uptime_seconds',    health, 'uptime_seconds');
  assertField('  Has timestamp',         health, 'timestamp');
  assertField('  Has checks',            health, 'checks');
  assertField('  Has language',          health, 'language');

  const { status: s2 } = await request('GET', '/ready');
  assertStatus('GET /ready', s2);

  const { status: s3 } = await request('GET', '/live');
  assertStatus('GET /live', s3);
}

async function testMetrics() {
  header('3. METRICS');

  const { status, data } = await request('GET', '/metrics');
  assertStatus('GET /metrics', status);
  assertField('  Has uptime_seconds',    data, 'uptime_seconds');
  assertField('  Has total_requests',    data, 'total_requests');
  assertField('  Has crystal_version',   data, 'crystal_version');
  assertField('  Has avg_response_ms',   data, 'avg_response_ms');
  assertField('  Has p99_response_ms',   data, 'p99_response_ms');
  assertField('  Has memory_mb',         data, 'memory_mb');
  assertField('  Has requests_per_minute', data, 'requests_per_minute');
  assertField('  Has error_rate_pct',    data, 'error_rate_pct');

  const { status: s2, raw } = await request('GET', '/metrics/prometheus');
  assertStatus('GET /metrics/prometheus', s2);
  if (raw.includes('crystal_uptime_seconds')) {
    pass('  Prometheus format contains crystal_uptime_seconds');
  } else {
    fail('  Prometheus format', 'Missing crystal_uptime_seconds metric');
  }
  if (raw.includes('crystal_requests_total')) {
    pass('  Prometheus format contains crystal_requests_total');
  } else {
    fail('  Prometheus format', 'Missing crystal_requests_total metric');
  }
}

async function testPipelines() {
  header('4. PIPELINE - LIST & STATS');

  const { status, data } = await request('GET', '/pipeline');
  assertStatus('GET /pipeline', status);
  assertField('  Has "total"',         data, 'total');
  assertField('  Has "runs"',          data, 'runs');
  assertField('  Has "success_count"', data, 'success_count');
  assertField('  Has "failure_count"', data, 'failure_count');

  if (Array.isArray(data.runs)) {
    pass('  "runs" is an array');
  } else {
    fail('  "runs" is an array', `Got: ${typeof data.runs}`);
  }

  const { status: s2, data: stats } = await request('GET', '/pipeline/stats/summary');
  assertStatus('GET /pipeline/stats/summary', s2);
  assertField('  Stats has "success_rate"', stats, 'success_rate');
  assertField('  Stats has "grade"',        stats, 'grade');
  assertField('  Stats has "total_runs"',   stats, 'total_runs');
}

async function testPipelineTrigger() {
  header('5. PIPELINE - TRIGGER & STATUS');

  const { status, data } = await request('POST', '/pipeline/run', {
    branch: 'main',
    pipeline_name: 'integration-test-pipeline',
    inject_failure: false,
  });
  assertStatus('POST /pipeline/run', status, 202);
  assertField('  Has "run_id"',   data, 'run_id');
  assertField('  Has "status"',   data, 'status');
  assertField('  Has "poll_url"', data, 'poll_url');

  if (data && data.run_id) {
    await sleep(500);
    const { status: s2, data: runData } = await request('GET', `/pipeline/${data.run_id}`);
    assertStatus(`GET /pipeline/${data.run_id.slice(0, 12)}...`, s2);
    assertField('  Run has "pipeline_name"', runData, 'pipeline_name');
    assertField('  Run has "stages"',        runData, 'stages');
    assertField('  Run has "branch"',        runData, 'branch');
    assertField('  Run has "passed_stages"', runData, 'passed_stages');
  }
}

async function testPipelineFailureInjection() {
  header('6. PIPELINE - FAILURE INJECTION');

  const { status, data } = await request('POST', '/pipeline/run', {
    branch: 'buggy/feature',
    inject_failure: true,
  });
  assertStatus('POST /pipeline/run (inject_failure=true)', status, 202);

  if (data && data.run_id) {
    pass(`  Failure pipeline accepted with ID: ${data.run_id}`);

    // Wait for it to fail at stage 3
    await sleep(4500);
    const { data: runData } = await request('GET', `/pipeline/${data.run_id}`);

    if (runData && runData.status === 'failed') {
      pass('  Pipeline correctly transitioned to "failed" status');
    } else {
      console.log(`  ${C.yellow}  NOTE: Pipeline still running, status: ${runData?.status}${C.reset}`);
    }

    const failedStage = (runData?.stages || []).find(s => s.status === 'failed');
    if (failedStage) {
      pass(`  Stage correctly marked "failed": ${failedStage.name}`);
    }

    const skippedStages = (runData?.stages || []).filter(s => s.status === 'skipped');
    if (skippedStages.length > 0) {
      pass(`  Downstream stages correctly "skipped" (${skippedStages.length} stages)`);
    }
  }
}

async function testDeploy() {
  header('7. DEPLOYMENTS');

  const { status: s1, data: deploys } = await request('GET', '/deploy');
  assertStatus('GET /deploy', s1);
  assertField('  Has "total"',       deploys, 'total');
  assertField('  Has "deployments"', deploys, 'deployments');

  const { status: s2, data: newDep } = await request('POST', '/deploy', {
    app_name: 'crystal-test-app',
    version: 'v2.0.0-test',
    environment: 'staging',
    strategy: 'blue-green',
  });
  assertStatus('POST /deploy (blue-green)', s2, 202);
  assertField('  Has "deployment_id"', newDep, 'deployment_id');
  assertField('  Has "strategy"',      newDep, 'strategy', 'blue-green');
  assertField('  Has "poll_url"',      newDep, 'poll_url');

  if (newDep && newDep.deployment_id) {
    await sleep(500);
    const { status: s3, data: depStatus } = await request('GET', `/deploy/${newDep.deployment_id}`);
    assertStatus(`GET /deploy/${newDep.deployment_id.slice(0, 14)}...`, s3);
    assertField('  Deploy has "app_name"',  depStatus, 'app_name', 'crystal-test-app');
    assertField('  Deploy has "status"',    depStatus, 'status');
    assertField('  Deploy has "logs"',      depStatus, 'logs');
    assertField('  Deploy has "strategy"',  depStatus, 'strategy', 'blue-green');
  }
}

async function testErrorHandling() {
  header('8. ERROR HANDLING');

  const { status: s1 } = await request('GET', '/pipeline/nonexistent-id-12345');
  assertStatus('GET /pipeline/nonexistent returns 404', s1, 404);

  const { status: s2 } = await request('GET', '/deploy/nonexistent-id-12345');
  assertStatus('GET /deploy/nonexistent returns 404', s2, 404);

  const { status: s3 } = await request('GET', '/this-route-does-not-exist');
  assertStatus('GET /unknown-route returns 404', s3, 404);
}

// ── Runner ─────────────────────────────────────────────────────────────────────
async function run() {
  console.log('\n' + '='.repeat(50));
  console.log(`${C.bold}${C.purple}   🔮 Crystal DevOps Demo — Test Suite${C.reset}`);
  console.log(`${C.bold}${C.purple}      Integration Tests (Node.js)${C.reset}`);
  console.log('='.repeat(50));
  console.log(`   ${C.cyan}Base URL: ${BASE_URL}${C.reset}`);
  console.log(`   ${C.cyan}Time:     ${new Date().toISOString()}${C.reset}\n`);

  try {
    await testRoot();
    await testHealth();
    await testMetrics();
    await testPipelines();
    await testPipelineTrigger();
    await testPipelineFailureInjection();
    await testDeploy();
    await testErrorHandling();
  } catch (e) {
    console.error(`\n${C.red}Fatal error: ${e.message}${C.reset}`);
    console.error('Is the server running? Start with: node server.js');
    process.exit(1);
  }

  // ── Summary ──────────────────────────────────────────────────────────────
  const total = PASS + FAIL;
  const rate = total > 0 ? ((PASS / total) * 100).toFixed(1) : 0;

  console.log('\n' + '='.repeat(50));
  console.log(`${C.bold}   Test Results${C.reset}`);
  console.log('='.repeat(50));
  console.log(`   Total:  ${total} tests`);
  console.log(`   ${C.green}Passed: ${PASS} ✅${C.reset}`);
  if (FAIL > 0) {
    console.log(`   ${C.red}Failed: ${FAIL} ❌${C.reset}`);
  } else {
    console.log(`   Failed: 0`);
  }
  console.log(`   Rate:   ${rate}%`);
  console.log('');

  if (FAIL === 0) {
    console.log(`${C.green}${C.bold}   🎉 All tests passed! Crystal DevOps API is healthy.${C.reset}`);
  } else {
    console.log(`${C.red}${C.bold}   ⚠️  ${FAIL} tests failed.${C.reset}`);
  }
  console.log('');

  process.exit(FAIL > 0 ? 1 : 0);
}

run();
