@echo off
setlocal enabledelayedexpansion

:: =====================================================
:: usefrida.bat - 一键启动 Frida Server (仅手机端)
:: 支持命令：
::   usefrida.bat               -> 部署/启动手机端 frida-server
::   usefrida.bat --kill        -> 杀掉旧进程并重启
::   usefrida.bat --status      -> 检查手机端 frida-server 状态
:: =====================================================

:log
set "LEVEL=%~1"
set "MSG=%~2"
for /f "tokens=1-3 delims=:.," %%a in ("%time%") do (
    set "t=%%a:%%b:%%c"
)
echo [%date% !t!] [%LEVEL%] %MSG%
exit /b

:: ================== STEP 1: 参数解析 ==================
set ACTION=start
set KILL_FLAG=

if "%~1"=="--kill" (
    set ACTION=start
    set KILL_FLAG=--kill
)
if "%~1"=="--status" (
    set ACTION=status
)

:: ================== STEP 2: 推送脚本 (非 status 模式) ==================
if "%ACTION%"=="start" (
    call :log INFO "推送 frida_auto_match.sh 到手机..."
    adb push device/frida_auto_match.sh /data/local/tmp/ >nul
    adb shell chmod +x /data/local/tmp/frida_auto_match.sh

    :: 默认版本号，可根据需要固定，比如 "16.5.2"
    set FRIDA_VERSION=16.5.2

    call :log INFO "执行手机端脚本，版本=%FRIDA_VERSION%，参数=%KILL_FLAG%"
    adb shell "sh /data/local/tmp/frida_auto_match.sh %FRIDA_VERSION% %KILL_FLAG%"
    call :log INFO "部署完成，查看日志: adb shell cat /data/local/tmp/frida.log"
    exit /b
)

:: ================== STEP 3: 检查状态 ==================
if "%ACTION%"=="status" (
    call :log INFO "检查手机端 frida-server 状态..."
    adb shell "ps -A | grep frida-server"
    if errorlevel 1 (
        call :log ERROR "frida-server 未在运行"
    ) else (
        call :log INFO "frida-server 正在运行"
    )
    exit /b
)
