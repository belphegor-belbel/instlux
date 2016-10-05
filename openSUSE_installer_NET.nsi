; openSUSE installer instlux-ng NSIS script
; -----------------------------------------------------------------------------

!include "MUI.nsh"
!include "x64.nsh"
!include "LogicLib.nsh"

; -----------------------------------------------------------------------------
; variables

Var hwnd
Var distribution
Var architecture
Var bcdedit
Var instsource

; -----------------------------------------------------------------------------
; General settings

Name "openSUSE installer"
Caption "openSUSE installer"
OutFile "openSUSE_installer_NET.exe"
ShowInstDetails "nevershow"
ShowUninstDetails "nevershow"
AllowRootDirInstall true
InstallDir "C:\openSUSE"
XPStyle on

!define MUI_ICON "opensuse.ico"
!define MUI_UNICON "opensuse.ico"

!define MUI_WELCOMEPAGE_TITLE_3LINES
!define MUI_FINISHPAGE_TITLE_3LINES

; -----------------------------------------------------------------------------
; pages

!insertmacro MUI_PAGE_WELCOME
Page custom "ShowDistributionSelection" "LeaveDistributionSelection"
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

; -----------------------------------------------------------------------------
; languages and translation macros
; see: http://nsis.sourceforge.net/Creating_language_files_and_integrating_with_MUI

!macro LANG_LOAD LANGLOAD
  !insertmacro MUI_LANGUAGE "${LANGLOAD}"
  !verbose 1
  !include "lang\${LANGLOAD}.nsh"
  !verbose 4
  # BrandingText "$(STRING_BRANDING)" ; example usage
  !undef LANG
!macroend

!macro LANG_STRING NAME VALUE
  LangString "${NAME}" "${LANG_${LANG}}" "${VALUE}"
!macroend

!macro LANG_UNSTRING NAME VALUE
  !insertmacro LANG_STRING "un.${NAME}" "${VALUE}"
!macroend

; first language is the default language
!insertmacro LANG_LOAD "English"
!insertmacro LANG_LOAD "French"
!insertmacro LANG_LOAD "German"
!insertmacro LANG_LOAD "Spanish"
!insertmacro LANG_LOAD "SpanishInternational"
!insertmacro LANG_LOAD "SimpChinese"
!insertmacro LANG_LOAD "TradChinese"
!insertmacro LANG_LOAD "Japanese"
!insertmacro LANG_LOAD "Korean"
!insertmacro LANG_LOAD "Italian"
!insertmacro LANG_LOAD "Dutch"
!insertmacro LANG_LOAD "Danish"
!insertmacro LANG_LOAD "Swedish"
!insertmacro LANG_LOAD "Norwegian"
!insertmacro LANG_LOAD "NorwegianNynorsk"
!insertmacro LANG_LOAD "Finnish"
!insertmacro LANG_LOAD "Greek"
!insertmacro LANG_LOAD "Russian"
!insertmacro LANG_LOAD "Portuguese"
!insertmacro LANG_LOAD "PortugueseBR"
!insertmacro LANG_LOAD "Polish"

; -----------------------------------------------------------------------------
; initialize function

Function .onInit
  InitPluginsDir
  File /oname=$PLUGINSDIR\DistributionSelection.ini "DistributionSelection.ini"

  ; if running in X64, bcdedit is in %windir%\Sysnative.
  ${If} ${RunningX64}
    ExpandEnvStrings $bcdedit "%windir%\Sysnative\bcdedit"
  ${Else}
    StrCpy $bcdedit "bcdedit"
  ${EndIf}

  Call CheckBootloader
  Pop $R0

  ${If} $R0 == 'vista'
    ; check whether UEFI boot mode is activated or not
    ExpandEnvStrings $0 %COMSPEC%
    nsExec::ExecToStack '"$0" /C "$bcdedit /enum bootmgr | findstr /I ^path | findstr /I \.efi$$"'
    Pop $1
    Pop $1
    StrLen $0 $1
    ${If} $0 > 0
      MessageBox MB_OK|MB_ICONSTOP $(STRING_REFUSE_UEFI)
      Quit
    ${EndIf}
  ${EndIf}

  ${If} $R0 == 'vista'
  ${OrIf} $R0 == 'nt'
    # check administrator privilege
    userInfo::getAccountType
    pop $0
    ${If} $0 != "Admin"
      MessageBox MB_OK $(STRING_NOTADMIN)
      Quit
    ${Endif}
  ${EndIf}

  !define MUI_LANGDLL_WINDOWTITLE $(STRING_LANGDLL_WINDOWTITLE)
  !define MUI_LANGDLL_INFO $(STRING_LANGDLL_INFO)

  !insertmacro MUI_LANGDLL_DISPLAY

  !undef MUI_LANGDLL_WINDOWTITLE
  !undef MUI_LANGDLL_INFO
FunctionEnd

; -----------------------------------------------------------------------------
; display distribution

Section "Display distribution selection"
  SectionIn RO                  ; always show
SectionEnd

Function "ShowDistributionSelection"
  ; test 64bit
  test64::get_arch

  WriteIniStr "$PLUGINSDIR\DistributionSelection.ini" \
    "Field 1" "Text" $(STRING_VERSION)
  WriteIniStr "$PLUGINSDIR\DistributionSelection.ini" \
    "Field 3" "Text" $(STRING_ARCHITECTURE)

  ${If} $0 == "x86_64"
    ; when x86_64 is supported..
    ; set latest stable version
    WriteIniStr "$PLUGINSDIR\DistributionSelection.ini" \
      "Field 2" "State" "openSUSE Leap 42.1"
    ; set currently supported versions
    WriteIniStr "$PLUGINSDIR\DistributionSelection.ini" \
      "Field 2" "ListItems" \
      "openSUSE Leap 42.2|openSUSE Leap 42.1|openSUSE 13.2|openSUSE Tumbleweed"
  ${Else}
    ; when x86_64 is not supported..
    ; set latest stable version
    WriteIniStr "$PLUGINSDIR\DistributionSelection.ini" \
      "Field 2" "State" "openSUSE 13.2"
    ; set currently supported versions
    WriteIniStr "$PLUGINSDIR\DistributionSelection.ini" \
      "Field 2" "ListItems" \
      "openSUSE 13.2|openSUSE Tumbleweed"

    ; remove x86_64
    WriteIniStr "$PLUGINSDIR\DistributionSelection.ini" \
      "Field 4" "State" "i386"
    WriteIniStr "$PLUGINSDIR\DistributionSelection.ini" \
      "Field 4" "ListItems" "i386"
  ${EndIf}

  ; show dialog
  InstallOptions::initDialog /NOUNLOAD "$PLUGINSDIR\DistributionSelection.ini"
  Pop $hwnd

  !insertmacro MUI_HEADER_TEXT $(STRING_SELECTDIST_TITLE) $(STRING_SELECTDIST_TEXT)

  InstallOptions::show
FunctionEnd ; "ShowDistributionSelection"

Function "LeaveDistributionSelection"
  ReadIniStr $distribution "$PLUGINSDIR\DistributionSelection.ini" \
    "Field 2" "State"
  ReadIniStr $architecture "$PLUGINSDIR\DistributionSelection.ini" \
    "Field 4" "State"

  StrCpy $0 $distribution 14
  ${If} $0 == "openSUSE Leap "
    ${If} $architecture != "x86_64"
      MessageBox MB_OK|MB_ICONSTOP $(STRING_LEAP_64BITONLY)
      Abort
    ${EndIf}
  ${EndIf}

  MessageBox MB_OKCANCEL|MB_ICONQUESTION|MB_DEFBUTTON2 $(STRING_STARTCONFIRM) \
    IDOK leavedist_ok
  Abort
leavedist_ok:

FunctionEnd ; "LeaveDistributionSelection"

; -----------------------------------------------------------------------------
; check bootloader

!macro CheckBootloaderMacro un
Function ${un}CheckBootloader
  Push $R0
  Push $R1
  ClearErrors

  ; check if Windows NT family
  ReadRegStr $R0 HKLM \
  "SOFTWARE\Microsoft\Windows NT\CurrentVersion" CurrentVersion

  IfErrors 0 lbl_winnt

  ; Windows Me or earlier
  StrCpy $R0 '9x'
  Goto lbl_done

lbl_winnt:

  ; Windows NT or later
  StrCpy $R1 $R0 1

  ${If} $R1 == '3'
  ${OrIf} $R1 == '4'
  ${OrIf} $R1 == '5'
    StrCpy $R0 'nt'
  ${Else}
    StrCpy $R0 'vista'
  ${EndIf}

lbl_done:

  Pop $R1
  Exch $R0
FunctionEnd ; "CheckBootloader"
!macroend ; "CheckBootloaderMacro"

!insertmacro CheckBootloaderMacro ""
!insertmacro CheckBootloaderMacro "un."

; -----------------------------------------------------------------------------
; install section

Section "Install"
  SectionIn RO

  SetOutPath $INSTDIR

  ; download kernel and initrd
  StrCpy $0 $distribution 14
  ${If} $distribution == "openSUSE Tumbleweed"
    ; openSUSE Tumbleweed
    StrCpy $R1 "http://download.opensuse.org/tumbleweed/repo/oss/boot/$architecture/loader/linux"
    StrCpy $R2 "http://download.opensuse.org/tumbleweed/repo/oss/boot/$architecture/loader/initrd"
    StrCpy $instsource "http://download.opensuse.org/tumbleweed/repo/oss/"
  ${ElseIf} $0 == "openSUSE Leap "
    ; openSUSE Leap
    StrCpy $R3 $distribution 255 14
    StrCpy $R1 "http://download.opensuse.org/distribution/leap/$R3/repo/oss/boot/$architecture/loader/linux"
    StrCpy $R2 "http://download.opensuse.org/distribution/leap/$R3/repo/oss/boot/$architecture/loader/initrd"
    StrCpy $instsource "http://download.opensuse.org/distribution/leap/$R3/repo/oss/"
  ${Else}
    ; openSUSE (before Leap)
    StrCpy $R3 $distribution 255 9
    StrCpy $R1 "http://download.opensuse.org/distribution/$R3/repo/oss/boot/$architecture/loader/linux"
    StrCpy $R2 "http://download.opensuse.org/distribution/$R3/repo/oss/boot/$architecture/loader/initrd"
    StrCpy $instsource "http://download.opensuse.org/distribution/$R3/repo/oss/"
  ${EndIf}

  NSISdl::download $R1 "$INSTDIR\linux"
  Pop $0
  ${If} $0 == "cancel"
    Abort
  ${ElseIf} $0 != "success"
    MessageBox MB_OK|MB_ICONSTOP $(STRING_DOWNLOADERROR_R1)
    Abort
  ${EndIf}

  NSISdl::download $R2 "$INSTDIR\initrd"
  Pop $0
  ${If} $0 == "cancel"
    Abort
  ${ElseIf} $0 != "success"
    MessageBox MB_OK|MB_ICONSTOP $(STRING_DOWNLOADERROR_R2)
    Abort
  ${EndIf}

  ; check bootloader and modify it accordingly
  Call CheckBootloader
  Pop $R0

  ${If} $R0 == '9x'
    # --------------------------------- Windows 9x style bootloader
    # Write uninstaller before doing anything else...
    WriteUninstaller "$SMSTARTUP\openSUSE-uninst.exe"

    File /oname=C:\grub.exe "grub.exe"
    Rename "C:\config.sys" "C:\config-bak.sys"
    FileOpen $R1 "C:\config.sys" w
    FileWrite $R1 "[menu]$\r$\n"
    FileWrite $R1 "menuitem=Windows , Start Windows$\r$\n"
    FileWrite $R1 "menuitem=openSUSE installer, openSUSE installer$\r$\n$\r$\n"
    FileWrite $R1 "[Windows]$\r$\n"
    FileWrite $R1 "shell=io.sys$\r$\n$\r$\n"
    FileWrite $R1 "[openSUSE installer]$\r$\n"
    FileWrite $R1 "install=grub.exe"
    FileSeek $R1 0 END
    FileClose $R1
  ${ElseIf} $R0 == 'nt'
    # --------------------------------- Windows NT style bootloader
    # Write uninstaller before doing anything else...
    WriteUninstaller "$SMSTARTUP\openSUSE-uninst.exe"

    ; save timeout value
    ReadINIStr $0 "C:\boot.ini" "boot loader" "timeout"
    WriteINIStr "C:\boot.save" "boot loader" "timeout" $0
    ; write new values
    SetFileAttributes "C:\boot.ini" NORMAL
    WriteINIStr "C:\boot.ini" "boot loader" "timeout" "30"
    WriteINIStr "C:\boot.ini" "operating systems" "C:\grldr" '"openSUSE installer"'
    SetFileAttributes "C:\boot.ini" SYSTEM|HIDDEN

    File /oname=C:\grldr "grldr"
    File /oname=C:\grldr.mbr "grldr.mbr"
  ${ElseIf} $R0 == 'vista'
    # --------------------------------- Windows Vista style bootloader
    ; if running in X64, bcdedit is in %windir%\Sysnative.
    ${If} ${RunningX64}
      ExpandEnvStrings $BcdEdit "%windir%\Sysnative\bcdedit"
    ${Else}
      StrCpy $BcdEdit "bcdedit"
    ${EndIf}

    # Write uninstaller before doing anything else,
    # but uninstaller is not installed to $SMSTARTUP directly;
    # this is due to UAC ("RunAs" required).
    WriteUninstaller "C:\openSUSE-uninst.exe"
    CreateShortcut "$SMSTARTUP\openSUSE setup uninstaller.lnk" \
      "$SYSDIR\WindowsPowerShell\v1.0\PowerShell.exe" \
      "Start-Process C:\openSUSE-uninst.exe -Verb RunAs"

    # check registry if boot ID was already generated or not
    ReadRegStr $0 HKLM "Software\openSUSE\openSUSE-Installer Loader" "bootmgr"
    ${If} $0 == ""
      nsExec::ExecToStack '"$BcdEdit" /create /d "openSUSE installer" /application bootsector'
      Pop $0
      ${If} $0 != 0
        StrCpy $0 bcdedit.exe
        MessageBox MB_OK $(STRING_BCDEDIT_ERROR)
        Quit
      ${Endif}
      Pop $0 ; "The entry {id} was successfully created"

      StrCpy $R1 $0
      StrCpy $R2 0

lblNext:
        IntOp $R2 $R2 + 1
        StrCpy $R4 $R1 1 $R2
        StrCmp $R4 "{" lblID lblNext 

lblID:
        StrCpy $R3 $R1 38 $R2

      ; write boot ID for future use.
      WriteRegStr HKLM "Software\openSUSE\openSUSE-Installer Loader" "bootmgr" "$R3"
    ${Else}
      StrCpy $R3 $0
    ${Endif}
    nsExec::Exec '"$BcdEdit" /set $R3 device partition=C:'
    nsExec::Exec '"$BcdEdit" /set $R3 path \grldr.mbr'
    nsExec::Exec '"$BcdEdit" /timeout 30'
    nsExec::Exec '"$BcdEdit" /displayorder $R3 /addlast'

    File /oname=C:\grldr "grldr"
    File /oname=C:\grldr.mbr "grldr.mbr"
  ${Else} ; bootloader
    ; not supported version
    MessageBox MB_OK $(STRING_NOTSUPPORTED_OS)
    Quit
  ${EndIf}

  FileOpen $R3 "C:\openSUSE_hitme.txt" a 
  FileWrite $R3 "This file was created by openSUSE setup installer."
  FileSeek $R3 0 END
  FileClose $R3

  # language name to ISO639-1
  ${If} $LANGUAGE == ${LANG_ENGLISH}
    StrCpy $R4 "en"
  ${ElseIf} $LANGUAGE == ${LANG_FRENCH}
    StrCpy $R4 "fr"
  ${ElseIf} $LANGUAGE == ${LANG_GERMAN}
    StrCpy $R4 "de"
  ${ElseIf} $LANGUAGE == ${LANG_SPANISH}
    StrCpy $R4 "es"
  ${ElseIf} $LANGUAGE == ${LANG_SIMPCHINESE}
    StrCpy $R4 "zh-cn"
  ${ElseIf} $LANGUAGE == ${LANG_TRADCHINESE}
    StrCpy $R4 "zh-tw"
  ${ElseIf} $LANGUAGE == ${LANG_JAPANESE}
    StrCpy $R4 "ja"
  ${ElseIf} $LANGUAGE == ${LANG_KOREAN}
    StrCpy $R4 "kr"
  ${ElseIf} $LANGUAGE == ${LANG_ITALIAN}
    StrCpy $R4 "it"
  ${ElseIf} $LANGUAGE == ${LANG_DUTCH}
    StrCpy $R4 "nl"
  ${ElseIf} $LANGUAGE == ${LANG_SWEDISH}
    StrCpy $R4 "sv"
  ${ElseIf} $LANGUAGE == ${LANG_NORWEGIAN}
    StrCpy $R4 "nb"
  ${ElseIf} $LANGUAGE == ${LANG_NORWEGIANNYNORSK}
    StrCpy $R4 "nn"
  ${ElseIf} $LANGUAGE == ${LANG_FINNISH}
    StrCpy $R4 "fi"
  ${ElseIf} $LANGUAGE == ${LANG_GREEK}
    StrCpy $R4 "el"
  ${ElseIf} $LANGUAGE == ${LANG_RUSSIAN}
    StrCpy $R4 "ru"
  ${ElseIf} $LANGUAGE == ${LANG_PORTUGUESE}
    StrCpy $R4 "pt"
  ${ElseIf} $LANGUAGE == ${LANG_PORTUGUESEBR}
    StrCpy $R4 "pt-br"
  ${ElseIf} $LANGUAGE == ${LANG_POLISH}
    StrCpy $R4 "pl"
  ${EndIf}

  # retrieve screen resolution
  System::Call 'user32::GetSystemMetrics(i 0) i .r0'
  System::Call 'user32::GetSystemMetrics(i 1) i .r1'

  # NOTE: 16bit color
  ${If} $0 == 640
    StrCpy $R5 "0x311"
  ${ElseIf} $0 == 800
    StrCpy $R5 "0x314"
  ${ElseIf} $0 == 1024
    StrCpy $R5 "0x317"
  ${ElseIf} $0 == 1280
    StrCpy $R5 "0x31A"
  ${ElseIf} $0 == 1400
    StrCpy $R5 "0x345"
  ${ElseIf} $0 == 1600
    StrCpy $R5 "0x31E"
  ${ElseIf} $0 == 1920
    # 16bit is not available for this resolutions
    StrCpy $R5 "0x37D"
  ${Else}
    # if unknown
    StrCpy $R5 "normal"
  ${EndIf}

  FileOpen $R6 C:\menu.lst a
  FileWrite $R6 "hiddenmenu$\r$\n"
  FileWrite $R6 "timeout 0$\r$\n"

  FileWrite $R6 "title openSUSE installer$\r$\n"
  FileWrite $R6 "find --set-root /openSUSE_hitme.txt$\r$\n"

  FileWrite $R6 "kernel /openSUSE/linux devfs=mount,dall ramdisk_size=65536 install=$instsource server=download.opensuse.org lang=$R4 splash=silent vga=$R5$\r$\n"
  FileWrite $R6 "initrd /openSUSE/initrd$\r$\n"
  FileSeek $R6 0 END
  FileClose $R6

  # uncompress files
  nsExec::Exec '"compact" /u C:\grldr C:\grldr.mbr C:\menu.lst C:\openSUSE\linux C:\openSUSE\initrd'

  SetRebootFlag True
SectionEnd ; "Install"

; -----------------------------------------------------------------------------
; uninstall section

Section "Uninstall"
  ; check bootloader and uninstall accordingly
  Call un.CheckBootloader
  Pop $R0

  ${If} $R0 == '9x'
    Delete /REBOOTOK "C:\grub.exe"
    Delete /REBOOTOK "C:\config.sys"
    Rename "C:\config-bak.sys" "C:\config.sys"

    Delete /REBOOTOK "$SMSTARTUP\openSUSE-uninst.exe"
  ${ElseIf} $R0 == 'nt'
    Delete /REBOOTOK "C:\grldr"
    SetFileAttributes "C:\boot.ini" NORMAL
    DeleteINIStr "C:\boot.ini" "operating systems" "C:\grldr"

    ; restore timeout
    DeleteINIStr "C:\boot.ini" "boot loader" "timeout"
    ReadINIStr $0 "C:\boot.save" "boot loader" "timeout"
    Delete "C:\boot.save"
    WriteINIStr "C:\boot.ini" "boot loader" "timeout" $0
    SetFileAttributes "C:\boot.ini" SYSTEM|HIDDEN

    Delete /REBOOTOK "$SMSTARTUP\openSUSE-uninst.exe"
  ${ElseIf} $R0 == 'vista'
    Delete /REBOOTOK "C:\grldr"

    ; if running in X64, bcdedit is in %windir%\Sysnative.
    ${If} ${RunningX64}
      ExpandEnvStrings $BcdEdit "%windir%\Sysnative\bcdedit"
    ${Else}
      StrCpy $BcdEdit "bcdedit"
    ${EndIf}

    ReadRegStr $0 HKLM "Software\openSUSE\openSUSE-Installer Loader" "bootmgr"
    ${If} $0 != ""
      nsExec::Exec '"$BcdEdit" /delete $0'
      Pop $0
      ${If} $0 != 0
        StrCpy $0 bcdedit.exe
        MessageBox MB_OK '"$BcdEdit" /delete $0 failed'
      ${Endif}
      DeleteRegKey HKLM "Software\openSUSE"
    ${Endif}

    Delete /REBOOTOK "$SMSTARTUP\openSUSE setup uninstaller.lnk"
    Delete /REBOOTOK "C:\openSUSE-uninst.exe"
  ${Else}
    ; not supported version
    MessageBox MB_OK $(STRING_NOTSUPPORTED_OS)
    Quit
  ${EndIf}

  Delete /REBOOTOK "C:\openSUSE\linux"
  Delete /REBOOTOK "C:\openSUSE\initrd"
  RmDir /REBOOTOK /r "C:\openSUSE"
  Delete /REBOOTOK "C:\menu.lst"
  Delete /REBOOTOK "C:\grldr"
  Delete /REBOOTOK "C:\grldr.mbr"
  Delete /REBOOTOK "C:\openSUSE_hitme.txt"
SectionEnd ; "Uninstall"
