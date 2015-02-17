[Setup]
AppName=AutoFLAC
AppVerName=AutoFLAC 1.2
AppPublisher=Jared Breland
AppPublisherURL=http://www.legroom.net/mysoft
AppSupportURL=http://www.legroom.net/mysoft
AppUpdatesURL=http://www.legroom.net/mysoft
DefaultDirName={reg:HKCU\Software\AWSoftware\EAC,InstallPath|{pf}\Exact Audio Copy}
DisableDirPage=false
DirExistsWarning=no
DefaultGroupName=Exact Audio Copy
OutputDir=Y:\software\autoflac\autoflac_12
SourceDir=Y:\software\autoflac\autoflac_12
OutputBaseFilename=autoflac12
SolidCompression=true
Compression=lzma/ultra
InternalCompressLevel=ultra
;SolidCompression=false
;Compression=none
;InternalCompressLevel=none
AlwaysShowComponentsList=false
DisableReadyPage=false
AppVersion=1.2
ShowLanguageDialog=auto
VersionInfoVersion=1.2
VersionInfoCompany=Jared Breland
VersionInfoDescription=Package for AutoFLAC
ChangesEnvironment=true
ChangesAssociations=true
AllowUNCPath=false
AllowNoIcons=true
UninstallDisplayIcon={app}\AutoFLAC.exe
WizardSmallImageFile=Y:\software\autoflac\support\Icons\autoflac_inno.bmp

[Types]
Name: custom; Description: Select which AutoFLAC components are installed; Flags: iscustom

[Components]
Name: autoflac; Description: AutoFLAC binary; Flags: fixed; Types: custom
Name: flac; Description: FLAC binaries

[Tasks]
Name: modifypath; Description: Add AutoFLAC binaries to your system &path
Name: associate; Description: &Enable Explorer context menu integration for CUE sheets; Flags: unchecked

[Files]
Source: ..\autoflac_changelog.txt; DestDir: {app}; Flags: ignoreversion; Components: autoflac
Source: ..\autoflac_license.txt; DestDir: {app}; Flags: ignoreversion; Components: autoflac
Source: ..\autoflac_todo.txt; DestDir: {app}; Flags: ignoreversion; Components: autoflac
Source: autoflac_readme.txt; DestDir: {app}; Flags: ignoreversion isreadme; Components: autoflac
Source: *.exe; DestDir: {app}; Flags: ignoreversion; Components: autoflac
Source: ..\support\flac-1.1.2-win\copying.gpl; DestDir: {app}\flac_license.txt; Flags: ignoreversion; Components: flac
Source: ..\support\flac-1.1.2-win\bin\flac.exe; DestDir: {app}; Flags: ignoreversion; Components: flac
Source: ..\support\flac-1.1.2-win\bin\metaflac.exe; DestDir: {app}; Flags: ignoreversion; Components: flac

[Icons]
Name: {userprograms}\Exact Audio Copy\AutoFLAC; Filename: {app}\AutoFLAC.exe; WorkingDir: {app}
Name: {userprograms}\Exact Audio Copy\AutoFLAC (Write Mode); Filename: {app}\AutoFLAC.exe; Parameters: /write; WorkingDir: {app}
Name: {userprograms}\Exact Audio Copy\AutoFLAC Readme; Filename: {app}\autoflac_readme.txt; WorkingDir: {app}

[Registry]
; Paths
Root: HKLM; Subkey: SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\AutoFLAC.exe; ValueType: string; ValueData: {app}\AutoFLAC.exe; Flags: uninsdeletekey; Tasks: modifypath
Root: HKLM; Subkey: SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\AutoFLAC.exe; ValueType: string; ValueName: Path; ValueData: {app}; Tasks: modifypath
; Context integration
Root: HKCR; SubKey: {reg:HKCR\.cue,}\shell\autoflac; ValueType: string; ValueData: Write with &AutoFLAC...; Flags: uninsdeletekey; Tasks: associate; Check: RVE('.cue')
Root: HKCR; SubKey: {reg:HKCR\.cue,}\shell\autoflac\command; ValueType: string; ValueData: """{app}\autoflac.exe"" /write ""%1"""; Tasks: associate; Check: RVE('.cue')
Root: HKCR; SubKey: .cue\shell\autoflac; ValueType: string; ValueData: Write with &AutoFLAC...; Flags: uninsdeletekey; Tasks: associate; Check: not RVE('.cue')
Root: HKCR; SubKey: .cue\shell\autoflac\command; ValueType: string; ValueData: """{app}\autoflac.exe"" /write ""%1"""; Tasks: associate; Check: not RVE('.cue')

[Code]
function RVE(ext: String): Boolean;
var
	regvalue: String;
begin
	RegQueryStringValue(HKEY_CLASSES_ROOT, ext, '', regvalue)
	if regvalue = '' then begin
		Result := False
	end else begin
		Result := True
	end;
end;

const
	ComponentList = 'autoflac - AutoFLAC binary, flac - FLAC binaries';
	TaskList = 'associate - Enable Explorer context menu integration for CUE sheets, modifypath - Add AutoFLAC to your system path';
#include "..\..\clihelp\clihelp.iss"

function ModPathDir(): String;
begin
	Result := ExpandConstant('{app}');
end;
#include "..\..\modpath\modpath.iss"
