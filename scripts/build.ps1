# =============================================================================
# Build — Docker Build + Trivy Scan + SBOM + ACR Push
#
# Reads ACR info from pipeline artifact (tf-outputs.json) — no terraform init.
#
# Known issues applied:
# - #6: Trivy installed via apt repo, NOT GitHub release URL
# - #8: Plain docker build, NOT Docker@2 task
# - #9: az acr login + docker push in SAME script (token expiry fix)
# =============================================================================

param(
    [Parameter(Mandatory)][string]$TfOutputsPath,
    [Parameter(Mandatory)][string]$DockerfilePath,
    [Parameter(Mandatory)][string]$BuildContext,
    [Parameter(Mandatory)][string]$ImageName,
    [Parameter(Mandatory)][string]$ImageTag,
    [string]$TrivySeverity = "CRITICAL",
    [Parameter(Mandatory)][string]$HelpersDir
)

$ErrorActionPreference = "Stop"

try {
    # --- Read Terraform Outputs from Pipeline Artifact ---
    Write-Host "##[section]Reading Terraform outputs from artifact"

    if (-not (Test-Path $TfOutputsPath)) {
        throw "tf-outputs.json not found at: $TfOutputsPath"
    }

    $tfOutputs = Get-Content $TfOutputsPath -Raw | ConvertFrom-Json
    $acrName       = $tfOutputs.acr_name.value
    $acrLoginServer = $tfOutputs.acr_login_server.value

    Write-Host "  ACR Name:   $acrName"
    Write-Host "  ACR Server: $acrLoginServer"

    $fullImageName = "${acrLoginServer}/${ImageName}:${ImageTag}"

    # --- Install Trivy via APT Repository ---
    Write-Host "##[section]Installing Trivy (apt repo)"
    & bash -c @"
        sudo apt-get install -y wget apt-transport-https gnupg lsb-release 2>/dev/null
        wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
        echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | sudo tee /etc/apt/sources.list.d/trivy.list
        sudo apt-get update -qq
        sudo apt-get install -y trivy
"@

    $trivyVersion = trivy --version 2>&1 | Select-Object -First 1
    Write-Host "##[section]$trivyVersion"

    # --- Docker Build ---
    Write-Host "##[section]Docker Build"
    $output = docker build `
        -t $fullImageName `
        -f $DockerfilePath `
        $BuildContext 2>&1 | Out-String

    if ($LASTEXITCODE -ne 0) {
        $errorLines = ($output -split "`n" | Select-Object -Last 10) -join "; "
        throw "Docker build failed: $errorLines"
    }

    Write-Host "##[section]Image built: $fullImageName"

    # --- Trivy Scan (fail on CRITICAL) ---
    Write-Host "##[section]Trivy Scan — severity threshold: $TrivySeverity"
    $scanOutput = trivy image `
        --severity $TrivySeverity `
        --exit-code 1 `
        --no-progress `
        --format table `
        $fullImageName 2>&1 | Out-String

    if ($LASTEXITCODE -ne 0) {
        throw "Trivy scan found $TrivySeverity vulnerabilities: $scanOutput"
    }

    Write-Host $scanOutput
    Write-Host "##[section]Trivy scan passed — zero $TrivySeverity CVEs"

    # --- SBOM Generation ---
    Write-Host "##[section]Generating SBOM (SPDX JSON)"
    $sbomPath = Join-Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY "sbom.json"
    trivy image --format spdx-json --output $sbomPath $fullImageName 2>&1 | Out-Null
    Write-Host "##[section]SBOM written to: $sbomPath"

    # --- ACR Login + Push (same step — token expiry fix) ---
    Write-Host "##[section]ACR Login + Push"
    $output = az acr login --name $acrName 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "ACR login failed: $output" }

    $output = docker push $fullImageName 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "Docker push failed: $output" }

    Write-Host "##[section]Image pushed: $fullImageName"
}
catch {
    & "$HelpersDir/Write-ErrorContext.ps1" `
        -ErrorMessage $_.Exception.Message `
        -ScriptName "build.ps1" `
        -LineNumber "$($_.InvocationInfo.ScriptLineNumber)"
    throw
}