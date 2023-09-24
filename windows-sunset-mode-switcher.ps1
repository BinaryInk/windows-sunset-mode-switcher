# Ver 2.1

param (
    [Parameter(Position=0)]
    [double]
    $Latitude = 0,

    [Parameter(Position=1)]
    [double]
    $Longitude = 0
)

$TASK_PATH = "\windows-sunset-mode-switcher\"
$TASK_NAME = "windows-sunset-mode-switcher"
$CURRENT_DATE = Get-Date

function Get-SunsetSunriseData() { # [datetime], [datetime]
    if ($Latitude -eq 0 -and $Longitude -eq 0) { Write-Warning 'It appears you didn''t supply a latitude or longitude. Defaulting to 0, 0.' }
    $URL_API = "https://api.sunrise-sunset.org/json?lat=$Latitude&lng=$Longitude&formatted=0"

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

    return @($Sunrise, $Sunset)
}

function Set-WindowsModeLight([Parameter(Position=0)][bool]$On) {
    $REG_PATH_PERSONALIZATION = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    
    $CurrentValue = Get-ItemPropertyValue -Path $REG_PATH_PERSONALIZATION -Name 'SystemUsesLightTheme'

    if (!$(Test-Path $REG_PATH_PERSONALIZATION)) { New-Item -Path $REG_PATH_PERSONALIZATION -Force | Out-Null }
    if ([int]$On -ne $CurrentValue) {
        'SystemUsesLightTheme','AppsUseLightTheme' | ForEach-Object {
            New-ItemProperty -Path $REG_PATH_PERSONALIZATION -Name $_ -Value $([int]$On) -PropertyType 'DWORD' -Force
        }
        # This is a workaround to enforce the change on the taskbar.
        # Requires "Launch Folder Windows in Separate Process" to be enabled in file explorer to avoid closing open windows.
        # TODO: Find function to enforce graceful change in mode, if possible.
        Start-Sleep -Seconds 2
        Get-Process explorer | 
                Where-Object { $_.Parent.ProcessName -eq 'winlogon' -or $null -eq $_.Parent } | 
                Stop-Process -Force
    }
}

### Stage 1: Windows Mode Change ###############################################
$Sunrise, $Sunset = Get-SunsetSunriseData
# Fix: Adding a minute to the Sunset and Sunrise ensures that the next time it runs, it will change as expected.
### TODO: May or may not address this since it's not "true" sunrise/sunset (on the other hand, it's a theme scheduler and it's only <=1 minute).
$Sunrise = $Sunrise.AddSeconds(5);
$Sunset = $Sunset.AddSeconds(5);
$SunIsInSky = $CURRENT_DATE -gt $Sunrise -and $CURRENT_DATE -lt $Sunset ? $true : $false

Set-WindowsModeLight $SunIsInSky

Write-Debug "Sunrise: $($Sunrise.ToString())`nSunset: $($Sunset.ToString())`nSun in Sky: $SunIsInSky"

### Stage 2: Task Scheduler ####################################################
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel "Highest"
$Actions = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument "-NoProfile -WindowStyle Hidden -File $PSScriptRoot -Latitude $Latitude -Longitude $Longitude"
$SunriseTrigger = New-ScheduledTaskTrigger -Daily -At $($Sunrise.ToString("HH:mm:ss"))
$SunsetTrigger = New-ScheduledTaskTrigger -Daily -At $($Sunset.ToString("HH:mm:ss"))
$LogonTrigger = New-ScheduledTaskTrigger -AtLogon

Unregister-ScheduledTask $TASK_NAME -Confirm:$false -ErrorAction 'SilentlyContinue' | Out-Null
Register-ScheduledTask -TaskName $TASK_NAME `
                       -TaskPath $TASK_PATH `
                       -Action $Actions `
                       -Trigger @($SunriseTrigger, $SunsetTrigger, $LogonTrigger) `
                       -Principal $Principal | 
        Out-Null
