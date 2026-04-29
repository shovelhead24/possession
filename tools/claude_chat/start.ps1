$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $dir

if (-not $env:ANTHROPIC_API_KEY) {
    Write-Host "ANTHROPIC_API_KEY not set." -ForegroundColor Yellow
    $key = Read-Host "Enter your Anthropic API key"
    $env:ANTHROPIC_API_KEY = $key
}

if (-not (Test-Path "node_modules")) {
    Write-Host "Installing dependencies..." -ForegroundColor Cyan
    npm install
}

Write-Host "Starting Claude Chat..." -ForegroundColor Green
node server.js
