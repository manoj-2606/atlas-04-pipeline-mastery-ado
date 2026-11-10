# =============================================================================
# Infra — Terraform Init + Plan + Apply + Export Outputs
#
# After apply, generates tf-outputs.json for PublishPipelineArtifact.
# Downstream stages download this instead of re-running terraform init.
#
# Known issues applied:
# - #3: Quoted compound arguments ("-var-file=$VarFile")
# - #4: Real stderr capture, never hardcoded error strings
# - #14: NEVER pass -var-file to terraform apply with saved plan
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
    Write-Host "##[section]Terraform Init"
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

    # --- Terraform Plan ---
    Write-Host "##[section]Terraform Plan"
    $output = terraform plan `
        "-var-file=$VarFile" `
        -out=tfplan `
        -input=false 2>&1 | Out-String

    if ($LASTEXITCODE -ne 0) {
        $errorLines = ($output -split "`n" | Where-Object { $_ -match "Error:" }) -join "; "
        if (-not $errorLines) { $errorLines = ($output -split "`n" | Select-Object -Last 5) -join "; " }
        throw "Terraform plan failed: $errorLines"
    }

    Write-Host $output

    # --- Terraform Apply (saved plan — NO -var-file here) ---
    Write-Host "##[section]Terraform Apply"
    $output = terraform apply -input=false tfplan 2>&1 | Out-String

    if ($LASTEXITCODE -ne 0) {
        $errorLines = ($output -split "`n" | Where-Object { $_ -match "Error:" }) -join "; "
        if (-not $errorLines) { $errorLines = ($output -split "`n" | Select-Object -Last 5) -join "; " }
        throw "Terraform apply failed: $errorLines"
    }

    Write-Host $output

    # --- Export Outputs as JSON (for pipeline artifact) ---
    Write-Host "##[section]Exporting Terraform Outputs"
    $tfOutputs = terraform output -json 2>&1 | Out-String

    if ($LASTEXITCODE -ne 0) {
        throw "Terraform output -json failed: $tfOutputs"
    }

    $outputPath = Join-Path $TfDir "tf-outputs.json"
    Set-Content -Path $outputPath -Value $tfOutputs
    Write-Host "##[section]Outputs written to: $outputPath"

    # Log key values (not sensitive ones)
    $parsed = $tfOutputs | ConvertFrom-Json
    Write-Host "  resource_group: $($parsed.resource_group_name.value)"
    Write-Host "  acr_name:       $($parsed.acr_name.value)"
    Write-Host "  aks_cluster:    $($parsed.aks_cluster_name.value)"

    Pop-Location
}
catch {
    Pop-Location -ErrorAction SilentlyContinue
    & "$HelpersDir/Write-ErrorContext.ps1" `
        -ErrorMessage $_.Exception.Message `
        -ScriptName "infra.ps1" `
        -LineNumber "$($_.InvocationInfo.ScriptLineNumber)"
    throw
}