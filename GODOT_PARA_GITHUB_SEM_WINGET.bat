@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"
title Godot - Enviar projeto para GitHub

echo ============================================================
echo        GODOT ^> GITHUB - SEM WINGET / AUTOMATICO
echo ============================================================
echo.
echo Pasta atual:
echo %CD%
echo.

if not exist "project.godot" (
    echo [ERRO] Nao encontrei project.godot nesta pasta.
    echo Coloque este BAT na raiz do seu projeto Godot.
    echo.
    pause
    exit /b 1
)

rem ============================================================
rem 1) ENCONTRAR GIT
rem ============================================================
set "GITEXE="

where git >nul 2>nul
if not errorlevel 1 set "GITEXE=git"

if not defined GITEXE if exist "%ProgramFiles%\Git\cmd\git.exe" set "GITEXE=%ProgramFiles%\Git\cmd\git.exe"
if not defined GITEXE if exist "%ProgramFiles%\Git\bin\git.exe" set "GITEXE=%ProgramFiles%\Git\bin\git.exe"
if not defined GITEXE if exist "%LocalAppData%\Programs\Git\cmd\git.exe" set "GITEXE=%LocalAppData%\Programs\Git\cmd\git.exe"

if not defined GITEXE (
    echo [ERRO] Git nao encontrado.
    echo.
    echo Instale o Git for Windows:
    start "" "https://git-scm.com/download/win"
    echo Depois feche esta janela e execute este BAT novamente.
    pause
    exit /b 1
)

echo [OK] Git encontrado:
"%GITEXE%" --version
echo.

rem ============================================================
rem 2) ENCONTRAR OU BAIXAR GITHUB CLI PORTATIL
rem ============================================================
set "GHEXE="

where gh >nul 2>nul
if not errorlevel 1 set "GHEXE=gh"

if not defined GHEXE if exist "%ProgramFiles%\GitHub CLI\gh.exe" set "GHEXE=%ProgramFiles%\GitHub CLI\gh.exe"
if not defined GHEXE if exist "%LocalAppData%\Programs\GitHub CLI\gh.exe" set "GHEXE=%LocalAppData%\Programs\GitHub CLI\gh.exe"

if not defined GHEXE (
    echo GitHub CLI nao encontrado.
    echo Vou baixar uma copia PORTATIL oficial dentro deste projeto.
    echo Nao precisa de winget nem instalacao no Windows.
    echo.

    set "TOOLSDIR=%CD%\.github_tools"
    set "GHROOT=!TOOLSDIR!\gh"
    set "GHZIP=!TOOLSDIR!\gh.zip"

    if not exist "!TOOLSDIR!" mkdir "!TOOLSDIR!" >nul 2>nul
    if exist "!GHROOT!" rmdir /s /q "!GHROOT!" >nul 2>nul
    mkdir "!GHROOT!" >nul 2>nul

    echo Consultando a versao mais recente do GitHub CLI...

    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "$ErrorActionPreference='Stop';" ^
      "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
      "$r=Invoke-RestMethod 'https://api.github.com/repos/cli/cli/releases/latest';" ^
      "$a=$r.assets | Where-Object { $_.name -match '^gh_.*_windows_amd64\.zip$' } | Select-Object -First 1;" ^
      "if(-not $a){ throw 'Arquivo windows_amd64.zip nao encontrado.' };" ^
      "Write-Host ('Baixando ' + $a.name + ' ...');" ^
      "Invoke-WebRequest -UseBasicParsing $a.browser_download_url -OutFile '%CD%\.github_tools\gh.zip';"

    if errorlevel 1 (
        echo.
        echo [ERRO] Nao consegui baixar o GitHub CLI.
        echo Verifique sua internet/firewall e execute novamente.
        pause
        exit /b 1
    )

    echo Extraindo GitHub CLI...
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "$ErrorActionPreference='Stop';" ^
      "Expand-Archive -LiteralPath '%CD%\.github_tools\gh.zip' -DestinationPath '%CD%\.github_tools\gh' -Force"

    if errorlevel 1 (
        echo [ERRO] Falha ao extrair o GitHub CLI.
        pause
        exit /b 1
    )

    del /q "!GHZIP!" >nul 2>nul

    for /r "!GHROOT!" %%G in (gh.exe) do (
        if not defined GHEXE set "GHEXE=%%~fG"
    )

    if not defined GHEXE (
        echo [ERRO] Baixei o GitHub CLI, mas nao achei gh.exe.
        pause
        exit /b 1
    )
)

echo [OK] GitHub CLI pronto:
"%GHEXE%" --version | findstr /I "gh version"
echo.

rem ============================================================
rem 3) LOGIN NO GITHUB
rem ============================================================
"%GHEXE%" auth status --hostname github.com >nul 2>nul
if errorlevel 1 (
    echo ============================================================
    echo                    LOGIN NO GITHUB
    echo ============================================================
    echo.
    echo O navegador sera usado para voce autorizar sua conta GitHub.
    echo O BAT nao pede nem salva sua senha.
    echo.
    "%GHEXE%" auth login --hostname github.com --git-protocol https --web

    if errorlevel 1 (
        echo.
        echo [ERRO] Login nao concluido.
        pause
        exit /b 1
    )
)

echo.
echo [OK] Login confirmado.
echo.

set "GHUSER="
set "GHID="

for /f "usebackq delims=" %%A in (`"%GHEXE%" api user --jq ".login" 2^>nul`) do set "GHUSER=%%A"
for /f "usebackq delims=" %%A in (`"%GHEXE%" api user --jq ".id" 2^>nul`) do set "GHID=%%A"

if not defined GHUSER (
    echo [ERRO] Nao consegui identificar sua conta GitHub.
    pause
    exit /b 1
)

echo Conta: !GHUSER!
echo.

rem ============================================================
rem 4) GITIGNORE / SEGREDOS
rem ============================================================
call :ENSURE_IGNORE ".env"
call :ENSURE_IGNORE ".godot/"
call :ENSURE_IGNORE ".godot_ai_venv/"
call :ENSURE_IGNORE ".github_tools/"
call :ENSURE_IGNORE "__pycache__/"
call :ENSURE_IGNORE "*.pyc"
call :ENSURE_IGNORE "*.bak_openai_assistant"
call :ENSURE_IGNORE "Godot_OpenAI_Assistant.zip"
call :ENSURE_IGNORE "Godot_OpenAI_Assistant/"

echo [OK] Arquivos privados e temporarios protegidos.
echo.

rem ============================================================
rem 5) INICIALIZAR GIT
rem ============================================================
if not exist ".git" (
    "%GITEXE%" init
    if errorlevel 1 goto :GIT_ERROR
)

"%GITEXE%" branch -M main >nul 2>nul

rem Remove do indice caso algum desses tenha sido adicionado antes.
"%GITEXE%" rm -r --cached --ignore-unmatch ".env" ".godot" ".godot_ai_venv" ".github_tools" "__pycache__" "Godot_OpenAI_Assistant.zip" "Godot_OpenAI_Assistant" >nul 2>nul

rem Identidade local de commits.
set "GITNAME="
set "GITEMAIL="
for /f "usebackq delims=" %%A in (`"%GITEXE%" config user.name 2^>nul`) do set "GITNAME=%%A"
for /f "usebackq delims=" %%A in (`"%GITEXE%" config user.email 2^>nul`) do set "GITEMAIL=%%A"

if not defined GITNAME "%GITEXE%" config user.name "!GHUSER!"
if not defined GITEMAIL (
    if defined GHID (
        "%GITEXE%" config user.email "!GHID!+!GHUSER!@users.noreply.github.com"
    ) else (
        "%GITEXE%" config user.email "!GHUSER!@users.noreply.github.com"
    )
)

rem ============================================================
rem 6) COMMIT
rem ============================================================
echo Preparando arquivos...
"%GITEXE%" add .
if errorlevel 1 goto :GIT_ERROR

rem Seguranca extra.
"%GITEXE%" reset -- ".env" >nul 2>nul

"%GITEXE%" diff --cached --quiet
if errorlevel 1 (
    set "MSG="
    set /p "MSG=Mensagem do commit [Atualizacao do projeto Godot]: "
    if not defined MSG set "MSG=Atualizacao do projeto Godot"

    "%GITEXE%" commit -m "!MSG!"
    if errorlevel 1 goto :GIT_ERROR
) else (
    echo [OK] Nao ha novas alteracoes para commit.
)

echo.

rem ============================================================
rem 7) REMOTE / CRIAR REPOSITORIO
rem ============================================================
set "ORIGIN="
for /f "usebackq delims=" %%A in (`"%GITEXE%" remote get-url origin 2^>nul`) do set "ORIGIN=%%A"

if not defined ORIGIN (
    for %%I in ("%CD%") do set "DEFAULT_REPO=%%~nxI"

    echo ============================================================
    echo                 REPOSITORIO NO GITHUB
    echo ============================================================
    echo.
    set "REPONAME="
    set /p "REPONAME=Nome do repositorio [!DEFAULT_REPO!]: "
    if not defined REPONAME set "REPONAME=!DEFAULT_REPO!"

    echo.
    echo [1] Privado  ^(recomendado^)
    echo [2] Publico
    choice /C 12 /N /M "Escolha: "

    if errorlevel 2 (
        set "VISIBILITY=public"
    ) else (
        set "VISIBILITY=private"
    )

    "%GHEXE%" repo view "!GHUSER!/!REPONAME!" >nul 2>nul
    if not errorlevel 1 (
        echo O repositorio ja existe. Conectando...
        "%GITEXE%" remote add origin "https://github.com/!GHUSER!/!REPONAME!.git"
        if errorlevel 1 goto :GIT_ERROR
    ) else (
        echo Criando !GHUSER!/!REPONAME!...
        "%GHEXE%" repo create "!REPONAME!" --!VISIBILITY! --source "." --remote origin
        if errorlevel 1 (
            echo [ERRO] Nao consegui criar o repositorio.
            pause
            exit /b 1
        )
    )
)

echo.

rem ============================================================
rem 8) PUSH
rem ============================================================
echo Enviando projeto para o GitHub...
"%GITEXE%" push -u origin main

if errorlevel 1 (
    echo.
    echo [ERRO] Falha no push.
    echo Nada foi apagado do seu computador.
    echo.
    pause
    exit /b 1
)

for /f "usebackq delims=" %%A in (`"%GITEXE%" remote get-url origin`) do set "FINALREMOTE=%%A"
set "WEBURL=!FINALREMOTE:.git=!"

echo.
echo ============================================================
echo                         PRONTO
echo ============================================================
echo.
echo Projeto enviado para:
echo !WEBURL!
echo.
echo Nas proximas vezes use este MESMO BAT para atualizar o GitHub.
echo.
start "" "!WEBURL!"
pause
exit /b 0


:ENSURE_IGNORE
set "IGNORE_LINE=%~1"
if not exist ".gitignore" type nul > ".gitignore"
findstr /X /C:"%IGNORE_LINE%" ".gitignore" >nul 2>nul
if errorlevel 1 >>".gitignore" echo %IGNORE_LINE%
exit /b 0


:GIT_ERROR
echo.
echo [ERRO] O Git encontrou um problema.
echo Leia a mensagem acima. Nenhum arquivo local foi apagado.
echo.
pause
exit /b 1
