; Tzar Fix (GOG) - installer
; Build:  ISCC.exe /DAppVersion=1.0.0 /DPayloadDir=..\build\payload src\TzarFix.iss

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef PayloadDir
  #define PayloadDir "..\build\payload"
#endif
#define AppName "Tzar Fix (GOG)"

[Setup]
AppId={{6C1E8F3A-52B4-4F7B-9D3E-7A1F2C9B8E41}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=tzar-fix contributors
AppPublisherURL=https://github.com/Nestogr/tzar-windows11-fix
AppSupportURL=https://github.com/Nestogr/tzar-windows11-fix/issues
DefaultDirName={autopf}\TzarFix
DisableDirPage=yes
DefaultGroupName=Tzar Fix
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x86compatible x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir=..\dist
OutputBaseFilename=TzarFix-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ShowLanguageDialog=no
LanguageDetectionMethod=uilanguage
UninstallDisplayName={#AppName}
UninstallDisplayIcon={app}\tzarfix.ico
SetupLogging=yes
CloseApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[CustomMessages]
english.GamePageTitle=Tzar folder
english.GamePageDesc=Where is Tzar: The Burden of the Crown (GOG) installed?
english.GamePageSub=The fix will be applied to this folder. It must contain Tzar.exe.
english.GamePageLabel=Game folder:
english.NoTzarExe=Tzar.exe was not found in:%n%1%n%nChoose the folder where Tzar (GOG) is installed.
english.Applying=Applying the fix. Tzar will open for a few seconds twice to measure your devices; please do not touch anything...
english.FixFailed=The fix could not be completed:%n%n%1%n%nLog: %2
english.FixOkFinish=%1%n%nYou can start Tzar from GOG Galaxy as usual. If GOG Galaxy updates or verifies the game, run "Repair Tzar" from the Start menu.
english.FixFailFinish=The fix did NOT complete:%n%1%n%nLog: %2
english.PlayNow=Play Tzar now
english.RepairName=Repair Tzar
english.UninstFailed=Restoring the original configuration reported problems:%n%n%1%n%nLog: %2
english.TzarRunning=Tzar is running. Close the game and try again.
english.ReadyMemo=Game folder:%n      %1%n%nWhat will be done:%n      - Backup in %1\_tzarfix_backup%n      - Uninstall the GOG compatibility shim (EmulateHeap)%n      - Install cnc-ddraw (MIT, FunkyFr3sh)%n      - Adjust tzar.ini to the devices detected by the game

spanish.GamePageTitle=Carpeta de Tzar
spanish.GamePageDesc=¿Dónde está instalado Tzar: El Poder de la Corona (GOG)?
spanish.GamePageSub=El arreglo se aplicará en esta carpeta. Debe contener Tzar.exe.
spanish.GamePageLabel=Carpeta del juego:
spanish.NoTzarExe=No se encuentra Tzar.exe en:%n%1%n%nElige la carpeta donde está instalado Tzar (GOG).
spanish.Applying=Aplicando el arreglo. Tzar se abrirá unos segundos dos veces para medir tus dispositivos; no toques nada...
spanish.FixFailed=No se pudo completar el arreglo:%n%n%1%n%nLog: %2
spanish.FixOkFinish=%1%n%nPuedes abrir Tzar desde GOG Galaxy como siempre. Si GOG Galaxy actualiza o verifica el juego, ejecuta "Reparar Tzar" desde el menú Inicio.
spanish.FixFailFinish=El arreglo NO se completó:%n%1%n%nLog: %2
spanish.PlayNow=Jugar ahora a Tzar
spanish.RepairName=Reparar Tzar
spanish.UninstFailed=La restauración de la configuración original dio problemas:%n%n%1%n%nLog: %2
spanish.TzarRunning=Tzar se está ejecutando. Cierra el juego y vuelve a intentarlo.
spanish.ReadyMemo=Carpeta del juego:%n      %1%n%nQué se hará:%n      - Copia de seguridad en %1\_tzarfix_backup%n      - Desinstalar el shim de compatibilidad de GOG (EmulateHeap)%n      - Instalar cnc-ddraw (MIT, FunkyFr3sh)%n      - Ajustar tzar.ini a los dispositivos que detecta el juego

[Files]
Source: "tzarfix.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "tzarfix.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PayloadDir}\cnc-ddraw\*"; DestDir: "{app}\cnc-ddraw"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\THIRD_PARTY_NOTICES.md"; DestDir: "{app}"; Flags: ignoreversion

[Registry]
Root: HKLM; Subkey: "SOFTWARE\TzarFix"; ValueType: string; ValueName: "GameDir"; ValueData: "{code:GetGameDir}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\TzarFix"; ValueType: string; ValueName: "InstallDir"; ValueData: "{app}"

[Icons]
Name: "{autoprograms}\{cm:RepairName}"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\tzarfix.ps1"" -Action Repair"; \
  WorkingDir: "{app}"; IconFilename: "{app}\tzarfix.ico"; Comment: "{cm:RepairName}"

[Run]
Filename: "{code:GetGameDir}\Tzar.exe"; WorkingDir: "{code:GetGameDir}"; Description: "{cm:PlayNow}"; \
  Flags: postinstall nowait skipifsilent runasoriginaluser unchecked; Check: FixSucceeded

[Code]
const
  GogKey = 'SOFTWARE\GOG.com\Games\1207659252';

var
  GamePage: TInputDirWizardPage;
  FixCode: Integer;
  FixMessage: String;

function HasTzar(const Dir: String): Boolean;
begin
  Result := (Dir <> '') and FileExists(AddBackslash(Dir) + 'Tzar.exe');
end;

function CleanDir(const Dir: String): String;
begin
  Result := RemoveBackslashUnlessRoot(Trim(Dir));
end;

function TryRegDir(RootKey: Integer; const SubKey, ValueName: String; var Dir: String): Boolean;
var S: String;
begin
  Result := False;
  if RegQueryStringValue(RootKey, SubKey, ValueName, S) then
  begin
    S := CleanDir(S);
    if HasTzar(S) then begin Dir := S; Result := True; end;
  end;
end;

function FindGameDir: String;
var
  Candidates: TArrayOfString;
  I: Integer;
begin
  Result := '';
  if TryRegDir(HKLM, 'SOFTWARE\TzarFix', 'GameDir', Result) then Exit;
  if TryRegDir(HKLM32, GogKey, 'path', Result) then Exit;
  if IsWin64 and TryRegDir(HKLM64, GogKey, 'path', Result) then Exit;
  if TryRegDir(HKCU, 'Software\Haemimont\Tzar', 'Path', Result) then Exit;
  if TryRegDir(HKLM32, 'SOFTWARE\Haemimont Games\Tzar Excalibur', 'Path', Result) then Exit;

  SetArrayLength(Candidates, 8);
  Candidates[0] := ExpandConstant('{commonpf32}\GOG Galaxy\Games\Tzar');
  Candidates[1] := ExpandConstant('{commonpf}\GOG Galaxy\Games\Tzar');
  Candidates[2] := ExpandConstant('{sd}\GOG Games\Tzar');
  Candidates[3] := ExpandConstant('{sd}\GOG Games\Tzar - The Burden of the Crown');
  Candidates[4] := ExpandConstant('{sd}\GOG\Tzar');
  Candidates[5] := ExpandConstant('{commonpf32}\GOG.com\Tzar');
  Candidates[6] := ExpandConstant('{commonpf32}\GOG Games\Tzar');
  Candidates[7] := ExpandConstant('{sd}\Games\Tzar');
  for I := 0 to GetArrayLength(Candidates) - 1 do
    if HasTzar(Candidates[I]) then begin Result := Candidates[I]; Exit; end;
end;

function GetGameDir(Param: String): String;
begin
  Result := CleanDir(GamePage.Values[0]);
end;

function FixSucceeded: Boolean;
begin
  Result := (FixCode = 0) or (FixCode = 2);
end;

procedure InitializeWizard;
var Dir: String;
begin
  FixCode := -1;
  GamePage := CreateInputDirPage(wpWelcome, CustomMessage('GamePageTitle'), CustomMessage('GamePageDesc'),
    CustomMessage('GamePageSub'), False, '');
  GamePage.Add(CustomMessage('GamePageLabel'));
  Dir := FindGameDir;
  if Dir = '' then Dir := ExpandConstant('{commonpf32}\GOG Galaxy\Games\Tzar');
  GamePage.Values[0] := Dir;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = GamePage.ID then
  begin
    if not HasTzar(GetGameDir('')) then
    begin
      MsgBox(FmtMessage(CustomMessage('NoTzarExe'), [GetGameDir('')]), mbError, MB_OK);
      Result := False;
    end;
  end;
end;

function UpdateReadyMemo(Space, NewLine, MemoUserInfoInfo, MemoDirInfo, MemoTypeInfo,
  MemoComponentsInfo, MemoGroupInfo, MemoTasksInfo: String): String;
begin
  Result := FmtMessage(CustomMessage('ReadyMemo'), [GetGameDir('')]);
end;

function PowerShellExe: String;
begin
  Result := ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe');
end;

function TzarIsRunning: Boolean;
var RC: Integer;
begin
  Result := Exec(PowerShellExe,
    '-NoProfile -Command "if (Get-Process -Name Tzar -ErrorAction SilentlyContinue) { exit 3 } else { exit 0 }"',
    '', SW_HIDE, ewWaitUntilTerminated, RC) and (RC = 3);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  if TzarIsRunning then Result := CustomMessage('TzarRunning');
end;

function InitializeUninstall: Boolean;
begin
  Result := True;
  if TzarIsRunning then
  begin
    if not UninstallSilent then MsgBox(CustomMessage('TzarRunning'), mbError, MB_OK);
    Result := False;
  end;
end;

function RunFixScript(const Action, GameDir: String; var Msg: String): Integer;
var
  ResultFile, Params: String;
  Lines: TArrayOfString;
  RC: Integer;
begin
  ResultFile := ExpandConstant('{tmp}\tzarfix_result.txt');
  DeleteFile(ResultFile);
  Params := '-NoProfile -ExecutionPolicy Bypass -File "' + ExpandConstant('{app}\tzarfix.ps1') + '"' +
    ' -Action ' + Action + ' -GameDir "' + GameDir + '"' +
    ' -Payload "' + ExpandConstant('{app}\cnc-ddraw') + '"' +
    ' -ResultFile "' + ResultFile + '" -Lang ' + ActiveLanguage;
  Log('Running: ' + PowerShellExe + ' ' + Params);
  if not Exec(PowerShellExe, Params, ExpandConstant('{app}'), SW_HIDE, ewWaitUntilTerminated, RC) then
  begin
    Msg := SysErrorMessage(RC);
    Result := 1;
    Exit;
  end;
  Result := RC;
  Msg := '';
  if LoadStringsFromFile(ResultFile, Lines) and (GetArrayLength(Lines) >= 2) then
  begin
    Result := StrToIntDef(Trim(Lines[0]), RC);
    Msg := Lines[1];
  end;
  Log(Format('Result %d: %s', [Result, Msg]));
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    WizardForm.StatusLabel.Caption := CustomMessage('Applying');
    WizardForm.FilenameLabel.Caption := '';
    FixCode := RunFixScript('Install', GetGameDir(''), FixMessage);
    if (FixCode <> 0) and (FixCode <> 2) and not WizardSilent then
      MsgBox(FmtMessage(CustomMessage('FixFailed'), [FixMessage, GetGameDir('') + '\_tzarfix_backup\log.txt']), mbError, MB_OK);
  end;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = wpFinished then
  begin
    if FixSucceeded then
      WizardForm.FinishedLabel.Caption := FmtMessage(CustomMessage('FixOkFinish'), [FixMessage])
    else
      WizardForm.FinishedLabel.Caption := FmtMessage(CustomMessage('FixFailFinish'), [FixMessage, GetGameDir('') + '\_tzarfix_backup\log.txt']);
    WizardForm.FinishedLabel.AutoSize := False;
    WizardForm.FinishedLabel.Height := ScaleY(150);
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  GameDir, Msg: String;
  RC: Integer;
begin
  if CurUninstallStep = usUninstall then
  begin
    if RegQueryStringValue(HKLM, 'SOFTWARE\TzarFix', 'GameDir', GameDir) and HasTzar(GameDir) then
    begin
      RC := RunFixScript('Uninstall', CleanDir(GameDir), Msg);
      if (RC = 1) and not UninstallSilent then
        MsgBox(FmtMessage(CustomMessage('UninstFailed'), [Msg, GameDir + '\_tzarfix_backup\log.txt']), mbError, MB_OK);
    end;
  end;
end;
