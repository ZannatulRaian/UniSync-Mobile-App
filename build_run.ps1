# UniSync — PowerShell build helper
# Usage: .\build_run.ps1          (clean build + run)
#        .\build_run.ps1 codegen  (codegen only)
#        .\build_run.ps1 run      (run only)

param([string]$task = "all")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Run($cmd) {
    Write-Host "`n>> $cmd" -ForegroundColor Cyan
    Invoke-Expression $cmd
    if ($LASTEXITCODE -ne 0) { throw "Command failed: $cmd" }
}

switch ($task) {
    "codegen" {
        Run "dart run build_runner build --delete-conflicting-outputs"
    }
    "run" {
        Run "flutter run"
    }
    default {
        Run "flutter clean"
        Run "flutter pub get"
        Run "dart run build_runner build --delete-conflicting-outputs"
        Run "flutter run"
    }
}
