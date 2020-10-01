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
set RTYPE=sum2

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

if "%name%"=="-a" (set RTYPE=sum1
) else if "%name%"=="-b" (set RTYPE=sum2
) else if "%name%"=="-c" (set RTYPE=sum3
) else if "%name%"=="-r" (set RTYPE=red
) else if "%name%"=="-w" (set RTYPE=white
) else if "%name%"=="-t" (set RTYPE=!VALUE!
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

if "%RTYPE%"=="white" (rem        
) else if "%RTYPE%"=="red" (rem
) else if "%RTYPE%"=="sum1" (rem
) else if "%RTYPE%"=="sum2" (rem 
) else if "%RTYPE%"=="sum3" (rem        
) else if "%RTYPE%"=="wresults" (rem
) else if "%RTYPE%"=="rresults" (rem
) else (
     echo "Unknown report type: %RTYPE%
     echo Aborted.
     exit /b
)

set schema=%name%
shift
set domain=%1

if "%schema%"=="?" (
    echo.
    echo Usage: greenfox [-a -b -c -r -w] [-t type] schema [domain]
    echo.
    echo schema: Greenfox schema file; relative or absolute path
    echo domain: Validation root resource; relative or absolute path
    echo.
    echo -a      : report type = sum1
    echo -b      : report type = sum2
    echo -c      : report type = sum3        
    echo -r      : report type = red
    echo -w      : report type = white        
    echo -t      : the report type; one of: sum1 sum2 sum3 red white wresults rresults 
    echo.
    exit /b
)
set RTYPE_PARAM=
if not "%RTYPE%"=="" (set RTYPE_PARAM=,reportType=%RTYPE%)
set DOMAIN_PARAM=
if not "%DOMAIN%"=="" (set DOMAIN_PARAM=,domain=%DOMAIN%)
basex -b "request=val?gfox=%schema%%RTYPE_PARAM%%DOMAIN_PARAM%" %HERE%/greenfox.xq
