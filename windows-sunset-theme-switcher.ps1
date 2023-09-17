param (
    [Parameter(Position=0)]
    [double]
    $Latitude = 0,

    [Parameter(Position=1)]
    [double]
    $Longitude = 0

    # TODO: Scheduled Task installation
    # Current hold-up: Cannot do -AtLogon 'Every 5 minutes indefinitely', need to find a way around it.
)

if ($Latitude -eq 0 -and $Longitude -eq 0) { Write-Warning 'It appears you didn''t supply a latitude or longitude. Defaulting to 0, 0.' }

$CURRENT_DATE = Get-Date
$URL_API = "https://api.sunrise-sunset.org/json?lat=$Latitude&lng=$Longitude&formatted=0"
$REG_PATH_PERSONALIZATION = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
$REG_PATH_SCRIPT = 'HKCU:\Script\BinaryInk\AutoThemeMode'

# Check if there is a previous run and grab data if there was.
if (!$(Test-Path $REG_PATH_SCRIPT)) { 
    if (!$(Test-Path 'HKCU:\Script')) {
        New-Item -Path 'HKCU:\Script'
    }
    if (!$(Test-Path 'HKCU:\Script\BinaryInk')) {
        New-Item -Path 'HKCU:\Script\BinaryInk'
    }
    if (!$(Test-Path 'HKCU:\Script\BinaryInk\AutoThemeMode')) {
        New-Item -Path 'HKCU:\Script\BinaryInk\AutoThemeMode'
    }
}
else { 
    $LastRun = Get-Date $(Get-ItemPropertyValue -Path $REG_PATH_SCRIPT -Name 'LastRun') 
    $Sunrise = Get-Date $(Get-ItemPropertyValue -Path $REG_PATH_SCRIPT -Name 'Sunrise') 
    $Sunset = Get-Date $(Get-ItemPropertyValue -Path $REG_PATH_SCRIPT -Name 'Sunset') 
}

# Determine whether data needs to be added to registry (or refreshed)
$UpdateData = $false
if ($null -eq $LastRun) {
    $UpdateData = $true
}
elseif ($LastRun.ToString("yyyyMMdd") -ne $CURRENT_DATE.ToString("yyyyMMdd")) {
    $UpdateData = $true
}

if ($UpdateData) {
    Write-Debug 'Retrieving New Data'
    # Get new Sunrise/Sunset
    $Response = Invoke-WebRequest -Uri $URL_API
    $ResponseContent = $Response.Content | ConvertFrom-Json
    if ($ResponseContent.status -eq "OK") {
        $Sunrise = Get-Date $ResponseContent.results.sunrise
        $Sunset = Get-Date $ResponseContent.results.sunset
    }
    else {
        throw "Error: Bad Response: $($ResponseContent.status)"
    }

    # Set new data in Registry
    New-ItemProperty -Path $REG_PATH_SCRIPT -Name 'LastRun' -Value $($CURRENT_DATE.ToString()) -PropertyType 'String' -Force
    New-ItemProperty -Path $REG_PATH_SCRIPT -Name 'Sunrise' -Value $($Sunrise.ToString()) -PropertyType 'String' -Force
    New-ItemProperty -Path $REG_PATH_SCRIPT -Name 'Sunset' -Value $($Sunset.ToString()) -PropertyType 'String' -Force
}

# Change the theme if needed.
$TargetValue = $CURRENT_DATE -gt $Sunrise -and $CURRENT_DATE -lt $Sunset ? 1 : 0
$CurrentValue = Get-ItemPropertyValue -Path $REG_PATH_PERSONALIZATION -Name 'SystemUsesLightTheme'
if (!$(Test-Path $REG_PATH_PERSONALIZATION)) { New-Item -Path $REG_PATH_PERSONALIZATION -Force | Out-Null }
if ($TargetValue -ne $CurrentValue) {
    'SystemUsesLightTheme','AppsUseLightTheme' | ForEach-Object {
        New-ItemProperty -Path $REG_PATH_PERSONALIZATION -Name $_ -Value $TargetValue -PropertyType 'DWORD' -Force
    }
    # This is a workaround to enforce the change on the taskbar.
    # Requires "Launch Folder Windows in Separate Process" to be enabled in file explorer to avoid closing open windows.
    Start-Sleep -Seconds 5
    Get-Process explorer | 
            Where-Object { $_.Parent.ProcessName -eq 'winlogon' -or $null -eq $_.Parent } | 
            Stop-Process -Force
}

# TODO: Offline sunset calculation.
