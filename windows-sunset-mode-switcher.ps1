# Ver 3.1

param (
    [Parameter(
        Position=0, 
        ParameterSetName = 'Standard'
    )]
    [double]
    $Latitude = 0,

    [Parameter(
        Position=1,
        ParameterSetName = 'Standard'
    )]
    [double]
    $Longitude = 0,

    [Parameter(
        Position=2,
        ParameterSetName = 'Standard'
    )]
    [string]
    [ValidateSet("Light", "Dark")]
    $SetMode,

    [Parameter(
        ParameterSetName = 'Standard'
    )]
    [string]
    $PrincipalUserId = $env:USERNAME,

    [Parameter(
        ParameterSetName = 'Uninstall',
        Mandatory = $true
    )]
    [switch]
    [Alias("Remove")]
    $Uninstall
)

$TASK_PATH = "\windows-sunset-mode-switcher\"
$TASK_NAME = "windows-sunset-mode-switcher"
$TASK_NAME_SUNRISE = $TASK_NAME + "-sunrise"
$TASK_NAME_SUNSET = $TASK_NAME + "-sunset"
if ($Uninstall) {
    foreach ($taskName in @($TASK_NAME, $TASK_NAME_SUNRISE, $TASK_NAME_SUNSET)) {
        Unregister-ScheduledTask -TaskName $taskName -TaskPath $TASK_PATH | Out-Null
    }

    return
}
$TASK_PRINCIPAL = New-ScheduledTaskPrincipal -UserId $PrincipalUserId -RunLevel "Highest"
$CURRENT_DATE = Get-Date

# Used to determine the next Sunrise and Sunset for Task Scheduler triggers.
function Get-SunriseSunset { # [datetime], [datetime]
    param()
    if ($Latitude -eq 0 -and $Longitude -eq 0) { 
        Write-Warning 'It appears you didn''t supply a latitude or longitude. Defaulting to 0, 0.' 
    }

    $URL_API = "https://api.sunrise-sunset.org/json?lat=$Latitude&lng=$Longitude&formatted=0"
    $URL_TODAY = "$URL_API&date=$($CURRENT_DATE.ToString("yyyy-MM-dd"))"
    $URL_TOMORROW = "$URL_API&date=$($CURRENT_DATE.AddDays(1).ToString("yyyy-MM-dd"))"

    Write-Debug "Invoking web requests...`nAPI URLs:`n`t$URL_TODAY`n`t$URL_TOMORROW"

    $ResponseToday = Invoke-WebRequest -Uri $URL_TODAY
    $ResponseContentToday = $ResponseToday.Content | ConvertFrom-Json
    $ResponseTomorrow = Invoke-WebRequest -Uri $URL_TOMORROW
    $ResponseContentTomorrow = $ResponseTomorrow.Content | ConvertFrom-Json

    Write-Debug "Processing web requests..."
    
    if ($ResponseContentToday.status -eq "OK" && $ResponseContentTomorrow.status -eq "OK") {
        $SunriseToday = Get-Date $ResponseContentToday.results.sunrise
        $SunsetToday = Get-Date $ResponseContentToday.results.sunset
        $SunriseTomorrow = Get-Date $ResponseContentTomorrow.results.sunrise
        $SunsetTomorrow = Get-Date $ResponseContentTomorrow.results.sunset

        $Sunrise = $CURRENT_DATE -le $SunriseToday ? $SunriseToday : $SunriseTomorrow
        $Sunset = $CURRENT_DATE -le $SunsetToday ? $SunsetToday : $SunsetTomorrow
    }
    else {
        throw "Error: Bad Response: $($ResponseContent.status)"
    }

    return @($Sunrise, $Sunset)
}

# Sets the registry keys that change the app & system mode
function Set-WindowsModeLight {
    param(
        [Parameter(Position=0)]
        [bool]
        $On
    )

    $REG_PATH_PERSONALIZATION = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    
    $CurrentValue = Get-ItemPropertyValue -Path $REG_PATH_PERSONALIZATION -Name 'SystemUsesLightTheme'

    if ([int]$On -ne $CurrentValue) {
        Write-Debug 'Changing Windows Theme Mode...'

        'SystemUsesLightTheme','AppsUseLightTheme' | ForEach-Object {
            New-ItemProperty -Path $REG_PATH_PERSONALIZATION -Name $_ -Value $([int]$On) -PropertyType 'DWORD' -Force | Out-Null
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
# Need sunset, sunrise for calculation and/or task creation.
$Sunrise, $Sunset = Get-SunriseSunset

# SetMode override handling
if ($SetMode -eq 'Dark' -or $SetMode -eq 'Light') {
    $SunIsInSky = $SetMode -eq "Light" ? $true : $false
}
else {
    $SunIsInSky = $CURRENT_DATE -ge $Sunrise -and $CURRENT_DATE -le $Sunset ? $true : $false
}

Set-WindowsModeLight $SunIsInSky

Write-Debug "Sunrise: $($Sunrise.ToString())`nSunset: $($Sunset.ToString())`nSun in Sky: $SunIsInSky"

### Stage 2: Task Scheduler ####################################################

$Execute = 'C:\Program Files\PowerShell\7\pwsh.exe'
$Argument = "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File $PSCommandPath -Latitude $Latitude -Longitude $Longitude"

$Tasks = @(
    @{
        TaskName = $TASK_NAME_SUNRISE
        TaskPath = $TASK_PATH
        Principal = $TASK_PRINCIPAL
        Action = New-ScheduledTaskAction -Execute $Execute `
                                        -Argument "$Argument -SetMode Light"
        Trigger = New-ScheduledTaskTrigger -Daily -At $($Sunrise.ToString("HH:mm:ss"))
    },
    @{
        TaskName = $TASK_NAME_SUNSET
        TaskPath = $TASK_PATH
        Principal = $TASK_PRINCIPAL
        Action = New-ScheduledTaskAction -Execute $Execute `
                                        -Argument "$Argument -SetMode Dark"
        Trigger = New-ScheduledTaskTrigger -Daily -At $($Sunset.ToString("HH:mm:ss"))
    },
    @{
        TaskName = $TASK_NAME
        TaskPath = $TASK_PATH
        Principal = $TASK_PRINCIPAL
        Action = New-ScheduledTaskAction -Execute $Execute `
                                        -Argument $Argument
        Trigger = New-ScheduledTaskTrigger -AtLogon
    }
)

foreach ($task in $Tasks) {
    Unregister-ScheduledTask $($task.TaskName) -Confirm:$false -ErrorAction 'SilentlyContinue' | Out-Null
    Register-ScheduledTask @task | Out-Null
}
