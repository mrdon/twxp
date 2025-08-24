{
Copyright (C) 2005  Remco Mulder

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

For source notes please refer to Notes.txt
For license terms please refer to GPL.txt.

These files should be stored in the root of the compression you 
received this source in.
}
{$mode delphi}{$H+}
program TWXProxy;

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, // LCL widgetset
  Classes,
  SysUtils,
  Forms,
  Dialogs,
  FileCtrl,
  LazarusCompat,
  FormMain,
  FormSetup,
  TWXProcess,
  Script,
  Menu,
  Database,
  Utility,
  FormHistory,
  Bubble,
  Log,
  ScriptCmd,
  TWXExport,
  ScriptCmp,
  Ansi,
  ScriptRef,
  FormAbout,
  TCP,
  FormScript,
  core,
  Global,
  Persistence,
  GUI,
  Observer;

{$R *.res}

type
  TModuleClass = class of TTWXModule;
  TModuleType = (mtDatabase, mtBubble, mtExtractor, mtMenu, mtServer, mtInterpreter, mtClient, mtLog, mtGUI);

  // TMessageHandler: Cross-platform message handling
  TMessageHandler = class(TObject)
  public
    {$IFDEF WINDOWS}
    procedure OnApplicationMessage(var Msg: TMsg; var Handled: Boolean);
    {$ENDIF}
  end;

const
  // ModuleClasses: Must line up with TModuleType for constructors to work properly
  ModuleClasses: array[TModuleType] of TModuleClass = (TModDatabase, TModBubble, TModExtractor, TModMenu, TModServer, TModInterpreter, TModClient, TModLog, TModGUI);

var
  PersistenceManager: TPersistenceManager;
  MessageHandler: TMessageHandler;
  ProgramDir: string;

function ModuleFactory(Module: TModuleType): TTWXModule;
var
  Globals: ITWXGlobals;
begin
  Result := ModuleClasses[Module].Create(Application, PersistenceManager);

  if (Result.GetInterface(ITWXGlobals, Globals)) then
  begin
    // set globals for this module
    Globals.ProgramDir := ProgramDir;
  end;

  // Not ideal.  This completely breaks the idea behind the factory method.  Having
  // all of these objects existing in a global scope destroys the modularity of
  // the application but is unfortunately necessary because of their current
  // interdependency.  The vision was to have each module abstracted through the
  // use of interfaces - I just never had time to pull this off.
  case Module of
    mtMenu: TWXMenu               := Result as TModMenu;
    mtDatabase: TWXDatabase       := Result as TModDatabase;
    mtLog: TWXLog                 := Result as TModLog;
    mtExtractor: TWXExtractor     := Result as TModExtractor;
    mtInterpreter: TWXInterpreter := Result as TModInterpreter;
    mtServer: TWXServer           := Result as TModServer;
    mtClient: TWXClient           := Result as TModClient;
    mtBubble: TWXBubble           := Result as TModBubble;
    mtGUI: TWXGUI                 := Result as TModGUI;
  end;
end;

{$HINTS OFF}
procedure InitProgram;
var
  I,
  Sectors   : Integer;
  DBName,
  Usage,
  Switch    : string;
  NewDB     : Boolean;
  ModuleType: TModuleType;
  S         : TSearchRec;
begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;  // EP - Enables new mem-manager to report leaks if Debug=TRUE
  {$ENDIF}
  Randomize;
  ProgramDir := GetCurrentDir;

  MessageHandler := TMessageHandler.Create;
  {$IFDEF WINDOWS}
  Application.OnMessage := MessageHandler.OnApplicationMessage;
  {$ENDIF}

  // Create dirs if they aren't there - cross-platform paths
  if not TWX_DirectoryExists(ProgramDir + PathDelim + 'data') then
    TWX_CreateDir(ProgramDir + PathDelim + 'data');

  if not TWX_DirectoryExists(ProgramDir + PathDelim + 'scripts') then
    TWX_CreateDir(ProgramDir + PathDelim + 'scripts');

  if not TWX_DirectoryExists(ProgramDir + PathDelim + 'logs') then
    TWX_CreateDir(ProgramDir + PathDelim + 'logs');

  PersistenceManager := TPersistenceManager.Create(Application);
  PersistenceManager.OutputFile := 'TWXSetup.dat';

  // call object constructors
  for ModuleType := Low(TModuleType) to High(TModuleType) do
    ModuleFactory(ModuleType);

  PersistenceManager.LoadStateValues;

  // check command line values
  I := 1;
  while (I <= ParamCount) do   
  begin
    Usage := 'Usage:' + LineEnding + 'twxproxy /p <port#> /dblist';
    Switch := UpperCase(ParamStr(I));
    
    if (Copy(Switch, 1, 2) = '/P') and (Length(Switch) > 2) then
    begin
      TWXServer.ListenPort := StrToIntSafe(Copy(Switch, 3, Length(Switch)));
    end

    // EP - New Switches
    // Single Parameters
    else if (Switch = '/DBLIST') then
    begin
      // List Database Files
      WriteLn('You specified /dblist' + LineEnding);
      SetCurrentDir(ProgramDir);
      if (FindFirst('data' + PathDelim + '*.xdb', faAnyFile, S) = 0) then
      begin
        repeat
          WriteLn(S.Name);
        until (FindNext(S) <> 0);
        FindClose(S);
      end;
      Exit;
    end

    // Multiple Parameters
    else if (ParamCount > I) then
    begin
      Inc(I);
      // Alternate syntax for listening port, e.g. "twxproxy /p 2002"
      if Switch = '/P' then
      begin
        TWXServer.ListenPort := StrToIntSafe(ParamStr(I));
      end
      else if Switch = '/DBCREATE' then // Create a new Database
      begin
        // Get Database Name
        DBName := ParamStr(I);
        NewDB := TRUE;
      end
      else if Switch = '/SECTORS' then
      begin
        try
          Sectors := StrToIntSafe(ParamStr(I));
          NewDB := TRUE;
        except
          TWXServer.Broadcast(Usage);
        end;
      end
      else if Switch = '/SCRIPT' then
      begin
        // Launch the specified script
      end;
    end; // End Multi-Parameters
  Inc(I);
  end; // End While (I <= ParamCount)
end;
{$HINTS ON}

procedure FinaliseProgram;
begin
  PersistenceManager.SaveStateValues;

  // More hacks ... force a destruction order using global variables to prevent
  // AVs on exit (some modules have extra processing on shutdown)
  // Note that modules not freed here are owned by the application object anyway -
  // so they will be freed implicitly.
  TWXInterpreter.Free;
  TWXGUI.Free;
  TWXClient.Free;
  TWXServer.Free;
  TWXLog.Free;
  TWXMenu.Free;
  TWXDatabase.Free;
  TWXBubble.Free;
  TWXExtractor.Free;

  MessageHandler.Free;
end;

{$IFDEF WINDOWS}
procedure TMessageHandler.OnApplicationMessage(var Msg: TMsg; var Handled: Boolean);
var
  NotificationEvent: TNotificationEvent;
begin
  if (Msg.Message = WM_USER) and (Msg.wParam <> 47806) then
  begin
    if (Msg.wParam = 47806) then //47806 = $BABE, still unsure what the cause is
    begin
      Dispose(Pointer(Msg.wParam)); // There appears to be no side effects to dismissing it
    end
    else
    begin
      // Dispatch message to the object its meant for
      NotificationEvent := TNotificationEvent(Pointer(Msg.wParam)^);
      NotificationEvent(Pointer(Msg.lParam));
      Dispose(Pointer(Msg.wParam));
    end;

    Handled := True;
  end;
end;
{$ENDIF}

begin
  Application.Initialize;
  Application.Title := 'TWX Proxy Server';
  SetCurrentDir(ExtractFilePath(ParamStr(0))); // Cross-platform path
  InitProgram;
  
  // EP - The Server ListenPort is persisted by the database now, so load from there
  if TWXDatabase.DataBaseOpen then
    TWXServer.ListenPort := TWXDatabase.DBHeader.ServerPort
  else
    TWXServer.ListenPort := 23;

  TWXServer.Activate;

  try
    // we don't use the TApplication message loop, as it requires a main form
    repeat
      Application.ProcessMessages;
      Sleep(10); // Prevent 100% CPU usage
    until Application.Terminated;
  finally
    FinaliseProgram;
  end;
end.