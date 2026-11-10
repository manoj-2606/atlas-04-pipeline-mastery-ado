# =============================================================================
# Deploy — Helm Upgrade/Install + Rollout Status + Smoke Test
#
# Reads AKS/ACR info from pipeline artifact — no terraform init.
# Deploys to specified namespace with per-environment values file.
#
# Multi-env promotion:
#   dev  → auto deploy on every push
#   staging → requires approval gate (configured in ADO Environment)
# =============================================================================

param(
    [Parameter(Mandatory)][string]$TfOutputsPath,
    [Parameter(Mandatory)][string]$ChartPath,
    [Parameter(Mandatory)][string]$ValuesFile,
    [Parameter(Mandatory)][string]$Namespace,
    [Parameter(Mandatory)][string]$ReleaseName,
    [Parameter(Mandatory)][string]$ImageName,
    [Parameter(Mandatory)][string]$ImageTag,
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
    $aksClusterName  = $tfOutputs.aks_cluster_name.value
    $resourceGroup   = $tfOutputs.resource_group_name.value
    $acrLoginServer  = $tfOutputs.acr_login_server.value

    Write-Host "  AKS Cluster: $aksClusterName"
    Write-Host "  RG:          $resourceGroup"
    Write-Host "  Namespace:   $Namespace"

    # --- Get AKS Credentials ---
    Write-Host "##[section]Getting AKS credentials"
    $output = az aks get-credentials `
        --resource-group $resourceGroup `
        --name $aksClusterName `
        --overwrite-existing 2>&1 | Out-String

    if ($LASTEXITCODE -ne 0) { throw "Failed to get AKS credentials: $output" }

    # --- Create Namespace (if not exists) ---
    Write-Host "##[section]Ensuring namespace: $Namespace"
    kubectl create namespace $Namespace 2>&1 | Out-Null
    # Ignore error if namespace already exists

    # --- Helm Deploy ---
    Write-Host "##[section]Helm Deploy — $ReleaseName to $Namespace"

    $fullImage = "${acrLoginServer}/${ImageName}"
    $valuesPath = Join-Path $ChartPath $ValuesFile

    if (-not (Test-Path $valuesPath)) {
        throw "Values file not found: $valuesPath"
    }

    $output = helm upgrade --install $ReleaseName $ChartPath `
        --namespace $Namespace `
        --values $valuesPath `
        --set "image.repository=$fullImage" `
        --set "image.tag=$ImageTag" `
        --wait `
        --timeout 300s 2>&1 | Out-String

    if ($LASTEXITCODE -ne 0) {
        $errorLines = ($output -split "`n" | Select-Object -Last 10) -join "; "
        throw "Helm deploy failed: $errorLines"
    }

    Write-Host $output

    # --- Rollout Status ---
    Write-Host "##[section]Checking rollout status"
    $output = kubectl rollout status deployment/$ReleaseName-atlas-platform-app `
        --namespace $Namespace `
        --timeout=120s 2>&1 | Out-String

    if ($LASTEXITCODE -ne 0) {
        # Capture pod events for debugging
        $podEvents = kubectl get events --namespace $Namespace `
            --sort-by='.lastTimestamp' 2>&1 | Out-String | Select-Object -Last 15
        throw "Rollout failed: $output | Events: $podEvents"
    }

    Write-Host "##[section]Rollout complete"

    # --- Smoke Test ---
    Write-Host "##[section]Smoke Test — /health endpoint"

    # Get a running pod name
    $podName = kubectl get pods --namespace $Namespace `
        -l "app.kubernetes.io/name=atlas-platform-app" `
        --field-selector=status.phase=Running `
        -o jsonpath='{.items[0].metadata.name}' 2>&1 | Out-String
    $podName = $podName.Trim()

    if (-not $podName) {
        throw "No running pods found for atlas-platform-app in namespace $Namespace"
    }

    # curl /health from inside the pod
    $healthResponse = kubectl exec $podName --namespace $Namespace `
        -- python -c "import urllib.request; print(urllib.request.urlopen('http://localhost:8000/health').read().decode())" `
        2>&1 | Out-String

    if ($LASTEXITCODE -ne 0) {
        throw "Smoke test failed: $healthResponse"
    }

    Write-Host "##[section]Smoke test passed: $($healthResponse.Trim())"
    Write-Host "##[section]Deploy complete — $ReleaseName ($Namespace)"
}
catch {
    & "$HelpersDir/Write-ErrorContext.ps1" `
        -ErrorMessage $_.Exception.Message `
        -ScriptName "deploy.ps1" `
        -LineNumber "$($_.InvocationInfo.ScriptLineNumber)"
    throw
}