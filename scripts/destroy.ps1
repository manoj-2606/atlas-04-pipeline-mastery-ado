# =============================================================================
# Destroy — Terraform Destroy + Delete Backend RG
#
# Order matters:
#   1. terraform destroy (needs state file → backend must still exist)
#   2. az group delete backend RG (removes state storage)
#
# Known issue #13: reversing this order = state file gone before destroy runs.
# =============================================================================

param(
    [Parameter(Mandatory)][string]$TfDir,
    [Parameter(Mandatory)][string]$VarFile,
    [Parameter(Mandatory)][string]$BackendKey,
    [Parameter(Mandatory)][string]$BackendResourceGroup,
    [Parameter(Mandatory)][string]$BackendStorageAccount,
    [Parameter(Mandatory)][string]$BackendContainer,
    [Parameter(Mandatory)][string]$HelpersDir
)

$ErrorActionPreference = "Stop"

try {
    # --- Install Terraform + Set OIDC env vars ---
    & "$HelpersDir/Setup-Terraform.ps1"

    Push-Location $TfDir

    # --- Terraform Init ---
    Write-Host "##[section]Terraform Init (for destroy)"
    $output = terraform init -reconfigure `
        "-backend-config=resource_group_name=$BackendResourceGroup" `
        "-backend-config=storage_account_name=$BackendStorageAccount" `
        "-backend-config=container_name=$BackendContainer" `
        "-backend-config=key=$BackendKey" `
        -input=false 2>&1 | Out-String

    if ($LASTEXITCODE -ne 0) {
        $errorLines = ($output -split "`n" | Where-Object { $_ -match "Error:" }) -join "; "
        if (-not $errorLines) { $errorLines = ($output -split "`n" | Select-Object -Last 5) -join "; " }
        throw "Terraform init failed: $errorLines"
    }

    # --- Terraform Destroy ---
    Write-Host "##[section]Terraform Destroy"
    $output = terraform destroy `
        "-var-file=$VarFile" `
        -auto-approve `
        -input=false 2>&1 | Out-String

    if ($LASTEXITCODE -ne 0) {
        $errorLines = ($output -split "`n" | Where-Object { $_ -match "Error:" }) -join "; "
        if (-not $errorLines) { $errorLines = ($output -split "`n" | Select-Object -Last 5) -join "; " }
        throw "Terraform destroy failed: $errorLines"
    }

    Write-Host $output
    Write-Host "##[section]Project resources destroyed"

    Pop-Location

    # --- Delete Backend Resource Group ---
    Write-Host "##[section]Deleting backend RG: $BackendResourceGroup"

    $rgExists = az group exists --name $BackendResourceGroup 2>&1
    if ($rgExists -eq "true") {
        $output = az group delete `
            --name $BackendResourceGroup `
            --yes `
            --no-wait 2>&1 | Out-String

        if ($LASTEXITCODE -ne 0) {
            Write-Host "##[warning]Backend RG delete may have failed: $output"
        }
        else {
            Write-Host "##[section]Backend RG deletion initiated (--no-wait)"
        }
    }
    else {
        Write-Host "##[section]Backend RG already deleted: $BackendResourceGroup"
    }

    Write-Host "##[section]Full cleanup complete"
}
catch {
    Pop-Location -ErrorAction SilentlyContinue
    & "$HelpersDir/Write-ErrorContext.ps1" `
        -ErrorMessage $_.Exception.Message `
        -ScriptName "destroy.ps1" `
        -LineNumber "$($_.InvocationInfo.ScriptLineNumber)"
    throw
}