@echo off
title Monitopr — Docker Compose
cd /d "%~dp0"

where docker >nul 2>&1
if errorlevel 1 (
    echo Docker nao encontrado. Instale o Docker Desktop e tente de novo.
    pause
    exit /b 1
)

echo.
echo  Subindo stack ^(nginx + frontend + backend + postgres^)...
echo  Interface: http://localhost  —  API: http://localhost:8000/docs
echo  Pare com Ctrl+C ^(ou feche esta janela apos docker compose down noutro terminal^).
echo.

docker compose up --build
echo.
pause
