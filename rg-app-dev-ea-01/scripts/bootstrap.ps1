
#requires -RunAsAdministrator

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Write-Host "Starting bootstrap..." -ForegroundColor Green

# ------------------------------------------------------------
# 1. Bootstrap WinGet
# ------------------------------------------------------------

Write-Host "Checking WinGet..." -ForegroundColor Cyan

$wingetCommand = Get-Command winget.exe -ErrorAction SilentlyContinue

if (-not $wingetCommand) {
    Write-Host "WinGet not found. Installing its PowerShell bootstrap module..." -ForegroundColor Yellow

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    Install-PackageProvider `
        -Name NuGet `
        -MinimumVersion 2.8.5.201 `
        -Force | Out-Null

    Set-PSRepository `
        -Name PSGallery `
        -InstallationPolicy Trusted

    Install-Module `
        -Name Microsoft.WinGet.Client `
        -Repository PSGallery `
        -Scope AllUsers `
        -Force `
        -AllowClobber

    Import-Module Microsoft.WinGet.Client -Force

    Write-Host "Repairing/bootstrapping WinGet for all users..." -ForegroundColor Cyan

    Repair-WinGetPackageManager -AllUsers

    # Refresh command discovery after package installation.
    $wingetCommand = Get-Command winget.exe -ErrorAction SilentlyContinue
}

# WinGet may be installed as an MSIX package without its alias
# being available in the current process PATH.
if (-not $wingetCommand) {
    $wingetPackagePaths = @(
        Get-ChildItem `
            -Path "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*__8wekyb3d8bbwe\winget.exe" `
            -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending
    )

    if ($wingetPackagePaths.Count -gt 0) {
        $wingetPath = $wingetPackagePaths[0].FullName
    }
    else {
        throw "WinGet bootstrap did not provide a usable winget.exe. Windows Server 2022 may not support this installation method."
    }
}
else {
    $wingetPath = $wingetCommand.Source
}

if (-not (Test-Path $wingetPath)) {
    throw "WinGet executable was not found at: $wingetPath"
}

Write-Host "WinGet executable: $wingetPath" -ForegroundColor Green

& $wingetPath --version

if ($LASTEXITCODE -ne 0) {
    throw "WinGet is installed but failed its version check."
}

# ------------------------------------------------------------
# 2. Helper function for package installations
# ------------------------------------------------------------

function Install-WinGetPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id
    )

    Write-Host "Installing $Id..." -ForegroundColor Cyan

    & $script:wingetPath install `
        --id $Id `
        --exact `
        --scope machine `
        --silent `
        --accept-package-agreements `
        --accept-source-agreements

    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        throw "WinGet installation failed for '$Id'. Exit code: $exitCode"
    }

    Write-Host "$Id installation completed." -ForegroundColor Green
}

# ------------------------------------------------------------
# 3. Install Git
# ------------------------------------------------------------

Install-WinGetPackage -Id "Git.Git"

# ------------------------------------------------------------
# 4. Install Azure CLI
# ------------------------------------------------------------

Install-WinGetPackage -Id "Microsoft.AzureCLI"

# ------------------------------------------------------------
# 5. Install .NET SDK 8
# ------------------------------------------------------------

Install-WinGetPackage -Id "Microsoft.DotNet.SDK.8"

# ------------------------------------------------------------
# 6. Install Visual Studio 2022 Build Tools
# ------------------------------------------------------------

Install-WinGetPackage -Id "Microsoft.VisualStudio.2022.BuildTools"

# ------------------------------------------------------------
# 7. Refresh PATH for newly installed machine-wide tools
# ------------------------------------------------------------

Write-Host "Refreshing machine PATH..." -ForegroundColor Cyan

$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")

$env:Path = "$machinePath;$userPath"

# Common Azure CLI installation directory.
$azureCliPath = "C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin"

if (Test-Path $azureCliPath) {
    if ($env:Path -notlike "*$azureCliPath*") {
        $env:Path = "$azureCliPath;$env:Path"
    }
}

# ------------------------------------------------------------
# 8. Install Az PowerShell module
# ------------------------------------------------------------

Write-Host "Installing Az PowerShell module..." -ForegroundColor Cyan

Set-PSRepository `
    -Name PSGallery `
    -InstallationPolicy Trusted

Install-Module `
    -Name Az `
    -Repository PSGallery `
    -Scope AllUsers `
    -Force `
    -AllowClobber

# ------------------------------------------------------------
# 9. Install Bicep CLI
# ------------------------------------------------------------

Write-Host "Installing Bicep..." -ForegroundColor Cyan

$azCommand = Get-Command az.cmd -ErrorAction SilentlyContinue

if (-not $azCommand) {
    $azCommand = Get-Command az -ErrorAction SilentlyContinue
}

if (-not $azCommand) {
    throw "Azure CLI was installed but az could not be located in PATH."
}

& $azCommand.Source bicep install

if ($LASTEXITCODE -ne 0) {
    throw "Azure CLI failed to install Bicep. Exit code: $LASTEXITCODE"
}

# ------------------------------------------------------------
# 10. Validate installed tools
# ------------------------------------------------------------

Write-Host "Validating installed tools..." -ForegroundColor Cyan

Write-Host "`nWinGet version:"
& $script:wingetPath --version

Write-Host "`nGit version:"
$gitCommand = Get-Command git.exe -ErrorAction SilentlyContinue

if ($gitCommand) {
    & $gitCommand.Source --version
}
else {
    Write-Warning "Git was installed, but git.exe is not currently discoverable in PATH."
}

Write-Host "`nAzure CLI version:"
& $azCommand.Source version

Write-Host "`n.NET SDK version:"
$dotnetCommand = Get-Command dotnet.exe -ErrorAction SilentlyContinue

if ($dotnetCommand) {
    & $dotnetCommand.Source --version
}
else {
    Write-Warning ".NET SDK was installed, but dotnet.exe is not currently discoverable in PATH."
}

Write-Host "`nAz PowerShell module version:"
$azModule = Get-Module Az -ListAvailable |
    Sort-Object Version -Descending |
    Select-Object -First 1

if ($null -ne $azModule) {
    Write-Host "Az Module Version: $($azModule.Version)"
}
else {
    throw "Az PowerShell module was not found after installation."
}

Write-Host "`nBicep version:"
& $azCommand.Source bicep version

if ($LASTEXITCODE -ne 0) {
    throw "Bicep validation failed."
}

Write-Host "`nBootstrap completed successfully." -ForegroundColor Green
