@echo off
title Monitopr — API + interface
cd /d "%~dp0"

where npm >nul 2>&1
if errorlevel 1 (
    echo npm nao encontrado no PATH. Instale o Node.js ou abra o terminal do VS Code/Cursor.
    pause
    exit /b 1
)

echo.
echo  Iniciando backend ^(8080^) e frontend ^(5173^)...
echo  Pare com Ctrl+C quando quiser encerrar.
echo.

npm run rodar
set EXITCODE=%ERRORLEVEL%
echo.
if %EXITCODE% neq 0 (
    echo Se foi a primeira execucao, na raiz: npm install
    echo No backend: python -m venv .venv ^&^& .venv\Scripts\activate ^&^& pip install -r requirements.txt
)
pause
