# =============================================================================
# Helper: Get-TerraformOutputs
# FALLBACK: Read-only terraform init + output -json when pipeline artifact
# is unavailable (e.g., manual re-run of a single stage).
#
# Primary path in P4: pipeline artifacts (DownloadPipelineArtifact@2).
# This helper exists for defensive programming — if artifact download fails,
# scripts can fall back to reading outputs directly from state.
#
# Returns: PSObject with terraform output values
# =============================================================================

param(
    [Parameter(Mandatory)][string]$TfDir,
    [Parameter(Mandatory)][string]$BackendKey,
    [string]$BackendResourceGroup  = "rg-atlas-tfstate",
    [string]$BackendStorageAccount = "atlastfstate2606",
    [string]$BackendContainer      = "tfstate"
)

$ErrorActionPreference = "Stop"

Write-Host "##[warning]Using fallback: reading Terraform outputs directly from state"

Push-Location $TfDir

try {
    # Init in read-only mode (no changes to state)
    $initOutput = terraform init -reconfigure `
        "-backend-config=resource_group_name=$BackendResourceGroup" `
        "-backend-config=storage_account_name=$BackendStorageAccount" `
        "-backend-config=container_name=$BackendContainer" `
        "-backend-config=key=$BackendKey" `
        -input=false 2>&1 | Out-String

    if ($LASTEXITCODE -ne 0) {
        throw "Terraform init failed: $initOutput"
    }

    # Read outputs as JSON
    $outputJson = terraform output -json 2>&1 | Out-String

    if ($LASTEXITCODE -ne 0) {
        throw "Terraform output failed: $outputJson"
    }

    return ($outputJson | ConvertFrom-Json)
}
finally {
    Pop-Location
}