# =============================================================================
# Log Error — Reads error-context.json, appends to logs.json, git pushes
#
# Called by: condition: failed() steps in every pipeline template.
# Requires: checkout: self with persistCredentials: true
#
# Auto-captured fields: run, stage, error, scriptLine, timestamp
# Manual fields: cause, fix, prevention (filled after debugging)
#
# ADO Permissions required (set BEFORE first run):
#   Project Settings → Repos → atlas-04-pipeline-mastery-ado → Security
#   Both identities → Allow: Contribute + Bypass policies when pushing
#   - Atlas-Platform Build Service (manojmanojkumar2513)
#   - Project Collection Build Service (manojmanojkumar2513)
# =============================================================================

param(
    [Parameter(Mandatory)][string]$Stage,
    [Parameter(Mandatory)][string]$ProjectDir
)

$ErrorActionPreference = "Stop"

try {
    # --- Read error context (written by Write-ErrorContext.ps1 helper) ---
    $contextPath = Join-Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY "error-context.json"
    $errorDetail = if (Test-Path $contextPath) {
        Get-Content $contextPath -Raw | ConvertFrom-Json
    }
    else {
        @{ error = "No error-context.json found"; script = "unknown"; scriptLine = "unknown"; timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ") }
    }

    # --- Build log entry ---
    $logEntry = [ordered]@{
        run         = $env:BUILD_BUILDNUMBER
        stage       = $Stage
        error       = $errorDetail.error
        script      = $errorDetail.script
        scriptLine  = $errorDetail.scriptLine
        timestamp   = $errorDetail.timestamp
        branch      = $env:BUILD_SOURCEBRANCH
        # Manual fields — fill after debugging
        cause       = ""
        fix         = ""
        prevention  = ""
    }

    # --- Read existing logs.json or initialize ---
    $logsPath = Join-Path $ProjectDir "logs.json"
    $logs = if (Test-Path $logsPath) {
        Get-Content $logsPath -Raw | ConvertFrom-Json
    }
    else {
        @()
    }

    # Convert to ArrayList for .Add() support
    $logsList = [System.Collections.ArrayList]@($logs)
    $logsList.Add($logEntry) | Out-Null

    # --- Write updated logs.json ---
    $logsList | ConvertTo-Json -Depth 5 | Set-Content -Path $logsPath

    # --- Git commit + push ---
    Push-Location $ProjectDir

    git config user.email "pipeline@atlas-platform.dev"
    git config user.name "Atlas Pipeline"
    git add logs.json
    git commit -m "log: $Stage failure — run $($env:BUILD_BUILDNUMBER)" 2>&1 | Out-String

    # Push to ADO repo (uses persisted credentials from checkout: self)
    $pushOutput = git push origin HEAD:main 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        Write-Host "##[warning]Git push failed (non-blocking): $pushOutput"
    }
    else {
        Write-Host "##[section]Error logged to logs.json and pushed to repo"
    }

    Pop-Location
}
catch {
    # log-error.ps1 failure should NOT mask the original error
    Write-Host "##[warning]log-error.ps1 failed (non-blocking): $($_.Exception.Message)"
}