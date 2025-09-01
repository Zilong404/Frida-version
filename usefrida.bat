@echo off
setlocal enabledelayedexpansion

REM =========================
REM 帮助信息
REM =========================
if "%~1"=="" goto :help
if "%~1"=="-h" goto :help
if "%~1"=="--help" goto :help

REM =========================
REM 参数解析
REM 支持：
REM   usefrida.bat -Version 17.1.5 [--kill]
REM   usefrida.bat -Env frida17 [--kill]
REM   usefrida.bat               （自动检测当前环境版本）
REM =========================

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
    echo [!] 未知参数 %~1
    goto :help
)
shift
goto :parse

:done_parse

REM =========================
REM 选择虚拟环境
REM =========================
if defined VERSION (
    set "EnvName=frida-%VERSION%"
) else if defined ENVNAME (
    set "EnvName=%ENVNAME%"
) else (
    echo [*] 未指定 Version 或 Env，将使用当前环境...
    goto :detect_version
)

echo [*] 准备切换到虚拟环境: %EnvName%

REM 检查虚拟环境是否存在
for /f "tokens=*" %%i in ('workon') do (
    if "%%i"=="%EnvName%" set "FOUND=1"
)
if not defined FOUND (
    echo [!] 未找到虚拟环境 %EnvName%
    echo     请先运行：
    echo       mkvirtualenv %EnvName%
    if defined VERSION echo       pip install frida-tools==%VERSION%
    exit /b 1
)

REM 切换到虚拟环境
workon %EnvName%

:detect_version
REM =========================
REM 检测 frida-tools 版本
REM =========================
for /f "tokens=2 delims=: " %%i in ('pip show frida-tools ^| findstr /I "Version"') do (
    set "VERSION=%%i"
)

if not defined VERSION (
    echo [!] 未检测到 frida-tools，请检查环境
    exit /b 1
)

echo [*] 使用 frida-tools 版本: %VERSION%

REM =========================
REM 调用 frida_auto_match.sh
REM =========================
set "cmd=sh /data/local/tmp/frida_auto_match.sh %VERSION% %KILL%"

echo [*] 执行: adb shell %cmd%
adb shell %cmd%

echo [*] ✅ Frida 环境 + 服务端已就绪
exit /b 0


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
exit /b 0
