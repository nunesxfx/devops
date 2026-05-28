@echo off
REM ═══════════════════════════════════════════════════════
REM   Crystal DevOps Demo - Teste rapido via CMD
REM ═══════════════════════════════════════════════════════

echo.
echo  ========================================
echo   Crystal DevOps Demo - Testes Rapidos
echo  ========================================
echo.

echo [1/5] Testando /health ...
curl -s http://localhost:3000/health | node -e "process.stdin.resume();let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{let j=JSON.parse(d);console.log('  Status:',j.status,'  Uptime:',j.uptime_seconds+'s','  Lang:',j.language)})"
echo.

echo [2/5] Testando /metrics ...
curl -s http://localhost:3000/metrics | node -e "process.stdin.resume();let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{let j=JSON.parse(d);console.log('  Requests:',j.total_requests,'  Avg RT:',j.avg_response_ms+'ms','  Memory:',j.memory_mb+'MB')})"
echo.

echo [3/5] Triggering pipeline (branch=main) ...
curl -s -X POST http://localhost:3000/pipeline/run -H "Content-Type: application/json" -d "{\"branch\":\"main\",\"inject_failure\":false}" | node -e "process.stdin.resume();let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{let j=JSON.parse(d);console.log('  Pipeline ID:',j.run_id,'  Status:',j.status,'  Poll:',j.poll_url)})"
echo.

echo [4/5] Triggering deploy (blue-green) ...
curl -s -X POST http://localhost:3000/deploy -H "Content-Type: application/json" -d "{\"app_name\":\"crystal-app\",\"version\":\"v1.0.99\",\"environment\":\"production\",\"strategy\":\"blue-green\"}" | node -e "process.stdin.resume();let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{let j=JSON.parse(d);console.log('  Deploy ID:',j.deployment_id,'  Strategy:',j.strategy)})"
echo.

echo [5/5] Rodando suite completa de testes ...
node test.js
echo.
