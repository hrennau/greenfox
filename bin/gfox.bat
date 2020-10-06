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
set PARAMS=
set CCFILTER=
set FNFILTER=
set schema=
set domain=

:NEXTPAR
set name=%~1
set char1=%name:~0,1%

rem if this is a parameter name, remove quote (by re-assigning to %~1)
rem the quote was needed for argument expressions containing <
set name=%~1
if "%name%"=="" goto :ENDPAR

shift
set value=%~1

if        "%name%"=="-1" (set RTYPE=sum1
) else if "%name%"=="-2" (set RTYPE=sum2
) else if "%name%"=="-3" (set RTYPE=sum3
) else if "%name%"=="-r" (set RTYPE=red
) else if "%name%"=="-w" (set RTYPE=white
) else if "%name%"=="-t" (set RTYPE=!VALUE!
   shift
) else if "%name%"=="-p" (
   if "%PARAMS%"=="" (set PARAMS=!VALUE!) else (
       set EDITED=!VALUE!
       rem set PARAMS=!PARAMS!;!VALUE!
       set PARAMS=!PARAMS!;!EDITED!
   )
   shift
) else if "%name%"=="-C" (
   set CCFILTER=!VALUE!
   shift
) else if "%name%"=="-R" (
   set FNFILTER=!VALUE!
   shift
 ) else if "%char1%"=="-" (
   echo Unknown option: %name%
   echo Supported options:
   echo    -1 -2 -3 -r -w                 # Select report type
   echo    -t reportType                  # Set report type to specific type
   echo    -p "name:value"                # Set schema parameter - multiple use allowed
   echo    -C "foo* *bar ~foo*bar ~*peng" # Filter constraint components - all "foo* or *bar, except foo*bar or *peng"   
   echo    -R "airport-* ~*.fra.*"        # Filter resources - all "airport-*, except *.fra.*"   
   echo Aborted.
   exit /b
) else (
    if "!schema!"=="" (
        set schema=!name!
    ) else if "!domain!"=="" (
        set domain=!name!
    ) else (
        echo Usage: gfox schema [domain] [-1 -2 -3 -r -w] [-t type] [-p paramBinding] [-C constraintTypes] [-R resourceNames]
        echo.
        echo Third argument not allowed.
        exit /b    
    )
)

if "%value%"=="" goto :ENDPAR

goto :NEXTPAR
:ENDPAR

if        "%RTYPE%"=="white"    (rem
) else if "%RTYPE%"=="red"      (rem
) else if "%RTYPE%"=="sum1"     (rem
) else if "%RTYPE%"=="sum2"     (rem
) else if "%RTYPE%"=="sum3"     (rem
) else if "%RTYPE%"=="wresults" (rem
) else if "%RTYPE%"=="rresults" (rem
) else (
     echo "Unknown report type: %RTYPE%
     echo Aborted.
     exit /b
)

if "%schema%"=="?" (
    echo.
    echo Usage: gfox schema [domain] [-1 -2 -3 -r -w] [-t type] [-p paramBinding] [-C constraintTypes] [-R resourceNames]
    echo.
    echo Options and arguments may be mixed.
    echo.
    echo schema: Greenfox schema file; relative or absolute path
    echo domain: Validation root resource; relative or absolute path
    echo.
    echo -1      : report type = sum1
    echo -2      : report type = sum2
    echo -3      : report type = sum3
    echo -r      : report type = red
    echo -w      : report type = white
    echo -t reportType       : the report type; one of: sum1 sum2 sum3 red white wresults rresults
    echo -p foo:bar          : parameter with name foo and value bar
    echo -C constraintTypes  : filter by constraint type
    echo -R resourceNames    : filter by resource name
    echo.
    echo The values of -C and -R are interpreted as "name filter"; rules:
    echo - value = whitespace-separated list of items
    echo - items without leading ~ are positive filters, selecting what is included; they are ORed
    echo - items with leading ~ are negative filters, selecting what is excluded; they are ANDed
    echo - all items are evaluated case-insensitively
    echo.
    echo Example:
    echo   -C "*closed *count* ~value* ~target*"
    echo   MEANS: All constraints *closed* or *count*, but excluding value* and excluding target*
    echo.
    echo Example:
    echo   -R "~.dtd"
    echo   MEANS: All resources except *.dtd
    echo.
    echo Example:
    echo   -R "airport-* airpots-* ~*.xml ~*txt"
    echo   MEANS: All resources airport-* or airports-*, yet excluding *.xml and *.txt
    echo.
    echo.
    exit /b
)

set RTYPE_PARAM=
if not "%RTYPE%"=="" (set RTYPE_PARAM=,reportType=%RTYPE%)
if not "%PARAMS%"=="" (set PARAMS_PARAM=,params=%PARAMS%)
if not "%CCFILTER%"=="" (set CCFILTER_PARAM=,ccfilter=%CCFILTER%)
if not "%FNFILTER%"=="" (set FNFILTER_PARAM=,fnfilter=%FNFILTER%)

set DOMAIN_PARAM=
if not "%DOMAIN%"=="" (set DOMAIN_PARAM=,domain=%DOMAIN%)
basex -b "request=val?gfox=%schema%%RTYPE_PARAM%%DOMAIN_PARAM%%PARAMS_PARAM%%CCFILTER_PARAM%%FNFILTER_PARAM%" %HERE%/greenfox.xq
