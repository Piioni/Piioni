@echo off
title Actualizador de Gestores de Paquetes
color 0A

:: Verificar si ya es administrador
net session >nul 2>&1
if %errorLevel% == 0 goto admin

:: Si no es admin, solicitar elevación
echo Solicitando permisos de administrador...
powershell -Command "Start-Process cmd -ArgumentList '/c %~dpnx0' -Verb RunAs"
exit /b

:admin
echo ========================================
echo    ACTUALIZADOR DE GESTORES DE PAQUETES
echo ========================================
echo.
echo Este script actualizara:
echo - Chocolatey
echo - Scoop
echo.
pause

echo.
echo [1/2] Actualizando Chocolatey...
choco upgrade all -y

echo.
echo [2/2] Actualizando Scoop y sus aplicaciones...
scoop update *
scoop update * --global


echo.
echo ========================================
echo    ACTUALIZACION COMPLETADA!
echo ========================================
echo.
timeout /t 5
