param(
	[string]$GodotExe = $env:GODOT_EXE,
	[string]$ServerAddress = $env:ELDERFORGE_PLAYTEST_SERVER,
	[int]$ServerPort = 24566
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
$ZipPath = Join-Path $PackageDir "Elderforge_Windows_Playtest.zip"
$LauncherPath = Join-Path $BuildDir "Start_Elderforge_Playtest.bat"
$ReadmePath = Join-Path $BuildDir "PLAYTEST_README.txt"

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

New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null
New-Item -ItemType Directory -Path $PackageDir -Force | Out-Null

if ([string]::IsNullOrWhiteSpace($ServerAddress)) {
	$ServerAddress = Get-DefaultPlaytestServerAddress
}
$ServerPort = [Math]::Min([Math]::Max($ServerPort, 1024), 65535)

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

$readmeContents = @"
Elderforge Windows Playtest

Run Start_Elderforge_Playtest.bat, then sign in or use Guest.
The launcher connects to $ServerAddress`:$ServerPort.

If you are testing on the same computer as the server, Elderforge_Playtest.exe also works directly.
If the server address changes, edit Start_Elderforge_Playtest.bat and replace the value after --connect=.
"@
Set-Content -LiteralPath $ReadmePath -Value $readmeContents -Encoding ASCII

if (Test-Path -LiteralPath $ZipPath) {
	Remove-Item -LiteralPath $ZipPath -Force
}

Write-Host "Packaging playtest zip..."
Compress-Archive -Path (Join-Path $BuildDir "*") -DestinationPath $ZipPath -Force

Write-Host "Created $ZipPath"
