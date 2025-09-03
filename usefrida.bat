@echo off
setlocal enabledelayedexpansion

set "ARGS="
set "TARGET_ENV="
set "FRIDA_VER="

:parse
if "%~1"=="" goto done
if /I "%~1"=="-Version" (
    set "FRIDA_VER=%2"
    shift
) else if /I "%~1"=="-Env" (
    set "TARGET_ENV=%2"
    shift
) else (
    set "ARGS=!ARGS! %1"
)
shift
goto parse
:done

:: 如果指定了 -Env，则先激活虚拟环境并探测版本号
if not "%TARGET_ENV%"=="" (
    echo [INFO] 激活虚拟环境: %TARGET_ENV%
    call workon %TARGET_ENV%
    if errorlevel 1 (
        echo [ERROR] 激活虚拟环境失败，请检查环境名是否正确
        pause
        exit /b 1
    )

    :: 在该虚拟环境下探测 frida 版本
    for /f "delims=" %%v in ('frida --version') do set "FRIDA_VER=%%v"
    echo [INFO] 环境 %TARGET_ENV% 内 frida 版本: %FRIDA_VER%
)

:: 如果既没有指定 -Env 也没有 -Version，则自动探测当前环境版本
if "%FRIDA_VER%"=="" (
    for /f "delims=" %%v in ('frida --version') do set "FRIDA_VER=%%v"
    echo [INFO] 当前环境 frida 版本: %FRIDA_VER%
)

:: 拼接最终命令，调用 Android 端脚本
echo [INFO] 调用 Android 脚本: /data/local/tmp/frida_auto_match.sh %FRIDA_VER% %ARGS%
adb shell "sh /data/local/tmp/frida_auto_match.sh %FRIDA_VER% %ARGS%"

if %errorlevel% neq 0 (
    echo [ERROR] 在 Android 端执行失败
    pause
    exit /b 1
)

echo [INFO] ✅ frida-server 已 root 常驻
pause
exit /b 0
