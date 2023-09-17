# Windows Sunset Theme Switcher

- Requires: Windows 11, PowerShell 7+ (pwsh.exe), active internet connection
    - Not tested, but this should work for Windows 10 as well.
    - It may run on a lower version of PowerShell, but I'm fairly certain this won't run in "Windows PowerShell" (i.e. powershell.exe, PowerShell 5.1). I would recommend installing the latest version either way.
    - This currently requires an internet connection and queries the public sunrise-sunset.org API. No API key required.

## About

A simple script that changes the Windows Theme Mode on sunset/sunrise to dark/light respectively. It does not change other personalization settings.

## Installation & Use

### Windows File Explorer Settings

This change is **HIGHLY RECOMMENDED**. Please read.

In order to enforce the change of mode to the taskbar and other desktop elements, this script restarts the _explorer.exe_ process that manages the desktop. Without doing so, the change to the theme mode will not apply to the task bar and some other desktop-related elements. 

If the below setting is _not_ enabled, it will close all open file explorer windows as well, which is obviously undesired. (I would recommend this change regardless of whether you choose to use this script: if the desktop crashes, your open File Explorer windows likely won't).

1. Open a File Explorer window (Win+E) and click on the elipses in the top-right, click Options
2. Under the View tab, enable the 'Launch folder windows in a separate process' option and click OK to apply.

Note that after the change, you will need to restart the explorer.exe process. You can do so in PowerShell with the following command: `ps explorer | kill`

### Task Scheduler

Eventually, I plan to add an -Install switch, but in the meantime, here is my recommendation for installing on a system:

1. Place the script file in a permanent location of your choosing.
2. Run `Unblock-File` on the file.
3. Open Windows Task Scheduler.
4. Expand the Task Scheduler Library on the left-hand side. You can create the task in the root of this folder or, as I would recommend, create your own folder and create the task in there.
5. Action > Create Task...
6. **General Tab**
    1. Set a name and description of your choosing.
    2. If it isn't by default, set the user to the current logged in user account.
    3. Ensure 'Run whether user is logged on or not' is selected; do not enable "Do not store password" sub option.
    4. Enable 'Run with highest privileges' (only necessary if you are running it from a location that requires admin rights or if you have more than one user account that uses the PC)
7. **Triggers**
    1. Click New...
    2. Change 'Begin the task' to 'At log on'
    3. Ensure "Any user" is selected
    4. Under advanced settings, enable 'Repeat task every:' and set it to '5 minutes, for a duration of Indefinitely'
    5. Ensure 'Enabled' is checked.
8. **Actions**
    1. Select the Action 'Start a program'.
    2. Use **pwsh.exe** for the Program/script
    3. Use **-NoProfile -NonInteractive -File C:\Users\Username\windows-sunset-theme-switcher.ps1 -Latitude 0.0 -Longitude 0.0** in the arguments field. *NOTE: Replace the path with the script path you chose in Step 1. Replace the Latitude and Longitude arguments with your latitude and longitude.*
9. **Conditions**
    1. No changes needed unless you're on a laptop. Then you may wish to enable/disable 'Start the task only if the computer is on AC power' and its sub-option. Alternatively, you can change the Trigger to fire less frequently than 5 minutes. This script is pretty lightweight so I can't imagine it'd have a major effect on battery.
10. **Settings**
    1. Defaults suffice.

## Roadmap
- **Installation Switch**
    - A switch in the script to set up the Task Scheduler item automatically so the above instructions become optional.
- **Offline sunset calculation**
    - Either through my own functions or via an external library, it would be beneficial to have the option to calculate offline. This is a privacy feature in addition to a redundancy feature.
