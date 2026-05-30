# Эквивалент `make up` для Windows (PowerShell).
# Запускать из корня mono репозитория: .\start.ps1
$ErrorActionPreference = "Stop"

Write-Host "-> Pulling latest changes..."
git pull origin main
git submodule update --remote --merge

Write-Host "-> Building and starting services (waiting for health checks)..."
docker compose up -d --build --wait
if ($LASTEXITCODE -ne 0) {
    Write-Error "docker compose failed (exit code $LASTEXITCODE)"
    exit $LASTEXITCODE
}

Write-Host "-> Applying DB migrations..."
$check = docker compose exec api sh -c "command -v alembic >/dev/null 2>&1 && echo yes || echo no" 2>$null
if ($check -eq "yes") {
    docker compose exec api alembic upgrade head
} else {
    Write-Host "  i  alembic not configured yet - skipping (see .agents/add-model.md)"
}

Write-Host ""
Write-Host "OK Stack is up. See: https://notebook.com"
