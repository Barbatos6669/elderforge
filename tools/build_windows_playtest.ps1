param(
	[string]$GodotExe = $env:GODOT_EXE,
	[string]$ServerAddress = $env:ELDERFORGE_PLAYTEST_SERVER,
	[int]$ServerPort = 24566,
	[switch]$RequirePlaytestCode,
	[string]$PlaytestCode = $env:ELDERFORGE_PLAYTEST_CODE,
	[string]$PlaytestCodeHash = $env:ELDERFORGE_PLAYTEST_CODE_HASH,
	[string]$StatusUrl = $env:ELDERFORGE_PLAYTEST_STATUS_URL,
	[string]$Repository = "Barbatos6669/elderforge",
	[string]$ReleaseTag = "playtest-2026-07-08"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if ([string]::IsNullOrWhiteSpace($GodotExe)) {
	$GodotExe = "C:\Godot\Godot_v4.7-stable_win64_console.exe"
}

if (-not (Test-Path -LiteralPath $GodotExe)) {
	throw "Godot console executable not found. Set GODOT_EXE or pass -GodotExe."
}

$BuildDir = Join-Path $ProjectRoot "builds\windows-playtest"
$PackageDir = Join-Path $ProjectRoot "builds\packages"
$ExePath = Join-Path $BuildDir "Elderforge_Playtest.exe"
$PlaytestZipName = "Elderforge_Windows_Playtest.zip"
$VersionAssetName = "Elderforge_Windows_Playtest.version.json"
$ClientZipName = "Elderforge_Playtest_Client.zip"
$ZipPath = Join-Path $PackageDir $PlaytestZipName
$VersionPath = Join-Path $BuildDir "playtest_version.json"
$VersionAssetPath = Join-Path $PackageDir $VersionAssetName
$LauncherPath = Join-Path $BuildDir "Start_Elderforge_Playtest.bat"
$ReadmePath = Join-Path $BuildDir "PLAYTEST_README.txt"
$ConfigPath = Join-Path $BuildDir "playtest_server.cfg"
$ClientSourceDir = Join-Path $ProjectRoot "tools\playtest_client"
$ClientBuildDir = Join-Path $ProjectRoot "builds\playtest-client"
$ClientZipPath = Join-Path $PackageDir $ClientZipName

function Get-DefaultPlaytestServerAddress {
	try {
		$configurations = Get-NetIPConfiguration | Where-Object {
			$null -ne $_.IPv4DefaultGateway -and $null -ne $_.IPv4Address
		}

		foreach ($configuration in $configurations) {
			foreach ($address in $configuration.IPv4Address) {
				if ($address.IPAddress -match '^(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.)') {
					return $address.IPAddress
				}
			}
		}

		foreach ($configuration in $configurations) {
			foreach ($address in $configuration.IPv4Address) {
				if ($address.IPAddress -ne "127.0.0.1" -and $address.IPAddress -notmatch '^169\.254\.') {
					return $address.IPAddress
				}
			}
		}
	}
	catch {
		# Get-NetIPConfiguration is Windows-only. Falling back keeps the build script usable elsewhere.
	}

	return "127.0.0.1"
}

function Get-GitCommit {
	try {
		$commit = (& git -C $ProjectRoot rev-parse --short=12 HEAD 2>$null)
		if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($commit)) {
			return $commit.Trim()
		}
	}
	catch {
	}

	return "unknown"
}

function Get-Sha256Hex {
	param([string]$Value)

	$bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
	$sha256 = [System.Security.Cryptography.SHA256]::Create()
	try {
		$hashBytes = $sha256.ComputeHash($bytes)
		return -join ($hashBytes | ForEach-Object { $_.ToString("x2") })
	}
	finally {
		$sha256.Dispose()
	}
}

function Get-CSharpCompiler {
	$command = Get-Command csc.exe -ErrorAction SilentlyContinue
	if ($null -ne $command -and -not [string]::IsNullOrWhiteSpace($command.Source)) {
		return $command.Source
	}

	$candidates = @(
		"C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
		"C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe"
	)

	foreach ($candidate in $candidates) {
		if (Test-Path -LiteralPath $candidate) {
			return $candidate
		}
	}

	return $null
}

function Write-PlaytestClientPackage {
	if (-not (Test-Path -LiteralPath $ClientSourceDir)) {
		throw "Playtest client source folder missing: $ClientSourceDir"
	}

	if (Test-Path -LiteralPath $ClientBuildDir) {
		Remove-Item -LiteralPath $ClientBuildDir -Recurse -Force
	}
	New-Item -ItemType Directory -Path $ClientBuildDir -Force | Out-Null

	Copy-Item -Path (Join-Path $ClientSourceDir "*") -Destination $ClientBuildDir -Recurse -Force
	foreach ($importFile in Get-ChildItem -LiteralPath $ClientBuildDir -Recurse -Force -File -Filter "*.import") {
		Remove-Item -LiteralPath $importFile.FullName -Force
	}

	$clientConfig = [ordered]@{
		version_url = "$ReleaseBaseUrl/$VersionAssetName"
		package_url = "$ReleaseBaseUrl/$PlaytestZipName"
		status_url = $StatusUrl
		server_address = $ServerAddress
		server_port = $ServerPort
		install_subdirectory = "Game"
	}
	$clientConfig |
		ConvertTo-Json -Depth 4 |
		Set-Content -LiteralPath (Join-Path $ClientBuildDir "client_config.json") -Encoding ASCII

	$launcherSource = Join-Path $ClientBuildDir "Elderforge_Playtest_Launcher.cs"
	$launcherExe = Join-Path $ClientBuildDir "Elderforge_Playtest_Launcher.exe"
	$csharpCompiler = Get-CSharpCompiler
	if ([string]::IsNullOrWhiteSpace($csharpCompiler)) {
		Write-Warning "C# compiler not found. The client zip will include only the batch fallback launcher."
	}
	else {
		Write-Host "Compiling no-console playtest launcher..."
		& $csharpCompiler /nologo /target:winexe /reference:System.Windows.Forms.dll "/out:$launcherExe" "$launcherSource"
		if ($LASTEXITCODE -ne 0) {
			throw "Failed to compile Elderforge_Playtest_Launcher.exe."
		}
	}

	if (Test-Path -LiteralPath $ClientZipPath) {
		Remove-Item -LiteralPath $ClientZipPath -Force
	}

	Write-Host "Packaging auto-updating playtest client..."
	Compress-Archive -Path (Join-Path $ClientBuildDir "*") -DestinationPath $ClientZipPath -Force
}

New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null
New-Item -ItemType Directory -Path $PackageDir -Force | Out-Null

if ([string]::IsNullOrWhiteSpace($ServerAddress)) {
	$ServerAddress = Get-DefaultPlaytestServerAddress
}
$ServerPort = [Math]::Min([Math]::Max($ServerPort, 1024), 65535)
if ([string]::IsNullOrWhiteSpace($StatusUrl)) {
	$StatusUrl = "http://{0}:24567/status" -f $ServerAddress
}
$PlaytestCodeRequired = [bool]$RequirePlaytestCode
if (-not [string]::IsNullOrWhiteSpace($PlaytestCode)) {
	$PlaytestCodeHash = Get-Sha256Hex -Value $PlaytestCode.Trim()
	$PlaytestCodeRequired = $true
}
if (-not [string]::IsNullOrWhiteSpace($PlaytestCodeHash)) {
	$PlaytestCodeHash = $PlaytestCodeHash.Trim().ToLowerInvariant()
	$PlaytestCodeRequired = $true
}
$ReleaseBaseUrl = "https://github.com/$Repository/releases/download/$ReleaseTag"
$BuiltAtUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$GitCommit = Get-GitCommit
$BuildStamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmss")
$BuildId = "$GitCommit-$BuildStamp"

Write-Host "Exporting Windows playtest build..."
& $GodotExe --headless --path $ProjectRoot --export-release "Windows Playtest" $ExePath
if ($LASTEXITCODE -ne 0) {
	throw "Godot export failed. In Godot, open Editor > Manage Export Templates and install templates for this Godot version, then rerun this script."
}

Write-Host "Writing playtest launcher for $ServerAddress`:$ServerPort..."
$launcherContents = @"
@echo off
setlocal
pushd "%~dp0"
start "" "%~dp0Elderforge_Playtest.exe" --connect=$ServerAddress`:$ServerPort
popd
"@
Set-Content -LiteralPath $LauncherPath -Value $launcherContents -Encoding ASCII

Write-Host "Writing embedded playtest server config..."
$configContents = @"
[server]
address="$ServerAddress"
port=$ServerPort

[playtest]
require_code=$($PlaytestCodeRequired.ToString().ToLowerInvariant())
access_code_hash=""
"@
Set-Content -LiteralPath $ConfigPath -Value $configContents -Encoding ASCII

Write-Host "Writing playtest version manifest..."
$versionData = [ordered]@{
	schema_version = 1
	game = "Elderforge"
	channel = "playtest"
	build_id = $BuildId
	commit = $GitCommit
	built_at_utc = $BuiltAtUtc
	server_address = $ServerAddress
	server_port = $ServerPort
	server_status_url = $StatusUrl
	package_url = "$ReleaseBaseUrl/$PlaytestZipName"
	playtest_code_required = $PlaytestCodeRequired
	repository = $Repository
	release_tag = $ReleaseTag
	package_asset = $PlaytestZipName
	version_asset = $VersionAssetName
}
$versionJson = $versionData | ConvertTo-Json -Depth 8
Set-Content -LiteralPath $VersionPath -Value $versionJson -Encoding ASCII
Set-Content -LiteralPath $VersionAssetPath -Value $versionJson -Encoding ASCII

$readmeContents = @"
Elderforge Windows Playtest

Run Elderforge_Playtest.exe, then sign in or use Guest.
The game automatically connects to $ServerAddress`:$ServerPort using playtest_server.cfg.
If this playtest requires a code, enter the shared playtest code on the sign-in screen.

For testers who should stay updated automatically, give them Elderforge_Playtest_Client.zip
instead of this full package. They can extract it once and run Elderforge_Playtest_Launcher.exe.
The launcher updates the game and shows the playtest server status before Play.

Elderforge_Playtest_Client.bat is included only as a fallback if Windows blocks
the launcher exe.

Start_Elderforge_Playtest.bat is still included as a developer fallback.
If the server address changes, update playtest_server.cfg or rebuild this package with -ServerAddress and -ServerPort.
If the playtest code changes, restart the server with the new code and privately share it with testers.
"@
Set-Content -LiteralPath $ReadmePath -Value $readmeContents -Encoding ASCII

if (Test-Path -LiteralPath $ZipPath) {
	Remove-Item -LiteralPath $ZipPath -Force
}

Write-Host "Packaging playtest zip..."
Compress-Archive -Path (Join-Path $BuildDir "*") -DestinationPath $ZipPath -Force

Write-PlaytestClientPackage

Write-Host "Created $ZipPath"
Write-Host "Created $VersionAssetPath"
Write-Host "Created $ClientZipPath"
