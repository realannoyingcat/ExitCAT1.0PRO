@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: CATRNN "Game Session" booster
:: - Does NOT disable Windows Update or change drivers
:: - Uses only built-in tools (powercfg, ipconfig, PowerShell NetQos)
:: - QoS rules are non-persistent (ActiveStore) and removed with "off" or on reboot

:: -----------------------
:: Helper: unified exit
:: -----------------------
set "CATRNN_SUPPRESS_PAUSE=%CATRNN_SUPPRESS_PAUSE%"
set "CATRNN_EXIT_CODE=0"
set "CATRNN_MSG="

:RequireAdmin
net session >nul 2>&1
if %errorlevel% neq 0 (
  set "CATRNN_MSG=[!] Please right-click and 'Run as administrator'."
  set "CATRNN_EXIT_CODE=1"
  goto :END
)

if "%~1"=="" (
  echo Usage:
  echo   %~nx0 on    ^<-- enable game session tweaks
  echo   %~nx0 off   ^<-- restore previous state
  goto :END
)

set "STATEDIR=%~dp0state"
if not exist "%STATEDIR%" mkdir "%STATEDIR%"
set "PREVSCHEMEFILE=%STATEDIR%\prev_scheme.txt"

if /i "%~1"=="on"  goto :ON
if /i "%~1"=="off" goto :OFF

set "CATRNN_MSG=[!] Unknown argument: %~1"
set "CATRNN_EXIT_CODE=1"
goto :END

:ON
echo [*] Saving current power plan...
for /f "tokens=3" %%A in ('powercfg /getactivescheme ^| findstr /i "GUID"') do set CURR_SCHEME=%%A
echo !CURR_SCHEME!>"%PREVSCHEMEFILE%"

echo [*] Enabling "Ultimate Performance" plan (or equivalent)...
set "ULT_GUID=e9a42b02-d5df-448d-aa00-03f14749eb61"
powercfg -setactive %ULT_GUID% >nul 2>&1
if errorlevel 1 (
  for /f "tokens=3" %%G in ('powercfg -duplicatescheme %ULT_GUID% ^| findstr /i "GUID"') do set NEW_GUID=%%G
  if defined NEW_GUID (
    powercfg -setactive !NEW_GUID! >nul 2>&1
  ) else (
    echo [WARN] Could not switch to Ultimate Performance; continuing on current plan.
  )
)

echo [*] Setting Wi-Fi adapter (AC) to Maximum Performance on the CURRENT plan only...
powercfg /setacvalueindex SCHEME_CURRENT 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 0 >nul 2>&1

echo [*] Disabling PCIe Link State Power Management (AC) for latency (plan-local)...
powercfg /setacvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0 >nul 2>&1

echo [*] Flushing DNS cache...
ipconfig /flushdns

echo [*] Adding TEMPORARY QoS (DSCP 46) policies for common game ports (ActiveStore only)...
powershell -NoLogo -NoProfile -Command "Try { New-NetQosPolicy -Name 'CATRNN-Game-UDP-3074' -IPProtocolMatchCondition UDP -IPPortMatchCondition 3074 -DSCPAction 46 -PolicyStore ActiveStore -ErrorAction Stop | Out-Null } Catch {}"
powershell -NoLogo -NoProfile -Command "Try { New-NetQosPolicy -Name 'CATRNN-Game-TCP-3074' -IPProtocolMatchCondition TCP -IPPortMatchCondition 3074 -DSCPAction 46 -PolicyStore ActiveStore -ErrorAction Stop | Out-Null } Catch {}"
powershell -NoLogo -NoProfile -Command "Try { New-NetQosPolicy -Name 'CATRNN-Steam-UDP-27015-27050' -IPProtocolMatchCondition UDP -IPDstPortStartMatchCondition 27015 -IPDstPortEndMatchCondition 27050 -DSCPAction 46 -PolicyStore ActiveStore -ErrorAction Stop | Out-Null } Catch {}"
powershell -NoLogo -NoProfile -Command "Try { New-NetQosPolicy -Name 'CATRNN-PSN-UDP-3478' -IPProtocolMatchCondition UDP -IPPortMatchCondition 3478 -DSCPAction 46 -PolicyStore ActiveStore -ErrorAction SilentlyContinue | Out-Null } Catch {}"
powershell -NoLogo -NoProfile -Command "Try { New-NetQosPolicy -Name 'CATRNN-PSN-UDP-3479' -IPProtocolMatchCondition UDP -IPPortMatchCondition 3479 -DSCPAction 46 -PolicyStore ActiveStore -ErrorAction SilentlyContinue | Out-Null } Catch {}"
powershell -NoLogo -NoProfile -Command "Try { New-NetQosPolicy -Name 'CATRNN-PSN-TCP-3478' -IPProtocolMatchCondition TCP -IPPortMatchCondition 3478 -DSCPAction 46 -PolicyStore ActiveStore -ErrorAction SilentlyContinue | Out-Null } Catch {}"
powershell -NoLogo -NoProfile -Command "Try { New-NetQosPolicy -Name 'CATRNN-PSN-TCP-3479' -IPProtocolMatchCondition TCP -IPPortMatchCondition 3479 -DSCPAction 46 -PolicyStore ActiveStore -ErrorAction SilentlyContinue | Out-Null } Catch {}"
powershell -NoLogo -NoProfile -Command "Try { New-NetQosPolicy -Name 'CATRNN-PSN-TCP-3480' -IPProtocolMatchCondition TCP -IPPortMatchCondition 3480 -DSCPAction 46 -PolicyStore ActiveStore -ErrorAction SilentlyContinue | Out-Null } Catch {}"

echo.
echo [OK] Game session ON.
echo     - Ultimate/High performance power plan active
echo     - Wi-Fi on AC set to Max Performance
echo     - DNS cache cleared
echo     - QoS DSCP 46 marking active for common game ports (non-persistent)
echo Use "%~nx0 off" after gaming to restore.
goto :END

:OFF
echo [*] Removing temporary QoS policies...
powershell -NoLogo -NoProfile -Command "Get-NetQosPolicy -PolicyStore ActiveStore -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'CATRNN-*' } | ForEach-Object { Remove-NetQosPolicy -Name $_.Name -PolicyStore ActiveStore -Confirm:$false }"

echo [*] Restoring previous power plan...
set "RESTORE_SCHEME="
if exist "%PREVSCHEMEFILE%" set /p RESTORE_SCHEME=<"%PREVSCHEMEFILE%"
if defined RESTORE_SCHEME (
  powercfg -setactive %RESTORE_SCHEME% >nul 2>&1
) else (
  powercfg -setactive 381b4222-f694-41f0-9685-ff5bb260df2e >nul 2>&1
)

echo [OK] Game session OFF. Previous plan restored; QoS rules removed.
goto :END

:END
if defined CATRNN_MSG echo %CATRNN_MSG%
:: Pause unless explicitly suppressed (useful when double-clicked)
if not defined CATRNN_SUPPRESS_PAUSE (
  echo.
  pause
)
exit /b %CATRNN_EXIT_CODE%
