@echo off
title Limpiador de Archivos Temporales
color 0C

echo ========================================
echo    LIMPIADOR DE ARCHIVOS TEMPORALES
echo ========================================
echo.
echo Este script limpiara:
echo - Temp del usuario
echo - Temp del sistema
echo - Prefetch
echo - Papelera de reciclaje
echo.
echo.
pause

echo [1/4] Limpiando Temp del usuario...
if exist "%temp%\*" (
    rmdir /s /q "%temp%"
    mkdir "%temp%" >nul 2>&1
)

echo [2/4] Limpiando Temp del sistema...
if exist "C:\Windows\Temp\*" (
    rmdir /s /q "C:\Windows\Temp"
    mkdir "C:\Windows\Temp" >nul 2>&1
)

echo [3/4] Limpiando Prefetch...
if exist "C:\Windows\Prefetch\*" (
    del /q /f /s "C:\Windows\Prefetch\*.*" >nul 2>&1
)

echo [4/4] Limpiando Papelera de reciclaje...
powershell -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue"

echo.
echo ========================================
echo    LIMPIEZA COMPLETADA EXITOSAMENTE!
echo ========================================
echo.
pause
