$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
Write-Host "Starting backend server on port $($env:PORT ?? '5000')..."
node index.js
