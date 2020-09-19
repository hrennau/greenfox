@echo off
setlocal EnableDelayedExpansion

set XERE=%~dp0
set XERE=%XERE:~0,-1%
set HERE=%XERE:\=/%

:: ====================================================================================
::
::     evaluate options
::
:: ====================================================================================

:: defaults
set RTYPE=
set ISWHITE=

:NEXTPAR
set name=%~1
set char1=%name:~0,1%
if "%char1%" neq "-" goto :ENDPAR

rem if this is a parameter name, remove quote (by re-assigning to %~1)
rem the quote was needed for argument expressions containing <
set name=%~1
shift
set value=%~1

if "%value%"=="" goto :ENDPAR

if "%name%"=="-w" (
   set ISWHITE=Y
) else if "%name%"=="-r" (
   set ISWHITE=N
) else if "%name%"=="-t" (
   set RTYPE=!VALUE!
   shift   
 ) else if "%name%"=="-t" (
   set RTYPE=!VALUE!
   shift   
 ) else (
   echo Unknown option: %name%
   echo Supported options: 
   echo    -r -w   
   echo Aborted.
   exit /b
)
goto :NEXTPAR
:ENDPAR 

if "%RTYPE"=="" (
    if "%ISWHITE%"=="Y" (
        set RTYPE=whiteTree
    ) else if "%RTYPE%"=="w" (
        set RTYPE=whiteTree
    ) else if "%RTYPE%"=="r" (
        set RTYPE=redTree
    ) else (
        echo "Unknown report type: %RTYPE%
        echo Aborted.
        exit /b
    )
)
set schema=%name%
shift
set domain=%1

if "%schema%"=="?" (
    echo.
    echo Usage: greenfox [-f w] schema [domain]
    echo.
    echo schema: Greenfox schema file; relative or absolute path
    echo domain: Validation root resource; relative or absolute path
    echo.
    echo -t      : the report type; w=whiteTree; r=redTree 
    echo.
    exit /b
)
set RTYPE_PARAM=
if not "%RTYPE%"=="" (set RTYPE_PARAM=,reportType=%RTYPE%)
set DOMAIN_PARAM=
if not "%DOMAIN%"=="" (set DOMAIN_PARAM=,domain=%DOMAIN%)
basex -b "request=val?gfox=%schema%%RTYPE_PARAM%%DOMAIN_PARAM%" %HERE%/greenfox.xq
