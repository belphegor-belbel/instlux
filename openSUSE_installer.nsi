; openSUSE installer instlux-ng NSIS script
; -----------------------------------------------------------------------------

!include "MUI.nsh"
!include "x64.nsh"
!include "LogicLib.nsh"
!include "WinVer.nsh"

; -----------------------------------------------------------------------------
; variables

Var hwnd
Var systemDrive
Var distribution
Var architecture
Var environment
Var bcdedit
Var bcdStore
Var instsource
Var mediaVer
Var mediaI386
Var mediaX86_64
Var dirVirt
Var dirVM
Var nameVM
Var memoryVM
Var diskVM
Var switchVM
Var buildNum

; -----------------------------------------------------------------------------
; definitions

!define DISTSELECT_INI "$PLUGINSDIR\DistributionSelection.ini"
!define VIRTSET_INI "$PLUGINSDIR\VirtualMachineSettings.ini"

; -----------------------------------------------------------------------------
; General settings

Name "openSUSE installer"
Caption "openSUSE installer"
BrandingText "openSUSE installer / NSIS version ${NSIS_VERSION}"
OutFile "openSUSE_installer.exe"
ShowInstDetails "nevershow"
ShowUninstDetails "nevershow"
AllowRootDirInstall true
InstallDir "C:\openSUSE"
XPStyle on
SetCompressor /SOLID lzma

!define MUI_ICON "opensuse.ico"
!define MUI_UNICON "opensuse.ico"

!define MUI_WELCOMEPAGE_TITLE_3LINES
!define MUI_FINISHPAGE_TITLE_3LINES

; -----------------------------------------------------------------------------
; pages

!insertmacro MUI_PAGE_WELCOME
Page custom "ShowDistributionSelection" "LeaveDistributionSelection"
Page custom "ShowVirtualMachineSettings" "LeaveVirtualMachineSettings"
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
!insertmacro LANG_LOAD "Lithuanian"
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
; get system memory function

Function "GetSystemMemoryInfo"
  ; check RAM (see http://nsis.sourceforge.net/Docs/System/System.html)
  System::Call "*(i 64,i,l,l,l,l,l,l,l)p.r1"
  System::Call "Kernel32::GlobalMemoryStatusEx(p r1)"
  System::Call "*$1(i.r2, i.r3, l.r4)"
  System::Free $1
  System::Int64Op $4 >> 20 ; (to [MB])
  Pop $4
  StrCpy $R0 1
  ${If} $4 L< $R0
    ; if no memory is detected, try again with "GlobalMemoryStatus"
    System::Call "*(i,i,p,p,p,p,p,p)p.r1"
    System::Call "Kernel32::GlobalMemoryStatus(p r1)"
    System::Call "*$1(i.r2, i.r3, p.r4)"
    System::Free $1
    IntOp $4 $4 >> 20 ; (to [MB])
  ${EndIf}
FunctionEnd ; "GetSystemMemoryInfo"

; -----------------------------------------------------------------------------
; run PowerShell script

!macro RunPowerShellCmdOptions Show CommandLine
  !define execID ${__LINE__}
  InitPluginsDir

  Push $R1
  FileOpen $R1 "$PLUGINSDIR\runpowershell.ps1" w
  FileWrite $R1 "${CommandLine}"
  FileClose $R1
  Pop $R1

  Push $R0
  ${If} ${Show} == 0
    Banner::show /set 76 $(STRING_BANNER_WAITINGTITLE) $(STRING_BANNER_WAITING_TEXT)

    ; if running in X64, powershell(X64) is in $WINDIR\Sysnative.
    ${If} ${RunningX64}
      nsExec::ExecToStack "$\"$WINDIR\Sysnative\WindowsPowerShell\v1.0\PowerShell.exe$\" -InputFormat none -ExecutionPolicy RemoteSigned -File $\"$PLUGINSDIR\runpowershell.ps1$\""
    ${Else}
      nsExec::ExecToStack "$\"$SYSDIR\WindowsPowerShell\v1.0\PowerShell.exe$\" -InputFormat none -ExecutionPolicy RemoteSigned -File $\"$PLUGINSDIR\runpowershell.ps1$\""
    ${EndIf}

    Banner::destroy

    Pop $R0 ; return value
  ${Else}
    Banner::show /set 76 $(STRING_BANNER_WAITINGTITLE) $(STRING_BANNER_WAITING_TEXT)

    ; if running in X64, powershell(X64) is in $WINDIR\Sysnative.
    ${If} ${RunningX64}
      ExecWait "$\"$WINDIR\Sysnative\WindowsPowerShell\v1.0\PowerShell.exe$\" -InputFormat none -ExecutionPolicy RemoteSigned -File $\"$PLUGINSDIR\runpowershell.ps1$\"" $R0
    ${Else}
      ExecWait "$\"$SYSDIR\WindowsPowerShell\v1.0\PowerShell.exe$\" -InputFormat none -ExecutionPolicy RemoteSigned -File $\"$PLUGINSDIR\runpowershell.ps1$\"" $R0
    ${EndIf}

    Banner::destroy
  ${EndIf}
  IntCmp $R0 0 lbl_success_${execID}
  SetErrorLevel 2

lbl_success_${execID}:
  Delete "$PLUGINSDIR\runpowershell.ps1"

  !undef execID
!macroend

!define RunPowerShellCmd `!insertmacro RunPowerShellCmdOptions "0"`
!define RunPowerShellCmdShow `!insertmacro RunPowerShellCmdOptions "1"`

; -----------------------------------------------------------------------------
; initialize function

Function .onInit
  InitPluginsDir
  File /oname=${DISTSELECT_INI} "DistributionSelection.ini"
  File /oname=${VIRTSET_INI} "VirtualMachineSettings.ini"

  ${If} ${IsWinMe}
    MessageBox MB_OK|MB_ICONSTOP $(STRING_WINDOWSME_NOTSUPPORTED)
    Quit
  ${EndIf}

  ExpandEnvStrings $systemDrive "%SYSTEMDRIVE%"
  ${If} $systemDrive == "%SYSTEMDRIVE%"
    ; If Windows 9x, SYSTEMDRIVE environment variable is not set..
    StrCpy $systemDrive "C:"
  ${EndIf}

  ; SetOutPath should be executed before any CMD.exe execution;
  ; CMD.exe may cause error if openSUSE_installer.exe is run in UNC path.
  SetOutPath $INSTDIR

  Call GetSystemMemoryInfo
  StrCpy $R0 768
  ${If} $4 L< $R0
    MessageBox MB_OKCANCEL|MB_ICONEXCLAMATION $(STRING_INSUFFICIENT_MEMORY) \
      IDOK lbl_lowmemoryok
    Quit
lbl_lowmemoryok:
    ExecShell "open" "$(STRING_URL_INSUFFICIENT_MEMORY)"
  ${EndIf}

  ; if running in X64, bcdedit is in %windir%\Sysnative.
  ${If} ${RunningX64}
    ExpandEnvStrings $bcdedit "%windir%\Sysnative\bcdedit"
  ${Else}
    StrCpy $bcdedit "bcdedit"
  ${EndIf}

  ; check bootloader
  Call CheckBootloader
  Pop $R0

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

  ; check media
  ClearErrors
  FileOpen $R0 "$EXEDIR\media.1\products" r
  IfErrors lbl_noproduct 0

  FileRead $R0 $R1
  FileClose $R0

  StrCpy $R2 $R1 255 2 ; remove "/ "

  ; remove after LF
  StrCpy $R3 0
lbl_loopLF:
  IntOp $R3 $R3 + 1
  StrCpy $R4 $R2 1 $R3
  StrCmp $R4 "$\n" lbl_loopexit
  StrCmp $R4 "" lbl_loopexit
  Goto lbl_loopLF
lbl_loopexit:

  StrCpy $mediaVer $R2 $R3

  ; check if i386 exists
  ClearErrors
  FileOpen $R0 "$EXEDIR\boot\i386\loader\linux" r
  IfErrors lbl_noi386 0

  FileClose $R0
  StrCpy $mediaI386 1
  Goto lbl_i386exit
lbl_noi386:
  StrCpy $mediaI386 0
lbl_i386exit:

  ; check if x86_64 exists
  ClearErrors
  FileOpen $R0 "$EXEDIR\boot\x86_64\loader\linux" r
  IfErrors lbl_nox86_64 0

  FileClose $R0
  StrCpy $mediaX86_64 1
  Goto lbl_x86_64exit
lbl_nox86_64:
  StrCpy $mediaX86_64 0
lbl_x86_64exit:

  Goto lbl_productdone
lbl_noproduct:
  StrCpy $mediaVer ""
lbl_productdone:

  !define MUI_LANGDLL_WINDOWTITLE $(STRING_LANGDLL_WINDOWTITLE)
  !define MUI_LANGDLL_INFO $(STRING_LANGDLL_INFO)

  !insertmacro MUI_LANGDLL_DISPLAY

  !undef MUI_LANGDLL_WINDOWTITLE
  !undef MUI_LANGDLL_INFO
FunctionEnd ; ".onInit"

Function un.onInit
  ExpandEnvStrings $systemDrive "%SYSTEMDRIVE%"
  ${If} $systemDrive == "%SYSTEMDRIVE%"
    ; If Windows 9x, SYSTEMDRIVE environment variable is not set..
    StrCpy $systemDrive "C:"
  ${EndIf}
FunctionEnd ; "un.onInit"

; -----------------------------------------------------------------------------
; display distribution

Section "Display distribution selection"
  SectionIn RO                  ; always show
SectionEnd

Function "ShowDistributionSelection"
  ; test 64bit
  test64::get_arch

  WriteIniStr ${DISTSELECT_INI} "Field 1" "Text" $(STRING_VERSION)
  WriteIniStr ${DISTSELECT_INI} "Field 3" "Text" $(STRING_ARCHITECTURE)
  WriteIniStr ${DISTSELECT_INI} "Field 5" "Text" $(STRING_ENVIRONMENT)
  WriteIniStr ${DISTSELECT_INI} "Field 6" "ListItems" \
    "$(STRING_ENVIRONMENTSELECTITEM_DUALBOOT)|$(STRING_ENVIRONMENTSELECTITEM_VIRTUALBOX)|$(STRING_ENVIRONMENTSELECTITEM_HYPERV)|$(STRING_ENVIRONMENTSELECTITEM_LINUXONWINDOWS)"
  WriteIniStr ${DISTSELECT_INI} "Field 7" "State" $(STRING_DISTSELECTIONDESCRIPTION)

  ${If} $0 == "x86_64"
    ; when x86_64 is supported..

    ${If} $mediaVer == ""
    ${OrIf} $mediaX86_64 == "0"
      ; set the latest stable version
      WriteIniStr ${DISTSELECT_INI} "Field 2" "State" "openSUSE Leap 15.3"
      StrCpy $R1 ""
    ${Else}
      ; set the version of this media
      WriteIniStr ${DISTSELECT_INI} \
        "Field 2" "State" "$(STRING_VERSIONOFTHISMEDIA) ($mediaVer)"
      StrCpy $R1 "$(STRING_VERSIONOFTHISMEDIA) ($mediaVer)|"
    ${EndIf}

    ; set currently supported versions
    WriteIniStr ${DISTSELECT_INI} "Field 2" "ListItems" \
      "$R1openSUSE Leap 15.3|openSUSE Leap 15.2|openSUSE Leap 15.1|openSUSE Leap 15.0|openSUSE Tumbleweed|openSUSE Leap 42.3"
  ${Else}
    ; when x86_64 is not supported..

    ${If} $mediaVer == ""
    ${OrIf} $mediaI386 == "0"
      ; set latest stable version
      WriteIniStr ${DISTSELECT_INI} "Field 2" "State" "openSUSE Tumbleweed"
      StrCpy $R1 ""
    ${Else}
      ; set the version of this media
      WriteIniStr ${DISTSELECT_INI} "Field 2" "State" \
        "$(STRING_VERSIONOFTHISMEDIA) ($mediaVer)"
      StrCpy $R1 "$(STRING_VERSIONOFTHISMEDIA) ($mediaVer)|"
    ${EndIf}

    ; set currently supported versions
    WriteIniStr ${DISTSELECT_INI} "Field 2" "ListItems" \
      "$R1openSUSE Tumbleweed"

    ; remove x86_64
    WriteIniStr ${DISTSELECT_INI} "Field 4" "State" "i386"
    WriteIniStr ${DISTSELECT_INI} "Field 4" "ListItems" "i386"
  ${EndIf}

  ${If} $distribution != ""
    WriteIniStr ${DISTSELECT_INI} "Field 2" "State" $distribution
  ${EndIf}
  ${If} $architecture != ""
    WriteIniStr ${DISTSELECT_INI} "Field 4" "State" $architecture
  ${EndIf}
  ${If} $environment != ""
    WriteIniStr ${DISTSELECT_INI} "Field 6" "State" $environment
  ${Else}
    WriteIniStr ${DISTSELECT_INI} "Field 6" "State" \
      "$(STRING_ENVIRONMENTSELECTITEM_DUALBOOT)"
  ${EndIf}

  ; show dialog
  InstallOptions::initDialog /NOUNLOAD ${DISTSELECT_INI}
  Pop $hwnd

  !insertmacro MUI_HEADER_TEXT $(STRING_SELECTDIST_TITLE) $(STRING_SELECTDIST_TEXT)

  InstallOptions::show
FunctionEnd ; "ShowDistributionSelection"

Function "LeaveDistributionSelection"
  ReadIniStr $distribution ${DISTSELECT_INI} "Field 2" "State"
  ReadIniStr $architecture ${DISTSELECT_INI} "Field 4" "State"
  ReadIniStr $environment ${DISTSELECT_INI} "Field 6" "State"

  StrCpy $0 $distribution 14
  ${If} $0 == "openSUSE Leap "
    ${If} $architecture != "x86_64"
      MessageBox MB_OK|MB_ICONSTOP $(STRING_LEAP_64BITONLY)
      Abort
    ${EndIf}
  ${EndIf}

  ${If} $mediaVer != ""
    StrLen $1 $(STRING_VERSIONOFTHISMEDIA)
    StrCpy $0 $distribution $1

    ${If} $0 == $(STRING_VERSIONOFTHISMEDIA)
      ; cannot use local media if virtualized install
      ${If} $environment != $(STRING_ENVIRONMENTSELECTITEM_DUALBOOT)
        MessageBox MB_OK|MB_ICONSTOP $(STRING_CANNOTUSELOCALMEDIAIFVIRTUALIZED)
        Abort
      ${EndIf}

      ${If} $architecture == "i386"
      ${AndIf} $mediaI386 == "0"
        MessageBox MB_OK|MB_ICONSTOP $(STRING_NOTEXISTONMEDIA)
        Abort
      ${EndIf}

      ${If} $architecture == "x86_64"
      ${AndIf} $mediaX86_64 == "0"
        MessageBox MB_OK|MB_ICONSTOP $(STRING_NOTEXISTONMEDIA)
        Abort
      ${EndIf}
    ${EndIf}
  ${EndIf}

  ${If} $environment == $(STRING_ENVIRONMENTSELECTITEM_VIRTUALBOX)
    ; check operating system (Windows XP or later required)
    ClearErrors
    ${IfNot} ${IsNT}
      MessageBox MB_OK|MB_ICONSTOP $(STRING_VIRTUALBOX_OSFAILED)
      Abort
    ${EndIf}
    ${IfNot} ${AtLeastWinXP}
      MessageBox MB_OK|MB_ICONSTOP $(STRING_VIRTUALBOX_OSFAILED)
      Abort
    ${EndIf}

    ; check Internet connectivity
    ; ###TODO###

    ; check memory (2GB or more needed)
    Call GetSystemMemoryInfo
    StrCpy $R0 2048
    ${If} $4 L< $R0
      MessageBox MB_OKCANCEL|MB_ICONEXCLAMATION $(STRING_INSUFFICIENT_MEMORY) \
        IDOK lbl_lowmemoryokvbox
      Abort
lbl_lowmemoryokvbox:
      ExecShell "open" "$(STRING_URL_INSUFFICIENT_MEMORY)"
    ${EndIf}

    ; check GUI (VirtualBox cannot support Server Core)
    IfFileExists "$WINDIR\explorer.exe" lbl_notservercore
    MessageBox MB_OK|MB_ICONSTOP $(STRING_SERVERCOREVIRTUALBOX)
    Abort
lbl_notservercore:

    ; check free storage (8GB or more needed)
    ; ###TODO###

    ; check powershell (required for later procedure)
    IfFileExists "$SYSDIR\WindowsPowerShell\v1.0\PowerShell.exe" lbl_powershellvbox
    MessageBox MB_OK|MB_ICONSTOP $(STRING_NOPOWERSHELLVIRTUALBOX)
    Abort
lbl_powershellvbox:

    ; read registry whether VirtualBox is installed or not
    ReadRegStr $0 HKCR "progId_VirtualBox.Shell.vbox\shell\open\command" ""
    ${If} $0 == ""
      ; VirtualBox is not installed; download and install.
      MessageBox MB_OKCANCEL|MB_ICONQUESTION \
        $(STRING_VIRTUALBOXINSTALLATIONCONFIRM) \
          IDOK lbl_installvbox
          Abort
lbl_installvbox:
      ; check the latest version
      ; (NSISdl cannot be used because it does not support HTTPS...)
      StrCpy $R2 "https://update.virtualbox.org/query.php?platform=WINDOWS_64BITS_GENERIC&version=1.0.0"
      ${RunPowerShellCmd} "(new-object System.Net.WebClient).Downloadfile($\"$R2$\", $\"$TEMP\vbox-latest.txt$\")"
      Pop $0
      ${IfNot} $0 == ""
        StrCpy $R1 $R2
        MessageBox MB_OK|MB_ICONSTOP "ver $(STRING_DOWNLOADERROR_R1)"
        Abort
      ${EndIf}

      FileOpen $R1 "$TEMP\vbox-latest.txt" r
      FileRead $R1 $R2
      FileClose $R1

      StrCpy $1 0
lbl_loopinstallvboxspace:
      StrCpy $2 $R2 1 $1
      IntOp $1 $1 + 1
      StrCmp $2 "" lbl_loopinstallvboxnotspace
      StrCmp $2 " " 0 lbl_loopinstallvboxspace
lbl_loopinstallvboxnotspace:
      StrCpy $2 $R2 1 $1
      IntOp $1 $1 + 1
      StrCmp $2 " " lbl_loopinstallvboxnotspace

      IntOp $1 $1 - 1
      StrCpy $R3 $R2 1024 $1
      Delete "$TEMP\vbox-latest.txt"

      ${RunPowerShellCmdShow} 'Start-BitsTransfer -Source $\"$R3$\" -Destination $\"$TEMP\vbox.exe$\"'

      ExecWait "$\"$TEMP\vbox.exe$\"" $0
      ${IfNot} $0 == "0"
        MessageBox MB_OK|MB_ICONSTOP $(STRING_VIRTUALBOXINSTALLATIONFAILED)
        Abort
      ${EndIf}
      Delete "$\"$TEMP\vbox.exe$\""
    ${EndIf}

    ; read registry again
    ReadRegStr $R2 HKCR "progId_VirtualBox.Shell.vbox\shell\open\command" ""
    ${If} $0 == ""
      ; VirtualBox installation failed; abort.
      MessageBox MB_OK|MB_ICONSTOP $(STRING_VIRTUALBOXINSTALLATIONFAILED)
      Abort
    ${EndIf}

    ; set $dirVirt
    StrCpy $1 $R2 1
    ${If} $1 == "$\""
      StrCpy $R3 1
lbl_loopquote:
      IntOp $R3 $R3 + 1
      StrCpy $R4 $R2 1 $R3
      StrCmp $R4 "$\"" lbl_loopquoteexit
      StrCmp $R4 "" lbl_loopquoteexit
      Goto lbl_loopquote
lbl_loopquoteexit:

      IntOp $R3 $R3 - 1
      StrCpy $dirVirt $R2 $R3 1
    ${Else}
      StrCpy $R3 0
lbl_loopspace:
      IntOp $R3 $R3 + 1
      StrCpy $R4 $R2 1 $R3
      StrCmp $R4 " " lbl_loopspaceexit
      StrCmp $R4 "" lbl_loopspaceexit
      Goto lbl_loopspace
lbl_loopspaceexit:

      StrCpy $dirVirt $R2 $R3 0
    ${EndIf}

    ; remove last "\" and followings
    StrLen $R3 $dirVirt
lbl_loopremove:
    IntOp $R3 $R3 - 1
    StrCpy $R4 $dirVirt 1 $R3
    StrCmp $R4 "\" lbl_loopremoveexit
    StrCmp $R4 "" lbl_loopremoveexit
    Goto lbl_loopremove
lbl_loopremoveexit:

    StrCpy $dirVirt $dirVirt $R3

    ; set $dirVM
    Banner::show /set 76 $(STRING_BANNER_WAITINGTITLE) $(STRING_BANNER_WAITING_TEXT)
    nsExec::Exec "cmd /C $\"$dirVirt\VBoxManage.exe$\" list systemproperties > $TEMP\vbox_system_prop.txt"
    FileOpen $R1 "$TEMP\vbox_system_prop.txt" r
    Pop $0
lbl_loopreadvboxprop:
    FileRead $R1 $R2
    StrCmp $R2 "" lbl_loopreadvboxpropexit
    StrCpy $R3 $R2 23 0
    StrCmp $R3 "Default machine folder:" lbl_loopreadvboxpropexit
    Goto lbl_loopreadvboxprop
lbl_loopreadvboxpropexit:
    Banner::destroy

    ${If} $R3 == "Default machine folder:"
      StrCpy $R4 23
lbl_loopvboxpropspace:
      IntOp $R4 $R4 + 1
      StrCpy $R5 $R2 1 $R4
      StrCmp $R5 " " lbl_loopvboxpropspace
      StrCmp $R5 "\t" lbl_loopvboxpropspace

      StrCpy $dirVM $R2 1024 $R4

      StrLen $R4 $dirVM
lbl_loopvboxpropcrlf:
      IntOp $R4 $R4 - 1
      StrCpy $R5 $dirVM 1 $R4
      StrCmp $R5 "$\r" lbl_loopvboxpropcrlf
      StrCmp $R5 "$\n" lbl_loopvboxpropcrlf

      IntOp $R4 $R4 + 1
      StrCpy $dirVM $dirVM $R4 0
    ${Else}
      MessageBox MB_OK|MB_ICONSTOP $(STRING_VIRTUALBOXINSTALLATIONFAILED)
      Abort
    ${EndIf}

    FileClose $R1
    Delete "$TEMP\vbox_system_prop.txt"

    CreateDirectory $dirVM
  ${ElseIf} $environment == $(STRING_ENVIRONMENTSELECTITEM_HYPERV)
    ; check operating system (Windows 8/Server 2012 or later required)
    ClearErrors
    ${IfNot} ${IsNT}
      MessageBox MB_OK|MB_ICONSTOP $(STRING_HYPERV_OSFAILED)
      Abort
    ${EndIf}
    ${IfNot} ${AtLeastWin8}
      MessageBox MB_OK|MB_ICONSTOP $(STRING_HYPERV_OSFAILED)
      Abort
    ${EndIf}

    ; check Internet connectivity
    ; ###TODO###

    ; check memory (2GB or more needed)
    Call GetSystemMemoryInfo
    StrCpy $R0 2048
    ${If} $4 L< $R0
      MessageBox MB_OKCANCEL|MB_ICONEXCLAMATION $(STRING_INSUFFICIENT_MEMORY) \
        IDOK lbl_lowmemoryokhyperv
      Abort
lbl_lowmemoryokhyperv:
      ExecShell "open" "$(STRING_URL_INSUFFICIENT_MEMORY)"
    ${EndIf}

    ; check free storage (8GB or more needed)
    ; ###TODO###

    ; check powershell (required for later procedure)
    IfFileExists "$SYSDIR\WindowsPowerShell\v1.0\PowerShell.exe" lbl_powershellhyperv
    MessageBox MB_OK|MB_ICONSTOP $(STRING_NOPOWERSHELLHYPERV)
    Abort
lbl_powershellhyperv:

    ${If} ${IsServerOS}
      ; check whether Hyper-V (for server OS) is installed or not
      ${RunPowerShellCmd} "Import-Module ServerManager; (Get-WindowsFeature Hyper-V).Installed"
    ${Else}
      ; check whether Hyper-V (for client OS) is installed or not
      ${RunPowerShellCmd} "(Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All).State -and (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Hypervisor).State -and (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Services).State"
    ${EndIf}
    Pop $0
    ${If} $0 == "False$\r$\n"
    ${OrIf} $0 == "Disabled$\r$\n"
      MessageBox MB_OKCANCEL|MB_ICONQUESTION \
        $(STRING_HYPERVINSTALLATIONCONFIRM) \
          IDOK lbl_installhyperv
          Abort

lbl_installhyperv:
      ; check CPU support (Virtualization)
      ${RunPowerShellCmd} "(Get-WmiObject WIN32_Processor).VirtualizationFirmwareEnabled"
      Pop $0
      ${If} $0 == "False$\r$\n"
        MessageBox MB_OK|MB_ICONSTOP $(STRING_HYPERV_VTDISABLED)
        Abort
      ${ElseIf} $0 != "True$\r$\n"
        MessageBox MB_OK|MB_ICONSTOP $(STRING_HYPERV_VTCHECKFAILED)
        Abort
      ${EndIf}

      ; check CPU support (Second Level Address Translation)
      ${RunPowerShellCmd} "(Get-WmiObject WIN32_Processor).SecondLevelAddressTranslationExtensions"
      Pop $0
      ${If} $0 == "False$\r$\n"
        MessageBox MB_OK|MB_ICONSTOP $(STRING_HYPERV_SLATDISABLED)
        Abort
      ${ElseIf} $0 != "True$\r$\n"
        MessageBox MB_OK|MB_ICONSTOP $(STRING_HYPERV_SLATCHECKFAILED)
        Abort
      ${EndIf}

      ${If} ${IsServerOS}
        ${RunPowerShellCmd} "Import-Module ServerManager; (Add-WindowsFeature Hyper-V).Success"
      ${Else}
        ${RunPowerShellCmd} "(Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart).Online -and (Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -NoRestart).Online -and (Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Hypervisor -NoRestart).Online -and (Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Services -NoRestart).Online"
      ${EndIf}
      Pop $0
      StrLen $1 $0
      IntOp $1 $1 - 6
      StrCpy $2 $0 6 $1
      ${If} $2 != "True$\r$\n"
        MessageBox MB_OK|MB_ICONSTOP "$(STRING_HYPERVINSTALLFAILED)"
        Abort
      ${EndIf}
    ${ElseIf} $0 != "True$\r$\n"
    ${AndIf} $0 != "Enabled$\r$\n"
      MessageBox MB_OK|MB_ICONSTOP "1: $(STRING_HYPERVCHECKFAILED)"
      Abort
    ${EndIf}

    ${If} ${IsServerOS}
      ${RunPowerShellCmd} "Import-Module ServerManager; (Get-WindowsFeature RSAT-Hyper-V-Tools).Installed"

      Pop $0
      ${If} $0 == "False$\r$\n"
      ${OrIf} $0 == "Disabled$\r$\n"
        MessageBox MB_OKCANCEL|MB_ICONQUESTION $(STRING_HYPERVTOOLSINSTALLATIONCONFIRM) \
          IDOK lbl_installhypervtools
          Abort

lbl_installhypervtools:
        ${RunPowerShellCmd} "Import-Module ServerManager; (Add-WindowsFeature RSAT-Hyper-V-Tools).Success"
        Pop $0
        StrLen $1 $0
        IntOp $1 $1 - 6
        StrCpy $2 $0 6 $1
        ${If} $2 != "True$\r$\n"
          MessageBox MB_OK|MB_ICONSTOP $(STRING_HYPERVTOOLSINSTALLFAILED)
          Abort
        ${EndIf}
      ${ElseIf} $0 != "True$\r$\n"
        MessageBox MB_OK|MB_ICONSTOP $(STRING_HYPERVTOOLSCHECKFAILED)
        Abort
      ${EndIf}

      ${RunPowerShellCmd} "Import-Module ServerManager; (Add-WindowsFeature RSAT-Hyper-V-Tools).RestartNeeded"
      Pop $0
      ${If} $0 == "Yes$\r$\n"
      ${OrIf} $0 == "True$\r$\n"
        MessageBox MB_OK|MB_ICONINFORMATION $(STRING_HYPERVTOOLSREBOOTREQUIRED)
        ; installer should quit because reboot is needed
        Quit
      ${ElseIf} $0 != "No$\r$\n"
      ${AndIf} $0 != "False$\r$\n"
        MessageBox MB_OK|MB_ICONSTOP "2: $(STRING_HYPERVCHECKFAILED)"
        Abort
      ${EndIf}
    ${EndIf}

    ${If} ${IsServerOS}
      ${RunPowerShellCmd} "Import-Module ServerManager; (Add-WindowsFeature Hyper-V).RestartNeeded"
    ${Else}
      ${RunPowerShellCmd} "(Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart).RestartNeeded 3> $$null"
    ${EndIf}
    Pop $0
    ${If} $0 == "Yes$\r$\n"
    ${OrIf} $0 == "True$\r$\n"
      MessageBox MB_OK|MB_ICONINFORMATION $(STRING_HYPERVREBOOTREQUIRED)
      ; installer should quit because reboot is needed
      Quit
    ${ElseIf} $0 != "No$\r$\n"
    ${AndIf} $0 != "False$\r$\n"
      MessageBox MB_OK|MB_ICONSTOP "2: $(STRING_HYPERVCHECKFAILED)"
      Abort
    ${EndIf}

    ${RunPowerShellCmd} "(Get-VmSwitch -SwitchType External).Name -join $\"|$\""
    Pop $0
    ${If} $0 == "$\r$\n"
      MessageBox MB_OK|MB_ICONSTOP $(STRING_HYPERV_NOEXTERNALSWITCH)
      Abort
    ${EndIf}

    ${RunPowerShellCmd} "(Get-VMHost).VirtualHardDiskPath"
    Pop $dirVM

    StrLen $R4 $dirVM
lbl_loophypervpropcrlf:
    IntOp $R4 $R4 - 1
    StrCpy $R5 $dirVM 1 $R4
    StrCmp $R5 "$\r" lbl_loophypervpropcrlf
    StrCmp $R5 "$\n" lbl_loophypervpropcrlf

    IntOp $R4 $R4 + 1
    StrCpy $dirVM $dirVM $R4 0
  ${ElseIf} $environment == $(STRING_ENVIRONMENTSELECTITEM_LINUXONWINDOWS)
    ; check operating system (Windows 10 version 10.0.16226 or later required)
    ClearErrors
    ${IfNot} ${IsNT}
      MessageBox MB_OK|MB_ICONSTOP $(STRING_LINUXONWIN_OSFAILED)
      Abort
    ${EndIf}
    ${IfNot} ${AtLeastWin10}
      MessageBox MB_OK|MB_ICONSTOP $(STRING_LINUXONWIN_OSFAILED)
      Abort
    ${EndIf}

    ; check whether it is server os or not (server os is not supported yet)
    ${If} ${IsServerOS}
      MessageBox MB_OK|MB_ICONSTOP $(STRING_LINUXONWIN_SERVEROSFAILED)
      Abort
    ${EndIf}

    ; check Internet connectivity
    ; ###TODO###

    ; check free storage (8GB or more needed)
    ; ###TODO###

    ; check powershell (required for later procedure)
    IfFileExists "$SYSDIR\WindowsPowerShell\v1.0\PowerShell.exe" lbl_powershelllinuxonwin
    MessageBox MB_OK|MB_ICONSTOP $(STRING_NOPOWERSHELLLINUXONWIN)
    Abort
lbl_powershelllinuxonwin:

    ; check operating system (Windows 10 version 10.0.16226 or later required)
    ${RunPowerShellCmd} "[System.Environment]::OSVersion.Version.Build"
    Pop $buildNum
    ${If} $buildNum < 16226
      MessageBox MB_OK|MB_ICONSTOP $(STRING_LINUXONWIN_OSFAILED)
      Abort
    ${EndIf}

    ; check whether Linux subsystem is installed or not
    ${If} $buildNum < 22000
      ${RunPowerShellCmd} "(Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux).State -and 1"
    ${Else}
      ; if Windows 11 (version 10.0.22000 or later) is installed,
      ; VirtualMachinePlatform is also required (i.e. only supports WSL2).
      ${RunPowerShellCmd} "(Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux).State -and (Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform).State"
    ${EndIf}
    Pop $0
    ${If} $0 == "False$\r$\n"
      MessageBox MB_OKCANCEL|MB_ICONQUESTION $(STRING_LINUXONWININSTALLATIONCONFIRM) \
        IDOK lbl_installlinuxonwin
        Abort

lbl_installlinuxonwin:
      ${If} $buildNum < 22000
        ${RunPowerShellCmd} "(Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart).Online 3> $$null"
      ${Else}
        ; if Windows 11 (version 10.0.22000 or later) is installed,
	; VirtualMachinePlatform is also required (i.e. only supports WSL2).
        ${RunPowerShellCmd} "(Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart).Online -and (Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart).Online 3> $$null"
      ${EndIf}
      Pop $0
      ${If} $0 != "True$\r$\n"
        MessageBox MB_OK|MB_ICONSTOP $(STRING_LINUXONWININSTALLFAILED)
        Abort
      ${EndIf}
    ${ElseIf} $0 != "True$\r$\n"
      MessageBox MB_OK|MB_ICONSTOP "$(STRING_LINUXONWINCHECKFAILED)"
      Abort
    ${EndIf}

    ; check reboot is needed or not
    ${If} $buildNum < 22000
      ${RunPowerShellCmd} "(Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart).RestartNeeded 3> $$null"
    ${Else}
      ; if Windows 11 (version 10.0.22000 or later) is installed,
      ; VirtualMachinePlatform is also required (i.e. only supports WSL2).
      ${RunPowerShellCmd} "(Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart).RestartNeeded -or (Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart).RestartNeeded 3> $$null"
    ${EndIf}
    Pop $0
    ${If} $0 == "True$\r$\n"
      MessageBox MB_OK|MB_ICONINFORMATION $(STRING_LINUXONWINREBOOTREQUIRED)
      ; installer should quit because reboot is needed
      Quit
    ${EndIf}

    MessageBox MB_OKCANCEL|MB_ICONQUESTION|MB_DEFBUTTON2 $(STRING_STARTCONFIRM) \
      IDOK leavedist_ok_linuxonwin
    Abort
leavedist_ok_linuxonwin:
  ${Else}
    ; check bootloader when install to real (i.e. not virtual) machine
    Call CheckBootloader
    Pop $R0

    ${If} $R0 == 'vista'
      ; check BCD store
      nsExec::ExecToStack "cmd /c $\"wmic Volume where SystemVolume=true get DeviceID | findstr /B /L \$\""
      Pop $1
      Pop $1
      StrCpy $2 0
lbl_loopvolumespaces:
      IntOp $2 $2 + 1
      StrCpy $3 $1 1 $2
      StrCmp $3 " " lbl_loopexitvolumespaces
      StrCmp $3 "$\r" lbl_loopexitvolumespaces
      StrCmp $3 "$\n" lbl_loopexitvolumespaces
      Goto lbl_loopvolumespaces
lbl_loopexitvolumespaces:
      StrCpy $4 $1 $2
      StrCpy $bcdStore "$4\boot\bcd"

      ; check whether UEFI boot mode is activated or not
      ExpandEnvStrings $0 %COMSPEC%
      nsExec::ExecToStack '"$0" /C "$bcdedit /enum bootmgr | findstr /I ^path | findstr /I \.efi$$"'
      Pop $1
      Pop $1
      StrLen $0 $1
      ${If} $0 > 0
        MessageBox MB_OK|MB_ICONSTOP $(STRING_REFUSE_UEFI)
        Abort
      ${EndIf}

      ; check BitLocker encryption
      nsExec::ExecToStack "cmd /c $\"wmic /namespace:\\root\cimv2\Security\MicrosoftVolumeEncryption path Win32_EncryptableVolume where 'DriveLetter = '$systemDrive'' call GetConversionStatus | findstr /C:$\"ConversionStatus = $\"$\""
      Pop $1
      Pop $2
      ${If} $1 = 0
        ${If} $2 != "$\r$\n$\tConversionStatus = 0;$\r$\n"
          MessageBox MB_OK|MB_ICONSTOP $(STRING_SYSTEMDRIVE_ENCRYPTED)
          Abort
        ${EndIf}
      ${EndIf}
    ${EndIf}

    MessageBox MB_OKCANCEL|MB_ICONQUESTION|MB_DEFBUTTON2 $(STRING_STARTCONFIRM) \
      IDOK leavedist_ok
    Abort
leavedist_ok:
  ${EndIf}

FunctionEnd ; "LeaveDistributionSelection"

; -----------------------------------------------------------------------------
; display virtual machine settings

Section "Display virtual machine settings"
  SectionIn RO                  ; always show
SectionEnd

Function "UpdateVirtualSwitches"
  ${RunPowerShellCmd} "(Get-VmSwitch -SwitchType External).Name -join $\"|$\""
  Pop $0
  WriteIniStr ${VIRTSET_INI} "Field 8" "ListItems" "$0"
  ${RunPowerShellCmd} "(Get-VmSwitch -SwitchType External).Name | Select-Object -First 1"
  Pop $0
  WriteIniStr ${VIRTSET_INI} "Field 8" "State" "$0"
FunctionEnd ; "UpdateVirtualSwitches"

Function "ShowVirtualMachineSettings"
  ; If not virtual machine, skip it
  ${If} $environment == $(STRING_ENVIRONMENTSELECTITEM_DUALBOOT)
  ${OrIf} $environment == $(STRING_ENVIRONMENTSELECTITEM_LINUXONWINDOWS)
    Abort
  ${EndIf}

  WriteIniStr ${VIRTSET_INI} "Field 1" "Text" $(STRING_VMNAME)
  WriteIniStr ${VIRTSET_INI} "Field 3" "Text" $(STRING_VMMEMORY)
  WriteIniStr ${VIRTSET_INI} "Field 5" "Text" $(STRING_VMDISK)
  WriteIniStr ${VIRTSET_INI} "Field 7" "Text" $(STRING_VMNETWORK)

  ${If} $nameVM != ""
    WriteIniStr ${VIRTSET_INI} "Field 2" "State" "$nameVM"
  ${Else}
    WriteIniStr ${VIRTSET_INI} "Field 2" "State" "$distribution $architecture"
  ${EndIf}

  ${If} $memoryVM != ""
    WriteIniStr ${VIRTSET_INI} "Field 4" "State" "$memoryVM"
  ${Else}
    WriteIniStr ${VIRTSET_INI} "Field 4" "State" "1024"
  ${EndIf}

  ${If} $diskVM != ""
    WriteIniStr ${VIRTSET_INI} "Field 6" "State" "$diskVM"
  ${Else}
    WriteIniStr ${VIRTSET_INI} "Field 6" "State" "8192"

    ; Increase to 10GB for Leap 15.0 or later
    StrCpy $0 $distribution 14
    ${If} $0 == "openSUSE Leap "
      StrCpy $R3 $distribution 255 14
      ${If} $R3 < 42
        WriteIniStr ${VIRTSET_INI} "Field 6" "State" "10240"
      ${EndIf}
    ${EndIf}
  ${EndIf}

  ${If} $environment == $(STRING_ENVIRONMENTSELECTITEM_HYPERV)
    ${If} $switchVM != ""
      WriteIniStr ${VIRTSET_INI} "Field 8" "State" "$switchVM"
    ${Else}
      Call UpdateVirtualSwitches
    ${EndIf}
  ${Else}
    WriteIniStr ${VIRTSET_INI} "Field 7" "Flags" "DISABLED"
    WriteIniStr ${VIRTSET_INI} "Field 8" "Flags" "DISABLED"
    WriteIniStr ${VIRTSET_INI} "Field 8" "ListItems" ""
    WriteIniStr ${VIRTSET_INI} "Field 9" "Flags" "DISABLED"
  ${EndIf}

  ; show dialog
  InstallOptions::initDialog /NOUNLOAD ${VIRTSET_INI}
  Pop $hwnd

  !insertmacro MUI_HEADER_TEXT $(STRING_VMSETTINGS_TITLE) $(STRING_VMSETTINGS_TEXT)

  InstallOptions::show
FunctionEnd ; "ShowVirtualMachineSettings"

Function "LeaveVirtualMachineSettings"
  ReadIniStr $nameVM ${VIRTSET_INI} "Field 2" "State"
  ReadIniStr $memoryVM ${VIRTSET_INI} "Field 4" "State"
  ReadInIStr $diskVM ${VIRTSET_INI} "Field 6" "State"
  ReadIniStr $switchVM ${VIRTSET_INI} "Field 8" "State"

  MessageBox MB_OKCANCEL|MB_ICONQUESTION|MB_DEFBUTTON2 $(STRING_STARTCONFIRM) \
    IDOK leavedist_ok
  Abort
leavedist_ok:

FunctionEnd ; "LeaveVirtualMachineSettings"

; -----------------------------------------------------------------------------
; check bootloader

!macro CheckBootloaderMacro un
Function ${un}CheckBootloader
  Push $R0
  Push $R1
  ClearErrors

  ; check if Windows NT family
  ClearErrors
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

  ${If} $environment == $(STRING_ENVIRONMENTSELECTITEM_VIRTUALBOX)
  ${OrIf} $environment == $(STRING_ENVIRONMENTSELECTITEM_HYPERV)
    ; download NET iso
    ${If} $architecture == "i386"
      StrCpy $architecture "i586"
    ${EndIf}

    StrCpy $0 $distribution 14
    ${If} $distribution == "openSUSE Tumbleweed"
      ; openSUSE Tumbleweed
      StrCpy $R1 "http://download.opensuse.org/tumbleweed/iso/openSUSE-Tumbleweed-NET-$architecture-Current.iso"
      StrCpy $R2 "openSUSE-Tumbleweed-NET-$architecture-Current.iso"
    ${ElseIf} $0 == "openSUSE Leap "
      ; openSUSE Leap
      StrCpy $R3 $distribution 255 14
      StrCpy $R1 "http://download.opensuse.org/distribution/leap/$R3/iso/openSUSE-Leap-$R3-NET-$architecture.iso"
      StrCpy $R2 "openSUSE-Leap-$R3-NET-$architecture.iso"
    ${Else}
      ; openSUSE (before Leap)
      StrCpy $R3 $distribution 255 9
      StrCpy $R1 "http://download.opensuse.org/distribution/$R3/iso/openSUSE-$R3-NET-$architecture.iso"
      StrCpy $R2 "openSUSE-$R3-NET-$architecture.iso"
    ${EndIf}

    NSISdl::download $R1 "$dirVM\$R2"
    Pop $0
    ${If} $0 == "cancel"
      Abort
    ${ElseIf} $0 != "success"
      ; try again with "-Current"
      StrCpy $0 $distribution 14
      ${If} $distribution == "openSUSE Tumbleweed"
        MessageBox MB_OK|MB_ICONSTOP "iso $(STRING_DOWNLOADERROR_R1)"
        Abort
      ${ElseIf} $0 == "openSUSE Leap "
        ; openSUSE Leap
        StrCpy $R3 $distribution 255 14
        StrCpy $R1 "http://download.opensuse.org/distribution/leap/$R3/iso/openSUSE-Leap-$R3-NET-$architecture-Current.iso"
        StrCpy $R2 "openSUSE-Leap-$R3-NET-$architecture-Current.iso"
      ${Else}
        ; openSUSE (before Leap)
        StrCpy $R3 $distribution 255 9
        StrCpy $R1 "http://download.opensuse.org/distribution/$R3/iso/openSUSE-$R3-NET-$architecture-Current.iso"
        StrCpy $R2 "openSUSE-$R3-NET-$architecture-Current.iso"
      ${EndIf}

      NSISdl::download $R1 "$dirVM\$R2"
      Pop $0
      ${If} $0 == "cancel"
        Abort
      ${ElseIf} $0 != "success"
        MessageBox MB_OK|MB_ICONSTOP "iso $(STRING_DOWNLOADERROR_R1)"
        Abort
      ${EndIf}
    ${EndIf}

    ${If} $environment == $(STRING_ENVIRONMENTSELECTITEM_VIRTUALBOX)
      ; create a virtual machine and start it..
      ${If} $architecture == "i386"
        StrCpy $R4 "$\"$dirVirt\VBoxManage$\" createvm --name $\"$nameVM$\" --register --ostype $\"OpenSUSE$\""
        nsExec::Exec $R4
      ${Else}
        StrCpy $R4 "$\"$dirVirt\VBoxManage$\" createvm --name $\"$nameVM$\" --register --ostype $\"OpenSUSE_64$\""
        nsExec::Exec $R4
      ${EndIf}
      Pop $R5
      StrCmp $R5 "0" 0 lbl_vboxerrorsnodelete
      StrCpy $R4 "$\"$dirVirt\VBoxManage$\" modifyvm $\"$nameVM$\" --memory $memoryVM --vram 32 --mouse usbtablet"
      nsExec::Exec $R4
      Pop $R5
      StrCmp $R5 "0" 0 lbl_vboxerrors
      StrCpy $R4 "$\"$dirVirt\VBoxManage$\" storagectl $\"$nameVM$\" --name $\"SATA$\" --add sata --bootable on"
      nsExec::Exec $R4
      Pop $R5
      StrCmp $R5 "0" 0 lbl_vboxerrors
      StrCpy $R4 "$\"$dirVirt\VBoxManage$\" createmedium disk --filename $\"$dirVM\$nameVM.vdi$\" --size $diskVM --variant Standard"
      nsExec::Exec $R4
      Pop $R5
      StrCmp $R5 "0" 0 lbl_vboxerrors
      StrCpy $R4 "$\"$dirVirt\VBoxManage$\" storageattach $\"$nameVM$\" --storagectl $\"SATA$\" --port 0 --type hdd --medium $\"$dirVM\$nameVM.vdi$\""
      nsExec::Exec $R4
      Pop $R5
      StrCmp $R5 "0" 0 lbl_vboxerrors
      StrCpy $R4 "$\"$dirVirt\VBoxManage$\" storagectl $\"$nameVM$\" --name $\"IDE$\" --add ide --bootable on"
      nsExec::Exec $R4
      Pop $R5
      StrCmp $R5 "0" 0 lbl_vboxerrors
      StrCpy $R4 "$\"$dirVirt\VBoxManage$\" storageattach $\"$nameVM$\" --storagectl $\"IDE$\" --port 0 --device 0 --type dvddrive --medium $\"$dirVM\$R2$\""
      nsExec::Exec $R4
      Pop $R5
      StrCmp $R5 "0" 0 lbl_vboxerrors
      StrCpy $R4 "$\"$dirVirt\VBoxManage$\" startvm $\"$nameVM$\" --type gui"
      nsExec::Exec $R4
      Pop $R5
      StrCmp $R5 "0" 0 lbl_vboxerrors

      ; show informational message
      MessageBox MB_OK|MB_ICONINFORMATION $(STRING_STARTEDVM)

      ; no more action is needed for virtualized environment
      Return

lbl_vboxerrors:
      ; delete created VM
      StrCpy $R6 "$\"$dirVirt\VBoxManage$\" unregistervm $\"$nameVM$\" --delete"
      nsExec::Exec $R6
      Pop $R6 ; ignore errors

lbl_vboxerrorsnodelete:
      ; show error message
      MessageBox MB_OK|MB_ICONSTOP $(STRING_CREATEVMERROR)
      Abort
    ${ElseIf} $environment == $(STRING_ENVIRONMENTSELECTITEM_HYPERV)
      ; memory=[MiB] to [B], disk=[MiB] to [B]
      System::Int64Op $memoryVM << 20
      Pop $memoryVM
      System::Int64Op $diskVM << 20
      Pop $diskVM

      StrCpy $R4 "(New-VM -Name $\"$nameVM$\" -MemoryStartupBytes $memoryVM -NewVHDPath $\"$nameVM.vhdx$\" -NewVHDSizeBytes $diskVM -SwitchName $\"$switchVM$\").Name 2>&1"
      ${RunPowerShellCmd} $R4
      Pop $0
      ${If} $0 != "$nameVM$\r$\n"
        StrCpy $R5 $0
        Goto lbl_hyperverrorsnodelete
        Abort
      ${EndIf}

      StrCpy $R4 "Set-VMDvdDrive -VMname $\"$nameVM$\" -Path $\"$dirVM\$R2$\" 2>&1"
      ${RunPowerShellCmd} $R4
      Pop $0
      ${If} $0 != ""
        StrCpy $R5 $0
        Goto lbl_hyperverrors
      ${EndIf}

      StrCpy $R4 "Start-VM -Name $\"$nameVM$\""
      ${RunPowerShellCmd} $R4
      Pop $0
      ${If} $0 != ""
        StrCpy $R5 $0
        Goto lbl_hyperverrors
      ${EndIf}

      Exec "$\"$WINDIR\Sysnative\vmconnect.exe$\" $\"localhost$\" $\"$nameVM$\""

      ; show informational message
      MessageBox MB_OK|MB_ICONINFORMATION $(STRING_STARTEDVM)

      ; no more action is needed for virtualized environment
      Return

lbl_hyperverrors:
      ; delete created VM
      ${RunPowerShellCmd} "Remove-VM -Name $\"$nameVM$\" -Force"
      Pop $R6 ; ignore errors
      Delete "$dirVM\$nameVM.vhdx"

lbl_hyperverrorsnodelete:
      ; show error message
      MessageBox MB_OK|MB_ICONSTOP $(STRING_CREATEVMERROR)
      Abort
    ${EndIf}
  ${ElseIf} $environment == $(STRING_ENVIRONMENTSELECTITEM_LINUXONWINDOWS)
    ; if Windows 11 (version 10.0.22000 or later) is installed,
    ; kernel package must be installed
    ${If} $buildNum >= 22000
      ; "Lxss" regitry is only available for 64bit view
      SetRegView 64
      ReadRegStr $0 HKLM \
        "SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss" "KernelVersion"

      StrLen $1 $0
      ${If} $1 < 1
	Banner::show /set 76 $(STRING_BANNER_WAITINGTITLE) $(STRING_BANNER_WAITING_TEXT)
	; wsl.exe is available under sysnative
        nsExec::Exec '$\"$WINDIR\Sysnative\wsl.exe$\" --update'
	Banner::destroy
      ${EndIf}
    ${EndIf}

    ${If} $distribution == "openSUSE Leap 42.1"
    ${OrIf} $distribution == "openSUSE Leap 42.2"
    ${OrIf} $distribution == "openSUSE Leap 42.3"
      ; open Microsoft Store
      MessageBox MB_OK|MB_ICONINFORMATION "$(STRING_LINUXONWIN_BEFORESTORE)"
      ExecShell "open" "https://www.microsoft.com/store/p/app/9njvjts82tjx"
    ${ElseIf} $distribution == "openSUSE Leap 15.0"
      ; open Microsoft Store
      MessageBox MB_OK|MB_ICONINFORMATION "$(STRING_LINUXONWIN_BEFORESTORE)"
      ExecShell "open" "https://www.microsoft.com/store/p/app/9n1tb6fpvj8c"
    ${ElseIf} $distribution == "openSUSE Leap 15.1"
      ; open Microsoft Store
      MessageBox MB_OK|MB_ICONINFORMATION "$(STRING_LINUXONWIN_BEFORESTORE)"
      ExecShell "open" "https://www.microsoft.com/store/p/app/9njfzk00fgkv"
    ${ElseIf} $distribution == "openSUSE Leap 15.2"
      ; open Microsoft Store
      MessageBox MB_OK|MB_ICONINFORMATION "$(STRING_LINUXONWIN_BEFORESTORE)"
      ExecShell "open" "https://www.microsoft.com/store/p/app/9mzd0n9z4m4h"
    ${ElseIf} $distribution == "openSUSE Leap 15.3"
      ; open Microsoft Store
      MessageBox MB_OK|MB_ICONINFORMATION "$(STRING_LINUXONWIN_BEFORESTORE)"
      ExecShell "open" "https://www.microsoft.com/store/p/app/9n6j06bmcgt3"
    ${Else}
      MessageBox MB_OK|MB_ICONSTOP "$(STRING_LINUXONWIN_NOTFOUNDONSTORE)"
    ${EndIf}

    Return
  ${EndIf}

  StrLen $1 $(STRING_VERSIONOFTHISMEDIA)
  StrCpy $0 $distribution $1
  ${If} $0 == $(STRING_VERSIONOFTHISMEDIA)
    ; copy kernel and initrd from this media
    CopyFiles "$EXEDIR\boot\$architecture\loader\linux" "$INSTDIR\linux"
    CopyFiles "$EXEDIR\boot\$architecture\loader\initrd" "$INSTDIR\initrd"
    StrCpy $instsource "install=cd:/"
  ${Else}
    ; download kernel and initrd
    StrCpy $0 $distribution 14
    ${If} $distribution == "openSUSE Tumbleweed"
      ; openSUSE Tumbleweed
      StrCpy $R1 "http://download.opensuse.org/tumbleweed/repo/oss/boot/$architecture/loader/linux"
      StrCpy $R2 "http://download.opensuse.org/tumbleweed/repo/oss/boot/$architecture/loader/initrd"
      StrCpy $instsource "install=http://download.opensuse.org/tumbleweed/repo/oss/ server=download.opensuse.org"
    ${ElseIf} $0 == "openSUSE Leap "
      ; openSUSE Leap
      StrCpy $R3 $distribution 255 14
      StrCpy $R1 "http://download.opensuse.org/distribution/leap/$R3/repo/oss/boot/$architecture/loader/linux"
      StrCpy $R2 "http://download.opensuse.org/distribution/leap/$R3/repo/oss/boot/$architecture/loader/initrd"
      StrCpy $instsource "install=http://download.opensuse.org/distribution/leap/$R3/repo/oss/ server=download.opensuse.org"
    ${Else}
      ; openSUSE (before Leap)
      StrCpy $R3 $distribution 255 9
      StrCpy $R1 "http://download.opensuse.org/distribution/$R3/repo/oss/boot/$architecture/loader/linux"
      StrCpy $R2 "http://download.opensuse.org/distribution/$R3/repo/oss/boot/$architecture/loader/initrd"
      StrCpy $instsource "install=http://download.opensuse.org/distribution/$R3/repo/oss/ server=download.opensuse.org"
    ${EndIf}

    NSISdl::download $R1 "$INSTDIR\linux"
    Pop $0
    ${If} $0 == "cancel"
      Delete /REBOOTOK "$INSTDIR\linux"
      RmDir /REBOOTOK /r $INSTDIR

      Abort
    ${ElseIf} $0 != "success"
      Delete /REBOOTOK "$INSTDIR\linux"
      RmDir /REBOOTOK /r "$INSTDIR"

      MessageBox MB_OK|MB_ICONSTOP $(STRING_DOWNLOADERROR_R1)
      Abort
    ${EndIf}

    NSISdl::download $R2 "$INSTDIR\initrd"
    Pop $0
    ${If} $0 == "cancel"
      Delete /REBOOTOK "$INSTDIR\linux"
      Delete /REBOOTOK "$INSTDIR\initrd"
      RmDir /REBOOTOK /r "$INSTDIR"

      Abort
    ${ElseIf} $0 != "success"
      Delete /REBOOTOK "$INSTDIR\linux"
      Delete /REBOOTOK "$INSTDIR\initrd"
      RmDir /REBOOTOK /r "$INSTDIR"

      StrCpy $R1 $R2
      MessageBox MB_OK|MB_ICONSTOP $(STRING_DOWNLOADERROR_R1)
      Abort
    ${EndIf}
  ${EndIf}

  ; check bootloader and modify it accordingly
  Call CheckBootloader
  Pop $R0

  ${If} $R0 == '9x'
    # --------------------------------- Windows 9x style bootloader
    # Write uninstaller before doing anything else...
    WriteUninstaller "$SMSTARTUP\openSUSE-uninst.exe"

    File /oname=$systemDrive\grub.exe "grub.exe"
    Rename "$systemDrive\config.sys" "$systemDrive\config-bak.sys"
    FileOpen $R1 "$systemDrive\config.sys" w
    FileWrite $R1 "[menu]$\r$\n"
    FileWrite $R1 "menuitem=Windows , Start Windows$\r$\n"
    FileWrite $R1 "menuitem=openSUSE installer, openSUSE installer$\r$\n$\r$\n"
    FileWrite $R1 "[Windows]$\r$\n"
    FileWrite $R1 "shell=io.sys$\r$\n$\r$\n"
    FileWrite $R1 "[openSUSE installer]$\r$\n"
    FileWrite $R1 "install=grub.exe --config-file=(hd0,0)/menu.lst"
    FileSeek $R1 0 END
    FileClose $R1
  ${ElseIf} $R0 == 'nt'
    # --------------------------------- Windows NT style bootloader
    # Write uninstaller before doing anything else...
    WriteUninstaller "$SMSTARTUP\openSUSE-uninst.exe"

    ; save timeout value
    ReadINIStr $0 "$systemDrive\boot.ini" "boot loader" "timeout"
    WriteINIStr "$systemDrive\boot.save" "boot loader" "timeout" $0
    ; write new values
    SetFileAttributes "$systemDrive\boot.ini" NORMAL
    WriteINIStr "$systemDrive\boot.ini" "boot loader" "timeout" "30"
    WriteINIStr "$systemDrive\boot.ini" "operating systems" "$systemDrive\grldr" '"openSUSE installer"'
    SetFileAttributes "$systemDrive\boot.ini" SYSTEM|HIDDEN

    File /oname=$systemDrive\grldr "grldr"
    File /oname=$systemDrive\grldr.mbr "grldr.mbr"
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
    WriteUninstaller "$systemDrive\openSUSE-uninst.exe"

    IfFileExists "$SYSDIR\WindowsPowerShell\v1.0\PowerShell.exe" 0 lbl_nopowershell
    CreateShortcut "$SMSTARTUP\openSUSE setup uninstaller.lnk" \
      "$SYSDIR\WindowsPowerShell\v1.0\PowerShell.exe" \
      "Start-Process $systemDrive\openSUSE-uninst.exe -Verb RunAs"
    Goto lbl_powershelldone
lbl_nopowershell:
    StrCpy $R0 "$systemDrive\openSUSE-uninst.exe"
    MessageBox MB_OK|MB_ICONEXCLAMATION $(STRING_NOPOWERSHELL)
lbl_powershelldone:

    ; check BCD store
    nsExec::ExecToStack "cmd /c $\"wmic Volume where SystemVolume=true get DeviceID | findstr /B /L \$\""
    Pop $1
    Pop $1
    StrCpy $2 0
lbl_loopvolumespaces:
    IntOp $2 $2 + 1
    StrCpy $3 $1 1 $2
    StrCmp $3 " " lbl_loopexitvolumespaces
    StrCmp $3 "$\r" lbl_loopexitvolumespaces
    StrCmp $3 "$\n" lbl_loopexitvolumespaces
    Goto lbl_loopvolumespaces
lbl_loopexitvolumespaces:
    StrCpy $4 $1 $2
    StrCpy $bcdStore "$4\boot\bcd"

    # check registry if boot ID was already generated or not
    ReadRegStr $0 HKLM "Software\openSUSE\openSUSE-Installer Loader" "bootmgr"
    ${If} $0 == ""
      nsExec::ExecToStack '"$BcdEdit" /store $bcdStore /create /d "openSUSE installer" /application bootsector'
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
    nsExec::Exec '"$BcdEdit" /store $bcdStore /set $R3 device partition=$systemDrive'
    nsExec::Exec '"$BcdEdit" /store $bcdStore /set $R3 path \grldr.mbr'
    nsExec::Exec '"$BcdEdit" /store $bcdStore /timeout 30'
    nsExec::Exec '"$BcdEdit" /store $bcdStore /displayorder $R3 /addlast'

    File /oname=$systemDrive\grldr "grldr"
    File /oname=$systemDrive\grldr.mbr "grldr.mbr"
  ${Else} ; bootloader
    ; not supported version
    MessageBox MB_OK $(STRING_NOTSUPPORTED_OS)
    Quit
  ${EndIf}

  FileOpen $R3 "$systemDrive\openSUSE_hitme.txt" a 
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
  ${ElseIf} $LANGUAGE == ${LANG_LITHUANIAN}
    StrCpy $R4 "lt"
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
    # 16bit is not available for this resolution
    StrCpy $R5 "0x37D"
  ${Else}
    # if unknown
    StrCpy $R5 "normal"
  ${EndIf}

  FileOpen $R6 $systemDrive\menu.lst a
  FileWrite $R6 "hiddenmenu$\r$\n"
  FileWrite $R6 "timeout 0$\r$\n"

  FileWrite $R6 "title openSUSE installer$\r$\n"
  FileWrite $R6 "find --set-root /openSUSE_hitme.txt$\r$\n"

  FileWrite $R6 "kernel /openSUSE/linux devfs=mount,dall ramdisk_size=65536 $instsource lang=$R4 splash=silent vga=$R5$\r$\n"
  FileWrite $R6 "initrd /openSUSE/initrd$\r$\n"
  FileSeek $R6 0 END
  FileClose $R6

  # uncompress files
  nsExec::Exec '"compact" /u $systemDrive\grldr $systemDrive\grldr.mbr $systemDrive\menu.lst $INSTDIR\linux $INSTDIR\initrd'

  SetRebootFlag True

  ; check GUI (Startup shortcut won't be run if Server Core is used)
  IfFileExists "$WINDIR\explorer.exe" 0 +2
    MessageBox MB_OK|MB_ICONINFORMATION $(STRING_PRELIM_WORK_COMPLETED)
  IfFileExists "$WINDIR\explorer.exe" +2 0
    MessageBox MB_OK|MB_ICONINFORMATION $(STRING_PRELIM_WORK_COMPLETED_SERVERCORE)
SectionEnd ; "Install"

; -----------------------------------------------------------------------------
; uninstall section

Section "Uninstall"
  ; check bootloader and uninstall accordingly
  Call un.CheckBootloader
  Pop $R0

  ${If} $R0 == '9x'
    Delete /REBOOTOK "$systemDrive\grub.exe"
    Delete /REBOOTOK "$systemDrive\config.sys"
    Rename "$systemDrive\config-bak.sys" "$systemDrive\config.sys"

    Delete /REBOOTOK "$SMSTARTUP\openSUSE-uninst.exe"
  ${ElseIf} $R0 == 'nt'
    Delete /REBOOTOK "$systemDrive\grldr"
    SetFileAttributes "$systemDrive\boot.ini" NORMAL
    DeleteINIStr "$systemDrive\boot.ini" "operating systems" "$systemDrive\grldr"

    ; restore timeout
    DeleteINIStr "$systemDrive\boot.ini" "boot loader" "timeout"
    ReadINIStr $0 "$systemDrive\boot.save" "boot loader" "timeout"
    Delete "$systemDrive\boot.save"
    WriteINIStr "$systemDrive\boot.ini" "boot loader" "timeout" $0
    SetFileAttributes "$systemDrive\boot.ini" SYSTEM|HIDDEN

    Delete /REBOOTOK "$SMSTARTUP\openSUSE-uninst.exe"
  ${ElseIf} $R0 == 'vista'
    Delete /REBOOTOK "$systemDrive\grldr"

    ; if running in X64, bcdedit is in %windir%\Sysnative.
    ${If} ${RunningX64}
      ExpandEnvStrings $BcdEdit "%windir%\Sysnative\bcdedit"
    ${Else}
      StrCpy $BcdEdit "bcdedit"
    ${EndIf}

    ; check BCD store
    nsExec::ExecToStack "cmd /c $\"wmic Volume where SystemVolume=true get DeviceID | findstr /B /L \$\""
    Pop $1
    Pop $1
    StrCpy $2 0
lbl_loopvolumespaces:
    IntOp $2 $2 + 1
    StrCpy $3 $1 1 $2
    StrCmp $3 " " lbl_loopexitvolumespaces
    StrCmp $3 "$\r" lbl_loopexitvolumespaces
    StrCmp $3 "$\n" lbl_loopexitvolumespaces
    Goto lbl_loopvolumespaces
lbl_loopexitvolumespaces:
    StrCpy $4 $1 $2
    StrCpy $bcdStore "$4\boot\bcd"

    ReadRegStr $0 HKLM "Software\openSUSE\openSUSE-Installer Loader" "bootmgr"
    ${If} $0 != ""
      nsExec::Exec '"$BcdEdit" /store $bcdStore /delete $0'
      Pop $0
      ${If} $0 != 0
        MessageBox MB_OK '"$BcdEdit" /store $bcdStore /delete $0 failed'
      ${Endif}
      DeleteRegKey HKLM "Software\openSUSE"
    ${Endif}

    Delete /REBOOTOK "$SMSTARTUP\openSUSE setup uninstaller.lnk"
    Delete /REBOOTOK "$systemDrive\openSUSE-uninst.exe"
  ${Else}
    ; not supported version
    MessageBox MB_OK $(STRING_NOTSUPPORTED_OS)
    Quit
  ${EndIf}

  ; cannot use $INSTDIR variable.
  Delete /REBOOTOK "$systemDrive\openSUSE\linux"
  Delete /REBOOTOK "$systemDrive\openSUSE\initrd"
  RmDir /REBOOTOK /r "$systemDrive\openSUSE"
  Delete /REBOOTOK "$systemDrive\menu.lst"
  Delete /REBOOTOK "$systemDrive\grldr"
  Delete /REBOOTOK "$systemDrive\grldr.mbr"
  Delete /REBOOTOK "$systemDrive\openSUSE_hitme.txt"
SectionEnd ; "Uninstall"
