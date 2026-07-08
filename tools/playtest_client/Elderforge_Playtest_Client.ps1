param(
	[string]$InstallDir,
	[string]$VersionUrl,
	[string]$PackageUrl,
	[switch]$NoLaunch
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$installDirWasProvided = -not [string]::IsNullOrWhiteSpace($InstallDir)
if (-not $installDirWasProvided) {
	$InstallDir = Join-Path $PSScriptRoot "Game"
}

$ConfigPath = Join-Path $PSScriptRoot "client_config.json"
if (Test-Path -LiteralPath $ConfigPath) {
	$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
	if ([string]::IsNullOrWhiteSpace($VersionUrl) -and $config.version_url) {
		$VersionUrl = [string]$config.version_url
	}
	if ([string]::IsNullOrWhiteSpace($PackageUrl) -and $config.package_url) {
		$PackageUrl = [string]$config.package_url
	}
	if (
		-not $installDirWasProvided -and
		$config.install_subdirectory
	) {
		$InstallDir = Join-Path $PSScriptRoot ([string]$config.install_subdirectory)
	}
}

if ([string]::IsNullOrWhiteSpace($VersionUrl)) {
	$VersionUrl = "https://github.com/Barbatos6669/elderforge/releases/download/playtest-2026-07-08/Elderforge_Windows_Playtest.version.json"
}
if ([string]::IsNullOrWhiteSpace($PackageUrl)) {
	$PackageUrl = "https://github.com/Barbatos6669/elderforge/releases/download/playtest-2026-07-08/Elderforge_Windows_Playtest.zip"
}

$InstallDir = [System.IO.Path]::GetFullPath($InstallDir)
$LocalVersionPath = Join-Path $InstallDir "playtest_version.json"
$GameExePath = Join-Path $InstallDir "Elderforge_Playtest.exe"
$UpdateRoot = Join-Path $env:TEMP "ElderforgePlaytestClient"
$PackagePath = Join-Path $UpdateRoot "Elderforge_Windows_Playtest.zip"
$ExtractDir = Join-Path $UpdateRoot "extract"

function Read-JsonFile {
	param([string]$Path)

	if (-not (Test-Path -LiteralPath $Path)) {
		return $null
	}

	try {
		return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
	}
	catch {
		return $null
	}
}

function Get-RemoteVersion {
	$cacheBust = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
	$separator = "?"
	if ($VersionUrl.Contains("?")) {
		$separator = "&"
	}

	return Invoke-RestMethod `
		-Uri "$VersionUrl${separator}t=$cacheBust" `
		-Headers @{ "User-Agent" = "ElderforgePlaytestClient"; "Cache-Control" = "no-cache" }
}

function Save-RemoteFile {
	param(
		[string]$Uri,
		[string]$Path
	)

	Invoke-WebRequest `
		-Uri $Uri `
		-OutFile $Path `
		-Headers @{ "User-Agent" = "ElderforgePlaytestClient"; "Cache-Control" = "no-cache" }
}

function Test-NeedsUpdate {
	param(
		$LocalVersion,
		$RemoteVersion
	)

	if (-not (Test-Path -LiteralPath $GameExePath)) {
		return $true
	}
	if ($null -eq $LocalVersion) {
		return $true
	}
	if ($null -eq $RemoteVersion) {
		return $false
	}

	return [string]$LocalVersion.build_id -ne [string]$RemoteVersion.build_id
}

function Install-GamePackage {
	param($RemoteVersion)

	if (Test-Path -LiteralPath $UpdateRoot) {
		Remove-Item -LiteralPath $UpdateRoot -Recurse -Force
	}
	New-Item -ItemType Directory -Path $UpdateRoot -Force | Out-Null
	New-Item -ItemType Directory -Path $ExtractDir -Force | Out-Null
	New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

	Write-Host "Downloading Elderforge playtest update..."
	Save-RemoteFile -Uri $PackageUrl -Path $PackagePath

	Write-Host "Installing update..."
	Expand-Archive -LiteralPath $PackagePath -DestinationPath $ExtractDir -Force
	Copy-Item -Path (Join-Path $ExtractDir "*") -Destination $InstallDir -Recurse -Force

	if ($null -ne $RemoteVersion) {
		$RemoteVersion | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $LocalVersionPath -Encoding UTF8
	}

	Remove-Item -LiteralPath $UpdateRoot -Recurse -Force
}

Write-Host "Checking Elderforge playtest updates..."
$localVersion = Read-JsonFile -Path $LocalVersionPath
$remoteVersion = $null

try {
	$remoteVersion = Get-RemoteVersion
}
catch {
	if (-not (Test-Path -LiteralPath $GameExePath)) {
		throw "Could not check for updates and no local game install exists. $($_.Exception.Message)"
	}

	Write-Warning "Could not check for updates. Launching installed build."
}

if (Test-NeedsUpdate -LocalVersion $localVersion -RemoteVersion $remoteVersion) {
	Install-GamePackage -RemoteVersion $remoteVersion
}
else {
	Write-Host "Elderforge playtest is up to date."
}

if (-not $NoLaunch) {
	if (-not (Test-Path -LiteralPath $GameExePath)) {
		throw "Game executable was not found after update: $GameExePath"
	}

	Write-Host "Starting Elderforge..."
	Start-Process -FilePath $GameExePath -WorkingDirectory $InstallDir
}
