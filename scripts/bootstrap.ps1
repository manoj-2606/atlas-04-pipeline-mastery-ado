# =============================================================================
# Bootstrap — Create Terraform backend storage (idempotent)
# Creates: Resource Group → Storage Account → Blob Container
# Safe to run every time — skips resources that already exist.
# =============================================================================

param(
    [Parameter(Mandatory)][string]$ResourceGroup,
    [Parameter(Mandatory)][string]$StorageAccount,
    [Parameter(Mandatory)][string]$Container,
    [string]$Location = "centralindia"
)

$ErrorActionPreference = "Stop"
$helpersDir = Join-Path $PSScriptRoot "helpers"

try {
    Write-Host "##[section]Bootstrap — Backend Storage Setup"

    # --- Resource Group ---
    $rgExists = az group exists --name $ResourceGroup 2>&1
    if ($rgExists -eq "false") {
        Write-Host "##[section]Creating resource group: $ResourceGroup"
        $output = az group create --name $ResourceGroup --location $Location --output none 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { throw "Failed to create RG: $output" }
    }
    else {
        Write-Host "##[section]Resource group exists: $ResourceGroup"
    }

    # --- Storage Account ---
    $saCheck = az storage account show --name $StorageAccount --resource-group $ResourceGroup 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        Write-Host "##[section]Creating storage account: $StorageAccount"
        $output = az storage account create `
            --name $StorageAccount `
            --resource-group $ResourceGroup `
            --location $Location `
            --sku Standard_LRS `
            --kind StorageV2 `
            --allow-blob-public-access false `
            --output none 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { throw "Failed to create storage account: $output" }
    }
    else {
        Write-Host "##[section]Storage account exists: $StorageAccount"
    }

    # --- Blob Container ---
    Write-Host "##[section]Ensuring container exists: $Container"
    $output = az storage container create `
        --name $Container `
        --account-name $StorageAccount `
        --auth-mode login `
        --output none 2>&1 | Out-String

    Write-Host "##[section]Bootstrap complete — backend ready"
    Write-Host "  Resource Group:  $ResourceGroup"
    Write-Host "  Storage Account: $StorageAccount"
    Write-Host "  Container:       $Container"
}
catch {
    & "$helpersDir/Write-ErrorContext.ps1" `
        -ErrorMessage $_.Exception.Message `
        -ScriptName "bootstrap.ps1" `
        -LineNumber "$($_.InvocationInfo.ScriptLineNumber)"
    throw
}