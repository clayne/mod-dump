unit mdConfiguration;

interface

uses
  SysUtils, Classes,
  // mte units
  mteHelpers, CRC32, RttiIni,
  // xedit units
  wbInterface, wbDefinitionsFO4, wbDefinitionsTES5, wbDefinitionsTES4,
  wbDefinitionsFNV, wbDefinitionsFO3;

type
  TGameMode = Record
    longName: string;
    gameName: string;
    gameMode: TwbGameMode;
    appName: string;
    exeName: string;
    appIDs: string;
    abbrName: string;
  end;
  TSettings = class(TObject)
  public
    [IniSection('General')]
    dummyPluginPath: string;
    pluginsPath: string;
    dumpPath: string;
    language: string;
    bPrintHashes: boolean;
    constructor Create; virtual;
    procedure UpdateForGame;
  end;
  TProgramStatus = class(TObject)
  public
    bUsedDummyPlugins: boolean;
    ProgramVersion: string;
    GameMode: TGameMode;
    constructor Create; virtual;
  end;

  function SetGameParam(param: string): boolean;
  procedure LoadSettings;
  procedure SaveSettings;

var
  ProgramStatus: TProgramStatus;
  PathList: TStringList;
  settings: TSettings;
  dummyPluginHash: string;

const
  // GAME MODES
  GameArray: array[1..5] of TGameMode = (
    ( longName: 'Skyrim'; gameName: 'Skyrim'; gameMode: gmTES5;
      appName: 'TES5'; exeName: 'TESV.exe'; appIDs: '72850';
      abbrName: 'sk'; ),
    ( longName: 'Oblivion'; gameName: 'Oblivion'; gameMode: gmTES4;
      appName: 'TES4'; exeName: 'Oblivion.exe'; appIDs: '22330,900883';
      abbrName: 'ob'; ),
    ( longName: 'Fallout New Vegas'; gameName: 'FalloutNV'; gameMode: gmFNV;
      appName: 'FNV'; exeName: 'FalloutNV.exe'; appIDs: '22380,2028016';
      abbrName: 'fnv'; ),
    ( longName: 'Fallout 3'; gameName: 'Fallout3'; gameMode: gmFO3;
      appName: 'FO3'; exeName: 'Fallout3.exe'; appIDs: '22300,22370';
      abbrName: 'fo3'; ),
    ( longName: 'Fallout 4'; gameName: 'Fallout4'; gameMode: gmFO4;
      appName: 'FO4'; exeName: 'Fallout4.exe'; appIDs: '377160';
      abbrName: 'fo4'; )
  );

implementation


{ TSettings }
constructor TSettings.Create;
begin
  // default settings
  dummyPluginPath := '{{gameName}}\plugins\EmptyPlugin.esp';
  pluginsPath := '{{gameName}}\plugins\';
  dumpPath := '{{gameName}}\dumps\';
  language := 'English';
  bPrintHashes := false;
end;

procedure TSettings.UpdateForGame;
var
  slMap: TStringList;
begin
  slMap := TStringList.Create;
  try
    // load values into map
    slMap.Values['gameName'] := ProgramStatus.GameMode.gameName;
    slMap.Values['longName'] := ProgramStatus.GameMode.longName;
    slMap.Values['appName'] := ProgramStatus.GameMode.appName;
    slMap.Values['abbrName'] := ProgramStatus.GameMode.abbrName;

    // apply template
    dummyPluginPath := PathList.Values['ProgramPath'] + ApplyTemplate(dummyPluginPath, slMap);
    pluginsPath := PathList.Values['ProgramPath'] + ApplyTemplate(pluginsPath, slMap);
    dumpPath := PathList.Values['ProgramPath'] + ApplyTemplate(dumpPath, slMap);

    // force directories to exist
    ForceDirectories(pluginsPath);
    ForceDirectories(dumpPath);

    // update empty plugin hash if empty plugin exists
    if FileExists(dummyPluginPath) then
      dummyPluginHash := FileCRC32(dummyPluginPath);
  finally
    slMap.Free;
  end;
end;

{ TProgramStatus }
constructor TProgramStatus.Create;
begin
  bUsedDummyPlugins := false;
  ProgramVersion := GetVersionMem;
end;

{ Sets the game mode in the TES5Edit API }
procedure SetGame(id: integer);
begin
  // update our vars
  ProgramStatus.GameMode := GameArray[id];
  settings.UpdateForGame;

  // update xEdit vars
  wbGameName := ProgramStatus.GameMode.gameName;
  wbGameMode := ProgramStatus.GameMode.gameMode;
  wbAppName := ProgramStatus.GameMode.appName;
  wbDataPath := settings.pluginsPath;
  wbVWDInTemporary := wbGameMode in [gmTES5, gmFO3, gmFNV];
  wbDisplayLoadOrderFormID := True;
  wbSortSubRecords := True;
  wbDisplayShorterNames := True;
  wbHideUnused := True;
  wbFlagsAsArray := True;
  wbRequireLoadOrder := True;
  wbLanguage := settings.language;
  wbEditAllowed := True;
  wbLoaderDone := True;

  // load definitions
  case wbGameMode of
    gmFO4: DefineFO4;
    gmTES5: DefineTES5;
    gmFNV: DefineFNV;
    gmTES4: DefineTES4;
    gmFO3: DefineFO3;
  end;
end;

function SetGameParam(param: string): boolean;
var
  abbrName: string;
  i: Integer;
begin
  Result := false;
  abbrName := Copy(param, 2, Length(param));
  for i := Low(GameArray) to High(GameArray) do
    if GameArray[i].abbrName = abbrName then begin
      SetGame(i);
      Result := true;
      exit;
    end;
end;

procedure LoadSettings;
begin
  settings := TSettings.Create;
  TRttiIni.Load(PathList.Values['ProgramPath'] + 'settings.ini', settings);
end;

procedure SaveSettings;
begin
  TRttiIni.Save(PathList.Values['ProgramPath'] + 'settings.ini', settings);
end;

initialization
begin
  ProgramStatus := TProgramStatus.Create;
  PathList := TStringList.Create;
end;

finalization
begin
  ProgramStatus.Free;
  PathList.Free;
end;

end.
