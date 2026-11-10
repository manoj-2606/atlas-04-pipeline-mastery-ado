# =============================================================================
# Helper: Write-ErrorContext
# Writes error-context.json to BUILD_ARTIFACTSTAGINGDIRECTORY.
# Called in every catch block across all scripts.
# log-error.ps1 reads this file to populate logs.json.
#
# Standardizes error capture format — no more inconsistent error objects.
# =============================================================================

param(
    [Parameter(Mandatory)][string]$ErrorMessage,
    [string]$ScriptName = "",
    [string]$LineNumber = ""
)

$errorContext = @{
    error      = $ErrorMessage
    script     = $ScriptName
    scriptLine = if ($LineNumber) { $LineNumber } else { "unknown" }
    timestamp  = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
}

# Use BUILD_ARTIFACTSTAGINGDIRECTORY if available, otherwise /tmp
$outputDir = if ($env:BUILD_ARTIFACTSTAGINGDIRECTORY) {
    $env:BUILD_ARTIFACTSTAGINGDIRECTORY
} else {
    "/tmp"
}

$outputPath = Join-Path $outputDir "error-context.json"
$errorContext | ConvertTo-Json -Depth 3 | Set-Content -Path $outputPath

Write-Host "##[warning]Error context written to: $outputPath"
Write-Host "##[warning]Error: $ErrorMessage"