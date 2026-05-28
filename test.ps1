#!/usr/bin/env pwsh
# ─────────────────────────────────────────────────────────────────────
# Crystal DevOps Demo — Integration Test Script (PowerShell)
# Testa todos os endpoints da API em sequência
# ─────────────────────────────────────────────────────────────────────

param(
    [string]$BaseUrl = "http://localhost:3000",
    [switch]$Verbose = $false
)

$ErrorActionPreference = "Stop"
$PASS = 0
$FAIL = 0
$GREEN  = "`e[32m"
$RED    = "`e[31m"
$CYAN   = "`e[36m"
$PURPLE = "`e[35m"
$BOLD   = "`e[1m"
$RESET  = "`e[0m"

function Write-Header($msg) {
    Write-Host "`n${BOLD}${PURPLE}═══ $msg ═══${RESET}"
}

function Write-Pass($test) {
    $script:PASS++
    Write-Host "  ${GREEN}✅ PASS${RESET} — $test"
}

function Write-Fail($test, $detail) {
    $script:FAIL++
    Write-Host "  ${RED}❌ FAIL${RESET} — $test"
    if ($detail) { Write-Host "        ${RED}$detail${RESET}" }
}

function Invoke-Test($name, $url, $method = "GET", $body = $null, $expectedStatus = 200) {
    try {
        $params = @{
            Uri = $url
            Method = $method
            ContentType = "application/json"
            TimeoutSec = 10
        }
        if ($body) { $params.Body = ($body | ConvertTo-Json -Compress) }

        $response = Invoke-WebRequest @params -SkipHttpErrorCheck
        $status = $response.StatusCode
        $content = $response.Content | ConvertFrom-Json -AsHashtable -ErrorAction SilentlyContinue

        if ($status -eq $expectedStatus) {
            Write-Pass $name
            if ($Verbose -and $content) {
                Write-Host "        Response: $($content | ConvertTo-Json -Compress -Depth 2)"
            }
            return $content
        } else {
            Write-Fail $name "Expected HTTP $expectedStatus, got $status"
            return $null
        }
    } catch {
        Write-Fail $name $_.Exception.Message
        return $null
    }
}

function Test-Field($testName, $obj, $field, $expectedValue = $null) {
    if ($null -eq $obj) {
        Write-Fail $testName "Response was null"
        return
    }
    if (-not $obj.ContainsKey($field)) {
        Write-Fail $testName "Missing field: $field"
        return
    }
    if ($null -ne $expectedValue -and $obj[$field] -ne $expectedValue) {
        Write-Fail $testName "Expected '$field' = '$expectedValue', got '$($obj[$field])'"
        return
    }
    Write-Pass $testName
}

# ─────────────────────────────────────────────────────────────────────
Write-Host "${BOLD}${PURPLE}"
Write-Host "  ╔═══════════════════════════════════════╗"
Write-Host "  ║   🔮 Crystal DevOps Demo — Tests      ║"
Write-Host "  ║      API Integration Test Suite       ║"
Write-Host "  ╚═══════════════════════════════════════╝"
Write-Host "${RESET}"
Write-Host "  ${CYAN}Base URL: $BaseUrl${RESET}"
Write-Host "  ${CYAN}Time:     $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')${RESET}`n"

# ── 1. Connectivity ────────────────────────────────────────────
Write-Header "1. CONNECTIVITY"
$root = Invoke-Test "GET / — Root endpoint" "$BaseUrl/"
Test-Field "  Has 'service' field"  $root "service"
Test-Field "  Has 'version' field"  $root "version"
Test-Field "  Has 'language' field" $root "language"
Test-Field "  Has 'endpoints'"      $root "endpoints"

# ── 2. Health Checks ───────────────────────────────────────────
Write-Header "2. HEALTH CHECKS"
$health = Invoke-Test "GET /health — Health check" "$BaseUrl/health"
Test-Field "  Status = healthy"    $health "status" "healthy"
Test-Field "  Has uptime_seconds"  $health "uptime_seconds"
Test-Field "  Has timestamp"       $health "timestamp"
Test-Field "  Has checks object"   $health "checks"

Invoke-Test "GET /ready  — Readiness probe" "$BaseUrl/ready" | Out-Null
Invoke-Test "GET /live   — Liveness probe"  "$BaseUrl/live"  | Out-Null

# ── 3. Metrics ─────────────────────────────────────────────────
Write-Header "3. METRICS"
$metrics = Invoke-Test "GET /metrics — Metrics snapshot" "$BaseUrl/metrics"
Test-Field "  Has uptime_seconds"    $metrics "uptime_seconds"
Test-Field "  Has total_requests"    $metrics "total_requests"
Test-Field "  Has crystal_version"   $metrics "crystal_version"
Test-Field "  Has avg_response_ms"   $metrics "avg_response_ms"
Test-Field "  Has p99_response_ms"   $metrics "p99_response_ms"
Test-Field "  Has memory_mb"         $metrics "memory_mb"

$promResp = Invoke-WebRequest -Uri "$BaseUrl/metrics/prometheus" -Method GET -TimeoutSec 10 -SkipHttpErrorCheck
if ($promResp.StatusCode -eq 200 -and $promResp.Content -like "*crystal_uptime_seconds*") {
    Write-Pass "GET /metrics/prometheus — Prometheus format"
} else {
    Write-Fail "GET /metrics/prometheus" "Missing prometheus metrics"
}

# ── 4. Pipeline — List ──────────────────────────────────────────
Write-Header "4. PIPELINE — LIST & STATS"
$pipelines = Invoke-Test "GET /pipeline — List runs" "$BaseUrl/pipeline"
Test-Field "  Has 'total' field"         $pipelines "total"
Test-Field "  Has 'runs' array"          $pipelines "runs"
Test-Field "  Has 'success_count'"       $pipelines "success_count"
Test-Field "  Has 'failure_count'"       $pipelines "failure_count"

$stats = Invoke-Test "GET /pipeline/stats/summary" "$BaseUrl/pipeline/stats/summary"
Test-Field "  Stats has 'success_rate'" $stats "success_rate"
Test-Field "  Stats has 'grade'"        $stats "grade"

# ── 5. Pipeline — Trigger ───────────────────────────────────────
Write-Header "5. PIPELINE — TRIGGER & STATUS"
$trigBody = @{ branch = "main"; pipeline_name = "test-pipeline"; inject_failure = $false }
$triggered = Invoke-Test "POST /pipeline/run — Trigger pipeline" "$BaseUrl/pipeline/run" "POST" $trigBody 202
Test-Field "  Has 'run_id'"   $triggered "run_id"
Test-Field "  Has 'poll_url'" $triggered "poll_url"
Test-Field "  Has 'status'"   $triggered "status"

if ($triggered -and $triggered.ContainsKey("run_id")) {
    $runId = $triggered["run_id"]
    Start-Sleep -Seconds 1
    $runStatus = Invoke-Test "GET /pipeline/$runId — Get run status" "$BaseUrl/pipeline/$runId"
    Test-Field "  Run has 'pipeline_name'" $runStatus "pipeline_name"
    Test-Field "  Run has 'stages'"        $runStatus "stages"
    Test-Field "  Run has 'branch'"        $runStatus "branch"
}

# ── 6. Pipeline — Failure Injection ────────────────────────────
Write-Header "6. PIPELINE — FAILURE INJECTION"
$failBody = @{ branch = "buggy-feature"; inject_failure = $true }
$failRun = Invoke-Test "POST /pipeline/run — Inject failure" "$BaseUrl/pipeline/run" "POST" $failBody 202
if ($failRun) {
    Write-Pass "  Failure pipeline accepted (will fail at Unit Tests stage)"
}

# ── 7. Deploy ──────────────────────────────────────────────────
Write-Header "7. DEPLOYMENTS"
$deploys = Invoke-Test "GET /deploy — List deployments" "$BaseUrl/deploy"
Test-Field "  Has 'total'"       $deploys "total"
Test-Field "  Has 'deployments'" $deploys "deployments"

$deployBody = @{
    app_name    = "crystal-test-app"
    version     = "v2.0.0"
    environment = "staging"
    strategy    = "blue-green"
}
$newDeploy = Invoke-Test "POST /deploy — Trigger deployment" "$BaseUrl/deploy" "POST" $deployBody 202
Test-Field "  Has 'deployment_id'" $newDeploy "deployment_id"
Test-Field "  Has 'strategy'"      $newDeploy "strategy"
Test-Field "  Has 'poll_url'"      $newDeploy "poll_url"

if ($newDeploy -and $newDeploy.ContainsKey("deployment_id")) {
    $depId = $newDeploy["deployment_id"]
    Start-Sleep -Milliseconds 500
    $depStatus = Invoke-Test "GET /deploy/$depId — Deployment status" "$BaseUrl/deploy/$depId"
    Test-Field "  Deploy has 'app_name'" $depStatus "app_name"
    Test-Field "  Deploy has 'status'"   $depStatus "status"
}

# ── 8. Error Handling ──────────────────────────────────────────
Write-Header "8. ERROR HANDLING"
Invoke-Test "GET /pipeline/nonexistent — 404 handling" "$BaseUrl/pipeline/nonexistent-id-xyz" "GET" $null 404 | Out-Null
Invoke-Test "GET /deploy/nonexistent   — 404 handling" "$BaseUrl/deploy/nonexistent-id-xyz" "GET" $null 404 | Out-Null

# ── Summary ────────────────────────────────────────────────────
$TOTAL = $PASS + $FAIL
Write-Host ""
Write-Host "${BOLD}${PURPLE}═════════════════════════════════════════${RESET}"
Write-Host "${BOLD}  📊 Test Results${RESET}"
Write-Host "${BOLD}${PURPLE}═════════════════════════════════════════${RESET}"
Write-Host "  Total:  $TOTAL tests"
Write-Host "  ${GREEN}Passed: $PASS ✅${RESET}"
if ($FAIL -gt 0) {
    Write-Host "  ${RED}Failed: $FAIL ❌${RESET}"
} else {
    Write-Host "  Failed: 0"
}

$successRate = if ($TOTAL -gt 0) { [math]::Round(($PASS / $TOTAL) * 100, 1) } else { 0 }
Write-Host "  Rate:   $successRate%"
Write-Host ""

if ($FAIL -eq 0) {
    Write-Host "${GREEN}${BOLD}  🎉 All tests passed! Crystal API is healthy.${RESET}"
} else {
    Write-Host "${RED}${BOLD}  ⚠️  Some tests failed. Is the API running?${RESET}"
    Write-Host "${CYAN}  Tip: Run 'docker-compose up -d' first${RESET}"
}
Write-Host ""
