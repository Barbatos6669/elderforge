param(
	[string]$InstallDir = (Join-Path $PSScriptRoot "Install"),
	[string]$VersionUrl,
	[string]$PackageUrl,
	[string]$StatusUrl,
	[switch]$NoLaunch
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$DefaultVersionUrl = "https://github.com/Barbatos6669/elderforge/releases/download/playtest-2026-07-08/Elderforge_Windows_Playtest.version.json"
$DefaultPackageUrl = "https://github.com/Barbatos6669/elderforge/releases/download/playtest-2026-07-08/Elderforge_Windows_Playtest.zip"
$DefaultStatusUrl = "http://20.253.172.141:24567/status"
$DefaultGameExe = "Elderforge_Playtest.exe"

$script:Window = $null
$script:IsBusy = $false
$script:Config = $null
$script:RemoteManifest = $null
$script:InstallRoot = $null

function Get-FullPath {
	param([string]$Path)

	return [System.IO.Path]::GetFullPath($Path)
}

function New-Directory {
	param([string]$Path)

	if (-not (Test-Path -LiteralPath $Path)) {
		New-Item -ItemType Directory -Path $Path -Force | Out-Null
	}
}

function Remove-DirectorySafely {
	param(
		[string]$Path,
		[string]$BasePath
	)

	if (-not (Test-Path -LiteralPath $Path)) {
		return
	}

	$target = Get-FullPath -Path $Path
	$base = (Get-FullPath -Path $BasePath).TrimEnd('\', '/')
	$baseWithSlash = $base + [System.IO.Path]::DirectorySeparatorChar

	if ($target -eq $base -or -not $target.StartsWith($baseWithSlash, [System.StringComparison]::OrdinalIgnoreCase)) {
		throw "Refusing to delete path outside launcher install root: $target"
	}

	Remove-Item -LiteralPath $target -Recurse -Force
}

function Get-ObjectValue {
	param(
		[object]$Object,
		[string]$Name,
		[object]$DefaultValue = $null
	)

	if ($null -eq $Object) {
		return $DefaultValue
	}

	if ($Object.PSObject.Properties.Name -contains $Name) {
		$value = $Object.$Name
		if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value)) {
			return $value
		}
	}

	return $DefaultValue
}

function Read-JsonFile {
	param([string]$Path)

	if (-not (Test-Path -LiteralPath $Path)) {
		return $null
	}

	$content = Get-Content -Raw -LiteralPath $Path
	if ([string]::IsNullOrWhiteSpace($content)) {
		return $null
	}

	return $content | ConvertFrom-Json
}

function Get-LauncherConfig {
	$configPath = Join-Path $PSScriptRoot "client_config.json"
	$config = Read-JsonFile -Path $configPath

	$result = [ordered]@{
		version_url = $DefaultVersionUrl
		package_url = $DefaultPackageUrl
		status_url = $DefaultStatusUrl
		install_subdirectory = "Game"
		server_address = "20.253.172.141"
		server_port = 24566
	}

	if ($null -ne $config) {
		foreach ($key in @("version_url", "package_url", "status_url", "install_subdirectory", "server_address", "server_port")) {
			$value = Get-ObjectValue -Object $config -Name $key
			if ($null -ne $value) {
				$result[$key] = $value
			}
		}
	}

	if (-not [string]::IsNullOrWhiteSpace($VersionUrl)) {
		$result.version_url = $VersionUrl
	}
	if (-not [string]::IsNullOrWhiteSpace($PackageUrl)) {
		$result.package_url = $PackageUrl
	}
	if (-not [string]::IsNullOrWhiteSpace($StatusUrl)) {
		$result.status_url = $StatusUrl
	}

	return [pscustomobject]$result
}

function Refresh-Ui {
	if ($null -eq $script:Window) {
		return
	}

	$script:Window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
}

function Set-Text {
	param(
		[object]$Control,
		[string]$Text
	)

	if ($null -ne $Control) {
		$Control.Text = $Text
	}
}

function Set-ButtonEnabled {
	param(
		[object]$Control,
		[bool]$Enabled
	)

	if ($null -ne $Control) {
		$Control.IsEnabled = $Enabled
	}
}

function New-Brush {
	param([string]$Color)

	$converter = New-Object System.Windows.Media.BrushConverter
	return $converter.ConvertFromString($Color)
}

function Append-Log {
	param([string]$Message)

	$line = "[$((Get-Date).ToString("HH:mm:ss"))] $Message"
	if ($null -ne $script:LogBox) {
		$script:LogBox.AppendText($line + [Environment]::NewLine)
		$script:LogBox.ScrollToEnd()
		Refresh-Ui
	}
	else {
		Write-Host $line
	}
}

function Set-LauncherStatus {
	param([string]$Message)

	Set-Text -Control $script:UpdateStatusText -Text $Message
	if ($null -ne $script:ProgressText) {
		$script:ProgressText.Text = $Message
	}
	Append-Log -Message $Message
	Refresh-Ui
}

function Set-Dot {
	param(
		[object]$Dot,
		[string]$Color
	)

	if ($null -ne $Dot) {
		$Dot.Fill = New-Brush -Color $Color
	}
}

function Set-Busy {
	param([bool]$Busy)

	$script:IsBusy = $Busy
	Set-ButtonEnabled -Control $script:PlayButton -Enabled (-not $Busy)
	Set-ButtonEnabled -Control $script:UpdateButton -Enabled (-not $Busy)
	Set-ButtonEnabled -Control $script:RefreshButton -Enabled (-not $Busy)
	Refresh-Ui
}

function Get-GameDirectory {
	$subdir = [string](Get-ObjectValue -Object $script:Config -Name "install_subdirectory" -DefaultValue "Game")
	return Join-Path $script:InstallRoot $subdir
}

function Get-GameExePath {
	return Join-Path (Get-GameDirectory) $DefaultGameExe
}

function Get-InstalledManifest {
	return Read-JsonFile -Path (Join-Path (Get-GameDirectory) "playtest_version.json")
}

function Get-RemoteManifest {
	$url = [string](Get-ObjectValue -Object $script:Config -Name "version_url" -DefaultValue $DefaultVersionUrl)
	if ([string]::IsNullOrWhiteSpace($url)) {
		return $null
	}

	try {
		return Invoke-RestMethod -Uri $url -TimeoutSec 10
	}
	catch {
		Append-Log -Message "Could not reach version manifest: $($_.Exception.Message)"
		return $null
	}
}

function Get-StatusUrl {
	$manifestStatus = Get-ObjectValue -Object $script:RemoteManifest -Name "server_status_url"
	if ($null -ne $manifestStatus) {
		return [string]$manifestStatus
	}

	$configStatus = Get-ObjectValue -Object $script:Config -Name "status_url"
	if ($null -ne $configStatus) {
		return [string]$configStatus
	}

	return $DefaultStatusUrl
}

function Get-BuildLabel {
	param([object]$Manifest)

	$buildId = [string](Get-ObjectValue -Object $Manifest -Name "build_id" -DefaultValue "not installed")
	if ($buildId.Length -gt 22) {
		return $buildId.Substring(0, 22)
	}

	return $buildId
}

function Update-BuildText {
	$installed = Get-InstalledManifest
	$label = Get-BuildLabel -Manifest $installed
	Set-Text -Control $script:BuildText -Text "Build: $label"
}

function Install-PlaytestBuild {
	param([object]$RemoteManifest)

	$packageUrl = [string](Get-ObjectValue -Object $RemoteManifest -Name "package_url")
	if ([string]::IsNullOrWhiteSpace($packageUrl)) {
		$packageUrl = [string](Get-ObjectValue -Object $script:Config -Name "package_url" -DefaultValue $DefaultPackageUrl)
	}
	if ([string]::IsNullOrWhiteSpace($packageUrl)) {
		throw "No package URL is configured for this launcher."
	}

	$cacheDir = Join-Path $script:InstallRoot "DownloadCache"
	$stageDir = Join-Path $script:InstallRoot "Stage"
	$gameDir = Get-GameDirectory
	$zipPath = Join-Path $cacheDir "Elderforge_Windows_Playtest.zip"

	New-Directory -Path $cacheDir
	Remove-DirectorySafely -Path $stageDir -BasePath $script:InstallRoot
	New-Directory -Path $stageDir

	Set-LauncherStatus -Message "Downloading latest playtest build..."
	Invoke-WebRequest -Uri $packageUrl -OutFile $zipPath -TimeoutSec 120

	Set-LauncherStatus -Message "Installing playtest build..."
	Expand-Archive -LiteralPath $zipPath -DestinationPath $stageDir -Force

	Remove-DirectorySafely -Path $gameDir -BasePath $script:InstallRoot
	Move-Item -LiteralPath $stageDir -Destination $gameDir -Force

	Set-LauncherStatus -Message "Playtest build installed."
}

function Invoke-LauncherUpdate {
	Set-Busy -Busy $true
	try {
		Set-LauncherStatus -Message "Checking for updates..."
		$script:RemoteManifest = Get-RemoteManifest
		$installed = Get-InstalledManifest
		$exePath = Get-GameExePath

		if ($null -eq $script:RemoteManifest) {
			if (Test-Path -LiteralPath $exePath) {
				Set-Dot -Dot $script:UpdateDot -Color "#d9a441"
				Set-LauncherStatus -Message "Could not check updates. Local build is available."
				Update-BuildText
				return
			}

			throw "No installed game was found, and the launcher could not reach the update manifest."
		}

		$remoteBuild = [string](Get-ObjectValue -Object $script:RemoteManifest -Name "build_id" -DefaultValue "")
		$installedBuild = [string](Get-ObjectValue -Object $installed -Name "build_id" -DefaultValue "")
		$needsInstall = (-not (Test-Path -LiteralPath $exePath)) -or [string]::IsNullOrWhiteSpace($installedBuild) -or ($remoteBuild -ne $installedBuild)

		if ($needsInstall) {
			Install-PlaytestBuild -RemoteManifest $script:RemoteManifest
		}
		else {
			Set-LauncherStatus -Message "Game is up to date."
		}

		Set-Dot -Dot $script:UpdateDot -Color "#2fd66f"
		Update-BuildText
	}
	catch {
		Set-Dot -Dot $script:UpdateDot -Color "#e34848"
		Set-LauncherStatus -Message "Update failed: $($_.Exception.Message)"
		throw
	}
	finally {
		Set-Busy -Busy $false
	}
}

function Update-ServerStatus {
	$statusUrl = Get-StatusUrl
	if ([string]::IsNullOrWhiteSpace($statusUrl)) {
		Set-Dot -Dot $script:ServerDot -Color "#d9a441"
		Set-Text -Control $script:ServerStatusText -Text "Server status: unknown"
		return
	}

	try {
		Set-Text -Control $script:ServerStatusText -Text "Server status: checking..."
		Refresh-Ui
		$status = Invoke-RestMethod -Uri $statusUrl -TimeoutSec 5
		$isOnline = [bool](Get-ObjectValue -Object $status -Name "online" -DefaultValue $false)
		$message = [string](Get-ObjectValue -Object $status -Name "message" -DefaultValue "")
		$name = [string](Get-ObjectValue -Object $status -Name "server_name" -DefaultValue "Elderforge Playtest")

		if ($isOnline) {
			Set-Dot -Dot $script:ServerDot -Color "#2fd66f"
			if ([string]::IsNullOrWhiteSpace($message)) {
				$message = "Server is online."
			}
		}
		else {
			Set-Dot -Dot $script:ServerDot -Color "#e34848"
			if ([string]::IsNullOrWhiteSpace($message)) {
				$message = "Server is offline."
			}
		}

		Set-Text -Control $script:ServerStatusText -Text "$name`: $message"
		Append-Log -Message "Server status refreshed: $message"
	}
	catch {
		Set-Dot -Dot $script:ServerDot -Color "#e34848"
		Set-Text -Control $script:ServerStatusText -Text "Server status: unavailable"
		Append-Log -Message "Server status check failed: $($_.Exception.Message)"
	}
}

function Start-Game {
	$exePath = Get-GameExePath
	if (-not (Test-Path -LiteralPath $exePath)) {
		Invoke-LauncherUpdate
	}

	if (-not (Test-Path -LiteralPath $exePath)) {
		throw "Game executable is missing after update."
	}

	Set-LauncherStatus -Message "Starting Elderforge..."
	Start-Process -FilePath $exePath -WorkingDirectory (Get-GameDirectory)
}

function Initialize-LauncherState {
	$script:Config = Get-LauncherConfig
	$script:InstallRoot = Get-FullPath -Path $InstallDir
	New-Directory -Path $script:InstallRoot
}

function Invoke-ConsoleMode {
	Initialize-LauncherState
	Invoke-LauncherUpdate
	Update-ServerStatus
}

function Show-LauncherWindow {
	Add-Type -AssemblyName PresentationFramework
	Add-Type -AssemblyName PresentationCore
	Add-Type -AssemblyName WindowsBase

	[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Elderforge Playtest Launcher"
        Width="980"
        Height="620"
        ResizeMode="CanMinimize"
        WindowStartupLocation="CenterScreen"
        Background="#0b1116">
	<Grid>
		<Grid.ColumnDefinitions>
			<ColumnDefinition Width="72" />
			<ColumnDefinition Width="*" />
		</Grid.ColumnDefinitions>
		<Border Grid.Column="0" Background="#0c1218" BorderBrush="#26323d" BorderThickness="0,0,1,0">
			<StackPanel Margin="0,18,0,0">
				<TextBlock Text="EF" FontWeight="Bold" FontSize="22" Foreground="#f0c866" HorizontalAlignment="Center" Margin="0,0,0,30" />
				<TextBlock Text="News" Foreground="#aeb8c2" HorizontalAlignment="Center" Margin="0,0,0,18" />
				<TextBlock Text="Server" Foreground="#aeb8c2" HorizontalAlignment="Center" Margin="0,0,0,18" />
				<TextBlock Text="Files" Foreground="#aeb8c2" HorizontalAlignment="Center" />
			</StackPanel>
		</Border>
		<Grid Grid.Column="1">
			<Grid.RowDefinitions>
				<RowDefinition Height="220" />
				<RowDefinition Height="*" />
				<RowDefinition Height="92" />
			</Grid.RowDefinitions>
			<Border Grid.Row="0">
				<Border.Background>
					<LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
						<GradientStop Color="#162437" Offset="0" />
						<GradientStop Color="#613019" Offset="0.65" />
						<GradientStop Color="#d29b3d" Offset="1" />
					</LinearGradientBrush>
				</Border.Background>
				<Grid Margin="28,22,28,22">
					<StackPanel VerticalAlignment="Center">
						<TextBlock Text="ELDERFORGE" FontSize="56" FontWeight="Black" Foreground="#f6f0dc" />
						<TextBlock Text="PUBLIC PLAYTEST LAUNCHER" FontSize="18" FontWeight="SemiBold" Foreground="#f0c866" Margin="4,-6,0,0" />
						<TextBlock Text="Auto-update, server status, and quick launch for the current test build." FontSize="14" Foreground="#f7dfae" Margin="5,14,0,0" />
					</StackPanel>
				</Grid>
			</Border>
			<Grid Grid.Row="1" Margin="20">
				<Grid.ColumnDefinitions>
					<ColumnDefinition Width="*" />
					<ColumnDefinition Width="*" />
					<ColumnDefinition Width="*" />
				</Grid.ColumnDefinitions>
				<Border Grid.Column="0" Background="#111a23" BorderBrush="#2a3947" BorderThickness="1" Margin="0,0,10,0">
					<StackPanel Margin="18">
						<TextBlock Text="PLAYTEST REALM" Foreground="#f6f0dc" FontSize="22" FontWeight="Bold" TextWrapping="Wrap" />
						<TextBlock Text="Azure-hosted multiplayer test server for friends and early contributors." Foreground="#aeb8c2" FontSize="13" TextWrapping="Wrap" Margin="0,12,0,0" />
					</StackPanel>
				</Border>
				<Border Grid.Column="1" Background="#111a23" BorderBrush="#2a3947" BorderThickness="1" Margin="0,0,10,0">
					<StackPanel Margin="18">
						<TextBlock Text="GATHER. CRAFT. FIGHT." Foreground="#f6f0dc" FontSize="22" FontWeight="Bold" TextWrapping="Wrap" />
						<TextBlock Text="Small survival loop, resource nodes, tool crafting, combat, and respawns." Foreground="#aeb8c2" FontSize="13" TextWrapping="Wrap" Margin="0,12,0,0" />
					</StackPanel>
				</Border>
				<Border Grid.Column="2" Background="#111a23" BorderBrush="#2a3947" BorderThickness="1">
					<StackPanel Margin="18">
						<TextBlock Text="UPDATER READY" Foreground="#f6f0dc" FontSize="22" FontWeight="Bold" TextWrapping="Wrap" />
						<TextBlock Text="Download the small launcher once. It keeps the installed game current." Foreground="#aeb8c2" FontSize="13" TextWrapping="Wrap" Margin="0,12,0,0" />
					</StackPanel>
				</Border>
			</Grid>
			<Border Grid.Row="2" Background="#0d1319" BorderBrush="#26323d" BorderThickness="0,1,0,0">
				<Grid Margin="20,12,20,12">
					<Grid.ColumnDefinitions>
						<ColumnDefinition Width="170" />
						<ColumnDefinition Width="*" />
						<ColumnDefinition Width="260" />
					</Grid.ColumnDefinitions>
					<Button x:Name="PlayButton" Grid.Column="0" Content="PLAY" Background="#b81717" Foreground="White" FontSize="22" FontWeight="Bold" BorderThickness="0" />
					<StackPanel Grid.Column="1" Margin="18,0,0,0">
						<StackPanel Orientation="Horizontal" Margin="0,2,0,0">
							<Ellipse x:Name="ServerDot" Width="10" Height="10" Fill="#d9a441" Margin="0,5,8,0" />
							<TextBlock x:Name="ServerStatusText" Text="Server status: checking..." Foreground="#d9e2ea" FontSize="13" />
						</StackPanel>
						<StackPanel Orientation="Horizontal" Margin="0,5,0,0">
							<Ellipse x:Name="UpdateDot" Width="10" Height="10" Fill="#d9a441" Margin="0,5,8,0" />
							<TextBlock x:Name="UpdateStatusText" Text="Update status: waiting..." Foreground="#d9e2ea" FontSize="13" />
						</StackPanel>
						<TextBlock x:Name="BuildText" Text="Build: checking..." Foreground="#84919c" FontSize="12" Margin="18,5,0,0" />
					</StackPanel>
					<StackPanel Grid.Column="2">
						<StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
							<Button x:Name="UpdateButton" Content="Check Updates" Width="112" Height="28" Margin="0,0,8,0" />
							<Button x:Name="RefreshButton" Content="Refresh Server" Width="112" Height="28" />
						</StackPanel>
						<Button x:Name="OpenFolderButton" Content="Open Game Folder" Width="232" Height="28" Margin="0,8,0,0" HorizontalAlignment="Right" />
					</StackPanel>
				</Grid>
			</Border>
			<Border Grid.Row="1" HorizontalAlignment="Right" VerticalAlignment="Bottom" Width="340" Height="86" Margin="0,0,20,18" Background="#101820" BorderBrush="#2a3947" BorderThickness="1">
				<Grid Margin="12">
					<Grid.RowDefinitions>
						<RowDefinition Height="20" />
						<RowDefinition Height="*" />
					</Grid.RowDefinitions>
					<TextBlock x:Name="ProgressText" Text="Launcher ready." Foreground="#f0c866" FontSize="12" />
					<TextBox x:Name="LogBox" Grid.Row="1" Background="#0b1116" Foreground="#aeb8c2" BorderThickness="0" FontFamily="Consolas" FontSize="11" IsReadOnly="True" TextWrapping="NoWrap" />
				</Grid>
			</Border>
		</Grid>
	</Grid>
</Window>
"@

	$reader = New-Object System.Xml.XmlNodeReader $xaml
	$script:Window = [Windows.Markup.XamlReader]::Load($reader)
	$script:PlayButton = $script:Window.FindName("PlayButton")
	$script:UpdateButton = $script:Window.FindName("UpdateButton")
	$script:RefreshButton = $script:Window.FindName("RefreshButton")
	$script:OpenFolderButton = $script:Window.FindName("OpenFolderButton")
	$script:ServerStatusText = $script:Window.FindName("ServerStatusText")
	$script:UpdateStatusText = $script:Window.FindName("UpdateStatusText")
	$script:BuildText = $script:Window.FindName("BuildText")
	$script:ProgressText = $script:Window.FindName("ProgressText")
	$script:LogBox = $script:Window.FindName("LogBox")
	$script:ServerDot = $script:Window.FindName("ServerDot")
	$script:UpdateDot = $script:Window.FindName("UpdateDot")

	$script:PlayButton.Add_Click({
		try {
			Start-Game
		}
		catch {
			[System.Windows.MessageBox]::Show($_.Exception.Message, "Elderforge Launcher", "OK", "Error") | Out-Null
		}
	})
	$script:UpdateButton.Add_Click({
		try {
			Invoke-LauncherUpdate
		}
		catch {
			[System.Windows.MessageBox]::Show($_.Exception.Message, "Elderforge Launcher", "OK", "Error") | Out-Null
		}
	})
	$script:RefreshButton.Add_Click({ Update-ServerStatus })
	$script:OpenFolderButton.Add_Click({
		New-Directory -Path (Get-GameDirectory)
		Start-Process explorer.exe (Get-GameDirectory)
	})
	$script:Window.Add_Loaded({
		try {
			Initialize-LauncherState
			Update-BuildText
			Invoke-LauncherUpdate
			Update-ServerStatus
		}
		catch {
			[System.Windows.MessageBox]::Show($_.Exception.Message, "Elderforge Launcher", "OK", "Error") | Out-Null
		}
	})

	$script:Window.ShowDialog() | Out-Null
}

try {
	if ($NoLaunch) {
		Invoke-ConsoleMode
		exit 0
	}

	Show-LauncherWindow
}
catch {
	if ($null -ne $script:Window) {
		[System.Windows.MessageBox]::Show($_.Exception.Message, "Elderforge Launcher", "OK", "Error") | Out-Null
	}
	else {
		Write-Error $_.Exception.Message
	}
	exit 1
}
