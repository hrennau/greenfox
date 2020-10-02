SYSTEM REQUIREMENTS
===================
Java 8 INSTALLED

Please check, e.g. entering on the command-line:
    java -version

(1) Install BaseX
=================
(a) Download from here: https://basex.org/download/
(b) Recommended: for Windows, use .exe, for other platforms: use .zip
(c) Execute installer (.exe) or unzip the zip file
(d) Check command-line interface:
(d1) Start shell
(d2) Enter:
       basex -version
(d3) You should see output starting with lines similar to this:
PS C:\path\to\current\dir> basex -version
BaseX 9.4.3 [Standalone]

(e) Optionally, you may may increase the Heap Space allocated in the start script:
    Edit the line containing "BASEX_JVM", changing the value of -Xmx. Examples:
       Windows:    set BASEX_JVM=-Xmx4g %BASEX_JVM%
       Other:      BASEX_JVM="-Xmx4g $BASEX_JVM"
       
    This change will become necessary if program execution terminates with
    "Out of Memory" or "Java heap space" error
       
(2) Install greenfox
====================
(a) Clone or download from here: https://github.com/hrennau/greenfox
(b) Check command-line interface:
(b1) Start shell
(b2) Enter:
     Windows:
       /path/to/greenfox/bin/gfox.bat /tt/greenfox/declarative-amsterdam-2020/schema/air01.gfox.xml
     Other:
       /path/to/greenfox/bin/gfox /tt/greenfox/declarative-amsterdam-2020/schema/air01.gfox.xml
            
     # Make sure to replace "/path/to" with the path of the root folder of unpacked Greenfox
     
(b3) You should see something similar to this:

=============================================================================
=                                                                           =
=                   W  E  L  C  O  M  E        A  T                         =
=                                                                           =
=     D  E  C  L  A  R  A  T  I  V  E        A  M  S  T  E  R  D  A  M      =
=                                                                           =
=                                 2  0  2  0                                =
=                                                                           =
=============================================================================


G r e e n f o x    r e p o r t    s u m m a r y

greenfox: C:/tt/greenfox/declarative-amsterdam-2020/schema/air01.gfox.xml
domain:   C:/tt/greenfox/declarative-amsterdam-2020/data/air

#red:     0
#green:   10   (2 resources)

-------------------------------------------
| Constraint Comp         | #red | #green |
|-------------------------|------|--------
| FolderContentClosed ... |    0 |      1 |
| FolderContentMemberFile |    0 |      7 |
| FolderContentMinCount . |    0 |      1 |
| TargetCount ........... |    0 |      1 |
-------------------------------------------

(c) Recommended: add the "bin" folder of the Greenfox installation to the PATH variable.
    Afterward, you can call Greenfox without path. Example:
       gfox.bat /tt/greenfox/declarative-amsterdam-2020/schema/air01.gfox.xml

(3) Install Foxpath (optional)
==============================
# Installation of Standalone Foxpath is optional - as Foxpath is integrated into Greenfox
# It will be shown, however, how you can use Foxpath independently of Greenfox;
# if you wish to seize the opportunity and do a few experiments (as will be suggested
# during the tutorial), you need to install Foxpath     
(a) Clone or download from here: https://github.com/hrennau/foxpath
(b) Check command-line interface:
(b1) Start shell
(b2) Enter:
     Windows:
       /path/to/foxpath/bin/fox.bat *
     Others:
       /path/to/foxpath/bin/fox *
            
     # Make sure to replace "/path/to" with the path of the root folder of unpacked Foxpath
(b3) You should see a list of file paths    

(c) Recommended: add the "bin" folder of the Foxpath installation to the PATH variable.
    Afterward, you can call Foxpath without path. Example:
       fox *

