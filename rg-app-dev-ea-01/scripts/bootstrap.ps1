#requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

Write-Host "Starting bootstrap..." -ForegroundColor Green

# Validate Winget
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "Winget is not installed on this image."
}

Write-Host "Installing Git..." -ForegroundColor Cyan

winget install `
    --id Git.Git `
    --exact `
    --scope machine `
    --silent `
    --accept-package-agreements `
    --accept-source-agreements

Write-Host "Installing Azure CLI..." -ForegroundColor Cyan

winget install `
    --id Microsoft.AzureCLI `
    --exact `
    --scope machine `
    --silent `
    --accept-package-agreements `
    --accept-source-agreements

Write-Host "Installing .NET SDK 8..." -ForegroundColor Cyan

winget install `
    --id Microsoft.DotNet.SDK.8 `
    --exact `
    --scope machine `
    --silent `
    --accept-package-agreements `
    --accept-source-agreements

Write-Host "Installing Visual Studio 2022 Build Tools..." -ForegroundColor Cyan

winget install `
    --id Microsoft.VisualStudio.2022.BuildTools `
    --exact `
    --scope machine `
    --silent `
    --accept-package-agreements `
    --accept-source-agreements

Write-Host "Installing Az PowerShell module..." -ForegroundColor Cyan

Set-PSRepository `
    -Name PSGallery `
    -InstallationPolicy Trusted

Install-Module `
    -Name Az `
    -Scope AllUsers `
    -Force `
    -AllowClobber

Write-Host "Installing Bicep..." -ForegroundColor Cyan

$env:PATH += ";C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin"

az bicep install

Write-Host "Validating installed tools..." -ForegroundColor Cyan

Write-Host "Git version:"
git --version

Write-Host "Azure CLI version:"
az version

Write-Host ".NET SDK version:"
dotnet --version

$azModule = Get-Module Az -ListAvailable |
    Sort-Object Version -Descending |
    Select-Object -First 1

if ($null -ne $azModule) {
    Write-Host "Az Module Version: $($azModule.Version)"
}
else {
    Write-Warning "Az PowerShell module was not found."
}

Write-Host "Validation completed." -ForegroundColor Green

Write-Host "Bootstrap completed successfully." -ForegroundColor Green
