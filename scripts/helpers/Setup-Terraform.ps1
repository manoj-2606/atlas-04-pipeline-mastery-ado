# =============================================================================
# Helper: Setup-Terraform
# Installs pinned Terraform version + sets all 5 OIDC env vars.
# Called by: infra.ps1, destroy.ps1
#
# Why pinned version: Microsoft-hosted agents don't have Terraform installed.
# Why not latest: reproducible builds. Same version across all projects.
#
# Requires: AzureCLI@2 task with addSpnToEnvironment: true
# That injects: $env:servicePrincipalId, $env:idToken, $env:tenantId
# =============================================================================

param(
    [string]$Version = "1.9.8"
)

$ErrorActionPreference = "Stop"

# --- Install Terraform ---
Write-Host "##[section]Installing Terraform $Version"

$tfZip = "/tmp/terraform_${Version}_linux_amd64.zip"
$tfUrl = "https://releases.hashicorp.com/terraform/${Version}/terraform_${Version}_linux_amd64.zip"

Invoke-WebRequest -Uri $tfUrl -OutFile $tfZip -UseBasicParsing

# Validate download (not an HTML 404 page)
$fileSize = (Get-Item $tfZip).Length
if ($fileSize -lt 1000000) {
    throw "Downloaded file too small ($fileSize bytes) — likely a 404 page, not Terraform binary"
}

Expand-Archive -Path $tfZip -DestinationPath /usr/local/bin -Force
Remove-Item $tfZip

$installed = terraform --version 2>&1 | Select-Object -First 1
Write-Host "##[section]$installed"

# --- Set OIDC Environment Variables ---
# These are required by the AzureRM Terraform provider for OIDC auth.
# Without ALL 5, terraform init/plan/apply will fail with auth errors.

if (-not $env:servicePrincipalId) {
    throw "servicePrincipalId not set — ensure AzureCLI@2 has addSpnToEnvironment: true"
}
if (-not $env:idToken) {
    throw "idToken not set — ensure service connection uses OIDC (Workload Identity Federation)"
}
if (-not $env:tenantId) {
    throw "tenantId not set — ensure AzureCLI@2 has addSpnToEnvironment: true"
}

$env:ARM_CLIENT_ID       = $env:servicePrincipalId
$env:ARM_OIDC_TOKEN      = $env:idToken
$env:ARM_TENANT_ID       = $env:tenantId
$env:ARM_SUBSCRIPTION_ID = (az account show --query id -o tsv)
$env:ARM_USE_OIDC         = "true"

Write-Host "##[section]OIDC env vars set — ARM_CLIENT_ID: $($env:ARM_CLIENT_ID.Substring(0,8))..."
Write-Host "##[section]ARM_SUBSCRIPTION_ID: $($env:ARM_SUBSCRIPTION_ID.Substring(0,8))..."