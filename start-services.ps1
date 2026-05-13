$ErrorActionPreference = "Stop"

Write-Host "🚀 Starting Docker Compose services..."

docker compose up -d --build
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to start Docker Compose services (exit code $LASTEXITCODE)"
    exit $LASTEXITCODE
}

Write-Host "✅ All services started successfully!"
Write-Host ""
Write-Host "  Frontend : http://localhost:3000"
Write-Host "  API      : http://localhost:8000"
Write-Host "  pgAdmin  : http://localhost:5050"
Write-Host "  Proxy    : https://localhost"
