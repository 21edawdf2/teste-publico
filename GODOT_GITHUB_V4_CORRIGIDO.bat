@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"

if /I not "%~1"=="--interno" (
    start "Godot para GitHub" cmd /k call "%~f0" --interno
    exit /b
)

title Godot - GitHub V4

set "LOG=%CD%\github_setup_log.txt"
> "%LOG%" echo ==== Godot para GitHub V4 ====
>>"%LOG%" echo Pasta: %CD%
>>"%LOG%" echo Data: %DATE% %TIME%

echo ============================================================
echo            GODOT ^> GITHUB - V4 CORRIGIDO
echo ============================================================
echo.
echo Esta janela ficara aberta se algo der errado.
echo.

if not exist "project.godot" (
    echo [ERRO] Nao encontrei project.godot nesta pasta.
    echo Coloque este BAT na raiz do projeto Godot.
    goto :ERRO
)

rem ============================================================
rem GIT
rem ============================================================
set "GITEXE="
where git >nul 2>nul
if not errorlevel 1 set "GITEXE=git"
if not defined GITEXE if exist "%ProgramFiles%\Git\cmd\git.exe" set "GITEXE=%ProgramFiles%\Git\cmd\git.exe"
if not defined GITEXE if exist "%ProgramFiles%\Git\bin\git.exe" set "GITEXE=%ProgramFiles%\Git\bin\git.exe"
if not defined GITEXE if exist "%LocalAppData%\Programs\Git\cmd\git.exe" set "GITEXE=%LocalAppData%\Programs\Git\cmd\git.exe"

if not defined GITEXE (
    echo [ERRO] Git nao encontrado.
    start "" "https://git-scm.com/download/win"
    goto :ERRO
)

echo [OK] Git encontrado:
"%GITEXE%" --version
echo.

rem ============================================================
rem GITHUB CLI
rem ============================================================
set "GHEXE="
where gh >nul 2>nul
if not errorlevel 1 set "GHEXE=gh"
if not defined GHEXE if exist "%ProgramFiles%\GitHub CLI\gh.exe" set "GHEXE=%ProgramFiles%\GitHub CLI\gh.exe"
if not defined GHEXE if exist "%LocalAppData%\Programs\GitHub CLI\gh.exe" set "GHEXE=%LocalAppData%\Programs\GitHub CLI\gh.exe"

set "TOOLSDIR=%CD%\.github_tools"
set "GHROOT=%TOOLSDIR%\gh"
set "GHZIP=%TOOLSDIR%\gh.zip"

if not defined GHEXE if exist "%GHROOT%\bin\gh.exe" set "GHEXE=%GHROOT%\bin\gh.exe"

if not defined GHEXE if exist "%GHROOT%" (
    for /f "delims=" %%G in ('dir /s /b "%GHROOT%\gh.exe" 2^>nul') do (
        if not defined GHEXE set "GHEXE=%%G"
    )
)

if not defined GHEXE (
    echo GitHub CLI nao encontrado.
    echo Baixando copia portatil oficial...
    echo.

    if not exist "%TOOLSDIR%" mkdir "%TOOLSDIR%"
    if exist "%GHROOT%" rmdir /s /q "%GHROOT%"
    mkdir "%GHROOT%"

    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "$ErrorActionPreference='Stop';" ^
      "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
      "$r=Invoke-RestMethod -Headers @{'User-Agent'='Godot-GitHub-Setup'} -Uri 'https://api.github.com/repos/cli/cli/releases/latest';" ^
      "$a=$r.assets | Where-Object { $_.name -match '^gh_.*_windows_amd64\.zip$' } | Select-Object -First 1;" ^
      "if(-not $a){throw 'Nao achei o ZIP windows_amd64.'};" ^
      "Write-Host ('Baixando ' + $a.name + ' ...');" ^
      "Invoke-WebRequest -UseBasicParsing -Headers @{'User-Agent'='Godot-GitHub-Setup'} -Uri $a.browser_download_url -OutFile '%GHZIP%';"

    if errorlevel 1 (
        echo [ERRO] Falha no download do GitHub CLI.
        goto :ERRO
    )

    echo Extraindo GitHub CLI...
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "$ErrorActionPreference='Stop';" ^
      "Expand-Archive -LiteralPath '%GHZIP%' -DestinationPath '%GHROOT%' -Force"

    if errorlevel 1 (
        echo [ERRO] Falha ao extrair GitHub CLI.
        goto :ERRO
    )

    del /q "%GHZIP%" >nul 2>nul

    if exist "%GHROOT%\bin\gh.exe" set "GHEXE=%GHROOT%\bin\gh.exe"

    if not defined GHEXE (
        for /f "delims=" %%G in ('dir /s /b "%GHROOT%\gh.exe" 2^>nul') do (
            if not defined GHEXE set "GHEXE=%%G"
        )
    )
)

if not defined GHEXE (
    echo [ERRO] Nao encontrei gh.exe.
    goto :ERRO
)

echo [OK] GitHub CLI:
"%GHEXE%" --version
echo.

rem ============================================================
rem LOGIN
rem ============================================================
"%GHEXE%" auth status --hostname github.com >nul 2>nul
if errorlevel 1 (
    echo ============================================================
    echo                    LOGIN NO GITHUB
    echo ============================================================
    echo.
    echo Pressione ENTER quando o GitHub CLI pedir.
    echo Depois autorize no navegador.
    echo.
    "%GHEXE%" auth login --hostname github.com --git-protocol https --web
    if errorlevel 1 (
        echo [ERRO] Login nao concluido.
        goto :ERRO
    )
)

echo [OK] Login confirmado.
echo.

rem ============================================================
rem LER USUARIO - MODO ROBUSTO (corrige a V3)
rem ============================================================
set "TMPUSER=%TEMP%\godot_gh_user_%RANDOM%.txt"
set "TMPID=%TEMP%\godot_gh_id_%RANDOM%.txt"

"%GHEXE%" api user --jq .login > "%TMPUSER%" 2>nul
if errorlevel 1 (
    echo [ERRO] O GitHub CLI esta logado, mas a API nao respondeu.
    if exist "%TMPUSER%" type "%TMPUSER%"
    goto :ERRO
)

set "GHUSER="
set /p GHUSER=<"%TMPUSER%"

"%GHEXE%" api user --jq .id > "%TMPID%" 2>nul
set "GHID="
if exist "%TMPID%" set /p GHID=<"%TMPID%"

del /q "%TMPUSER%" "%TMPID%" >nul 2>nul

if not defined GHUSER (
    echo [ERRO] Login foi feito, mas nao consegui identificar o usuario.
    echo Execute manualmente para testar:
    echo "%GHEXE%" api user --jq .login
    goto :ERRO
)

echo [OK] Conta GitHub: !GHUSER!
>>"%LOG%" echo Usuario: !GHUSER!
echo.

rem ============================================================
rem GITIGNORE
rem ============================================================
call :IGNORE ".env"
call :IGNORE ".godot/"
call :IGNORE ".godot_ai_venv/"
call :IGNORE ".github_tools/"
call :IGNORE "__pycache__/"
call :IGNORE "*.pyc"
call :IGNORE "*.bak_openai_assistant"
call :IGNORE "Godot_OpenAI_Assistant.zip"
call :IGNORE "Godot_OpenAI_Assistant/"

echo [OK] .gitignore protegido.
echo.

rem ============================================================
rem REPOSITORIO LOCAL
rem ============================================================
if not exist ".git" (
    "%GITEXE%" init
    if errorlevel 1 goto :GIT_ERRO
)

"%GITEXE%" branch -M main >nul 2>nul

"%GITEXE%" rm -r --cached --ignore-unmatch ".env" ".godot" ".godot_ai_venv" ".github_tools" "__pycache__" "Godot_OpenAI_Assistant.zip" "Godot_OpenAI_Assistant" >nul 2>nul

set "GITNAME="
set "GITEMAIL="
for /f "delims=" %%A in ('"%GITEXE%" config user.name 2^>nul') do set "GITNAME=%%A"
for /f "delims=" %%A in ('"%GITEXE%" config user.email 2^>nul') do set "GITEMAIL=%%A"

if not defined GITNAME "%GITEXE%" config user.name "!GHUSER!"
if not defined GITEMAIL (
    if defined GHID (
        "%GITEXE%" config user.email "!GHID!+!GHUSER!@users.noreply.github.com"
    ) else (
        "%GITEXE%" config user.email "!GHUSER!@users.noreply.github.com"
    )
)

echo Adicionando arquivos...
"%GITEXE%" add .
if errorlevel 1 goto :GIT_ERRO

"%GITEXE%" reset -- ".env" >nul 2>nul

"%GITEXE%" diff --cached --quiet
if errorlevel 1 (
    set "MSG="
    set /p "MSG=Mensagem do commit [Atualizacao do projeto Godot]: "
    if not defined MSG set "MSG=Atualizacao do projeto Godot"

    "%GITEXE%" commit -m "!MSG!"
    if errorlevel 1 goto :GIT_ERRO
) else (
    echo [OK] Nenhuma alteracao nova para commit.
)

echo.

rem ============================================================
rem CRIAR / CONECTAR REPOSITORIO
rem ============================================================
set "ORIGIN="
for /f "delims=" %%A in ('"%GITEXE%" remote get-url origin 2^>nul') do set "ORIGIN=%%A"

if not defined ORIGIN (
    for %%I in ("%CD%") do set "DEFAULT_REPO=%%~nxI"

    echo ============================================================
    echo                  REPOSITORIO GITHUB
    echo ============================================================
    echo.
    set "REPONAME="
    set /p "REPONAME=Nome do repositorio [!DEFAULT_REPO!]: "
    if not defined REPONAME set "REPONAME=!DEFAULT_REPO!"

    echo.
    echo [1] Privado (recomendado)
    echo [2] Publico
    choice /C 12 /N /M "Escolha 1 ou 2: "

    if errorlevel 2 (
        set "VISIBILITY=public"
    ) else (
        set "VISIBILITY=private"
    )

    echo.
    echo Verificando !GHUSER!/!REPONAME!...

    "%GHEXE%" repo view "!GHUSER!/!REPONAME!" >nul 2>nul
    if not errorlevel 1 (
        echo [OK] Repositorio ja existe. Conectando...
        "%GITEXE%" remote add origin "https://github.com/!GHUSER!/!REPONAME!.git"
        if errorlevel 1 goto :GIT_ERRO
    ) else (
        echo Criando repositorio !VISIBILITY!...
        "%GHEXE%" repo create "!REPONAME!" --!VISIBILITY! --source "." --remote origin
        if errorlevel 1 (
            echo [ERRO] Nao consegui criar o repositorio.
            goto :ERRO
        )
    )
)

echo.
echo Enviando para o GitHub...
"%GITEXE%" push -u origin main
if errorlevel 1 goto :GIT_ERRO

set "FINALREMOTE="
for /f "delims=" %%A in ('"%GITEXE%" remote get-url origin') do set "FINALREMOTE=%%A"
set "WEBURL=!FINALREMOTE:.git=!"

echo.
echo ============================================================
echo                         PRONTO!
echo ============================================================
echo.
echo Conta: !GHUSER!
echo Projeto enviado para:
echo !WEBURL!
echo.
echo O .env e a pasta .github_tools NAO foram enviados.
echo.
>>"%LOG%" echo SUCESSO: !WEBURL!
start "" "!WEBURL!"
goto :FIM

:IGNORE
if not exist ".gitignore" type nul > ".gitignore"
findstr /X /C:"%~1" ".gitignore" >nul 2>nul
if errorlevel 1 >>".gitignore" echo %~1
exit /b

:GIT_ERRO
echo.
echo [ERRO] O Git encontrou um problema.
goto :ERRO

:ERRO
echo.
echo ============================================================
echo O processo parou.
echo Veja o erro acima.
echo Log: %LOG%
echo ============================================================
echo.
goto :EOF

:FIM
echo.
echo Concluido. Pode fechar esta janela quando quiser.
echo Nas proximas vezes use este mesmo BAT para atualizar o projeto.
echo.
goto :EOF
