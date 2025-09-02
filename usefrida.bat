@echo off
setlocal enabledelayedexpansion

:: =========================
:: 日志函数
:: =========================
:log
set "LEVEL=%~1"
set "MSG=%~2"
for /f "tokens=1-3 delims=:.," %%a in ("%time%") do (
    set "t=%%a:%%b:%%c"
)
echo [!date! !t!] [%LEVEL%] %MSG%
exit /b

:: =========================
:: 帮助信息
:: =========================
if "%~1"=="" goto :help
if "%~1"=="-h" goto :help
if "%~1"=="--help" goto :help

:: =========================
:: 参数解析
:: =========================
set "VERSION="
set "ENVNAME="
set "KILL="

:parse
if "%~1"=="" goto :done_parse
if "%~1"=="-Version" (
    set "VERSION=%~2"
    shift
) else if "%~1"=="-Env" (
    set "ENVNAME=%~2"
    shift
) else if "%~1"=="--kill" (
    set "KILL=--kill"
) else (
    call :log ERROR "未知参数 %~1"
    goto :help
)
shift
goto :parse

:done_parse

:: =========================
:: 选择虚拟环境
:: =========================
if defined VERSION (
    set "EnvName=frida-%VERSION%"
) else if defined ENVNAME (
    set "EnvName=%ENVNAME%"
) else (
    call :log INFO "未指定 Version 或 Env，将使用当前环境..."
    goto :detect_version
)

call :log INFO "准备切换到虚拟环境: %EnvName%"

:: 检查虚拟环境是否存在
set "FOUND="
for /f "tokens=*" %%i in ('workon') do (
    if "%%i"=="%EnvName%" set "FOUND=1"
)
if not defined FOUND (
    call :log ERROR "未找到虚拟环境 %EnvName%"
    echo     请先运行：
    echo       mkvirtualenv %EnvName%
    if defined VERSION echo       pip install frida-tools==%VERSION%
    goto :end
)

:: 切换到虚拟环境
workon %EnvName%

:detect_version
:: =========================
:: 检测 frida-tools 版本
:: =========================
set "VERSION="
for /f "tokens=2 delims=: " %%i in ('pip show frida-tools ^| findstr /I "Version"') do (
    set "VERSION=%%i"
)

if not defined VERSION (
    call :log ERROR "未检测到 frida-tools，请检查环境"
    goto :end
)

call :log INFO "使用 frida-tools 版本: %VERSION%"

:: =========================
:: 调用 frida_auto_match.sh
:: =========================
set "cmd=sh /data/local/tmp/frida_auto_match.sh %VERSION% %KILL%"

call :log INFO "执行: adb shell %cmd%"
adb shell %cmd%

if %errorlevel% neq 0 (
    call :log ERROR "adb 执行失败，请检查连接和脚本"
    goto :end
)

call :log INFO "✅ Frida 环境 + 服务端已就绪"
goto :end


:help
echo 用法:
echo   usefrida.bat -Version ^<版本号^> [--kill]
echo   usefrida.bat -Env ^<环境名^> [--kill]
echo   usefrida.bat               （自动检测当前环境版本）
echo   usefrida.bat -h ^| --help
echo.
echo 示例:
echo   usefrida.bat -Version 16.1.0
echo   usefrida.bat -Version 17.1.5 --kill
echo   usefrida.bat -Env frida17
echo   usefrida.bat --kill

:end
echo.
pause
exit /b 0
