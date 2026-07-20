[Setup]
AppName=ChessCreator
AppVersion=1.0.0
AppPublisher=ChessCreator Team
DefaultDirName={autopf}\ChessCreator
DefaultGroupName=ChessCreator
OutputDir=..\build\windows\x64\installer
OutputBaseFilename=ChessCreator_Installer
Compression=lzma
SolidCompression=yes
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\chesscreator.exe

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\chesscreator.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\ffmpeg.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs
Source: "..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\ChessCreator"; Filename: "{app}\chesscreator.exe"
Name: "{autodesktop}\ChessCreator"; Filename: "{app}\chesscreator.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\chesscreator.exe"; Description: "{cm:LaunchProgram,ChessCreator}"; Flags: nowait postinstall skipifsilent
