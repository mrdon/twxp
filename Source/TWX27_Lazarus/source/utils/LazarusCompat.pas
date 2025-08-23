unit LazarusCompat;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, Process
  {$IFDEF WINDOWS}
  , Windows, Registry, ScktComp, Messages
  {$ENDIF}
  {$IFDEF UNIX}
  , BaseUnix, Unix, LMessages
  {$ENDIF}
  ;

// Cross-platform path separator
const
  {$IFDEF WINDOWS}
  PathSep = '\';
  {$ELSE}
  PathSep = '/';
  {$ENDIF}

// Cross-platform configuration class
type
  TTWXConfig = class
  private
    {$IFDEF WINDOWS}
    FRegistry: TRegistry;
    FUseRegistry: Boolean;
    {$ENDIF}
    FConfigFile: TIniFile;
    function GetConfigDir: string;
    function GetUserConfigFile: string;
  public
    constructor Create;
    destructor Destroy; override;
    
    function ReadString(const Section, Key, Default: string): string;
    function WriteString(const Section, Key, Data: string): Boolean;
    function ReadInteger(const Section, Key: string; Default: Integer): Integer;
    function WriteInteger(const Section, Key: string; Data: Integer): Boolean;
    function ReadBool(const Section, Key: string; Default: Boolean): Boolean;
    function WriteBool(const Section, Key: string; Data: Boolean): Boolean;
  end;

// Windows API compatibility functions
{$IFNDEF WINDOWS}
function GetCurrentDir: string;
function DirectoryExists(const Directory: string): Boolean;
function CreateDir(const Dir: string): Boolean;
{$ENDIF}

// Cross-platform system functions
function TWX_GetCurrentProcessId: Cardinal;
function TWX_GetSystemInfo: string;
function TWX_GetUserDir: string;
function TWX_GetAppDataDir: string;
function TWX_GetConfigDir: string;

// Cross-platform process operations
function TWX_OpenProcess(ProcessId: Cardinal): Cardinal;
function TWX_TerminateProcess(ProcessHandle, ProcessId: Cardinal): Boolean;
function TWX_CloseHandle(Handle: Cardinal): Boolean;

// Cross-platform file operations (Windows API compatible)
function TWX_CreateFile(const FileName: string; DesiredAccess, ShareMode: Cardinal): Cardinal;
function TWX_QueryPerformanceFrequency(var Frequency: Int64): Boolean;
function TWX_QueryPerformanceCounter(var Counter: Int64): Boolean;

// Cross-platform UI operations
procedure TWX_ShowMessage(const Msg: string);
procedure TWX_PlaySound(const SoundFile: string);
function TWX_ShellExecute(const FileName: string): Boolean;
function TWX_CopyFile(const Source, Dest: string): Boolean;
function TWX_GetFileTime(const FileName: string): TDateTime;
procedure TWX_SetForegroundWindow(WindowHandle: PtrUInt);

// Cross-platform memory operations  
procedure TWX_ZeroMemory(Destination: Pointer; Length: PtrUInt);
procedure TWX_CopyMemory(Destination, Source: Pointer; Length: PtrUInt);

// Cross-platform authentication socket operations
type
  TTWXAuthSocket = class
  private
    {$IFDEF WINDOWS}
    FWinSocket: TClientSocket;
    {$ELSE}
    // Could use Synapse TCPBlockSocket or other cross-platform socket
    FConnected: Boolean;
    FHost: string;
    FPort: Integer;
    {$ENDIF}
    FOnConnect: TNotifyEvent;
    FOnRead: TNotifyEvent; 
    FOnError: TNotifyEvent;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure Connect;
    procedure Disconnect;
    procedure Open;
    procedure Close;
    procedure SendText(const Text: string);
    function ReceiveText: string;
    
    property Host: string read FHost write FHost;
    property Port: Integer read FPort write FPort;
    property Address: string read FHost write FHost;  // Alias for Host
    function GetConnected: Boolean;
    property Connected: Boolean read GetConnected;
    property OnConnect: TNotifyEvent read FOnConnect write FOnConnect;
    property OnRead: TNotifyEvent read FOnRead write FOnRead;
    property OnError: TNotifyEvent read FOnError write FOnError;
  end;

// Cross-platform file operations
function TWX_DirectoryExists(const Directory: string): Boolean;
function TWX_CreateDir(const Dir: string): Boolean;
function TWX_SetFileReadOnly(const FileName: string; ReadOnly: Boolean): Boolean;
function TWX_GetFileSize(const FileName: string): Int64;
function TWX_FileExists(const FileName: string): Boolean;

// Cross-platform hardware identification (replaces registry-based)
function TWX_GetHardwareID1: Cardinal;
function TWX_GetHardwareID2: Cardinal;
function TWX_GetMachineGUID: string;

// String utility functions
function StrToIntSafe(const S: string): Integer;
function StripFileExtension(const FileName: string): string;
function ShortFilename(const FileName: string): string;

implementation

// TTWXConfig implementation

constructor TTWXConfig.Create;
begin
  {$IFDEF WINDOWS}
  FUseRegistry := True;
  FRegistry := TRegistry.Create;
  FRegistry.RootKey := HKEY_CURRENT_USER;
  {$ELSE}
  ForceDirectories(GetConfigDir);
  FConfigFile := TIniFile.Create(GetUserConfigFile);
  {$ENDIF}
end;

destructor TTWXConfig.Destroy;
begin
  {$IFDEF WINDOWS}
  if Assigned(FRegistry) then
    FRegistry.Free;
  {$ELSE}
  if Assigned(FConfigFile) then
    FConfigFile.Free;
  {$ENDIF}
  inherited Destroy;
end;

function TTWXConfig.GetConfigDir: string;
begin
  {$IFDEF WINDOWS}
  Result := GetEnvironmentVariable('APPDATA') + PathSep + 'TWXProxy';
  {$ELSE}
  Result := GetEnvironmentVariable('HOME') + '/.config/twxproxy';
  {$ENDIF}
end;

function TTWXConfig.GetUserConfigFile: string;
begin
  Result := GetConfigDir + PathSep + 'twxproxy.ini';
end;

function TTWXConfig.ReadString(const Section, Key, Default: string): string;
begin
  {$IFDEF WINDOWS}
  if FUseRegistry then
  begin
    if FRegistry.OpenKeyReadOnly(Section) then
    begin
      if FRegistry.ValueExists(Key) then
        Result := FRegistry.ReadString(Key)
      else
        Result := Default;
      FRegistry.CloseKey;
    end
    else
      Result := Default;
  end
  else
  {$ENDIF}
  begin
    Result := FConfigFile.ReadString(Section, Key, Default);
  end;
end;

function TTWXConfig.WriteString(const Section, Key, Data: string): Boolean;
begin
  Result := True;
  try
    {$IFDEF WINDOWS}
    if FUseRegistry then
    begin
      if FRegistry.OpenKey(Section, True) then
      begin
        FRegistry.WriteString(Key, Data);
        FRegistry.CloseKey;
      end
      else
        Result := False;
    end
    else
    {$ENDIF}
    begin
      FConfigFile.WriteString(Section, Key, Data);
    end;
  except
    Result := False;
  end;
end;

function TTWXConfig.ReadInteger(const Section, Key: string; Default: Integer): Integer;
begin
  {$IFDEF WINDOWS}
  if FUseRegistry then
  begin
    if FRegistry.OpenKeyReadOnly(Section) then
    begin
      if FRegistry.ValueExists(Key) then
        Result := FRegistry.ReadInteger(Key)
      else
        Result := Default;
      FRegistry.CloseKey;
    end
    else
      Result := Default;
  end
  else
  {$ENDIF}
  begin
    Result := FConfigFile.ReadInteger(Section, Key, Default);
  end;
end;

function TTWXConfig.WriteInteger(const Section, Key: string; Data: Integer): Boolean;
begin
  Result := True;
  try
    {$IFDEF WINDOWS}
    if FUseRegistry then
    begin
      if FRegistry.OpenKey(Section, True) then
      begin
        FRegistry.WriteInteger(Key, Data);
        FRegistry.CloseKey;
      end
      else
        Result := False;
    end
    else
    {$ENDIF}
    begin
      FConfigFile.WriteInteger(Section, Key, Data);
    end;
  except
    Result := False;
  end;
end;

function TTWXConfig.ReadBool(const Section, Key: string; Default: Boolean): Boolean;
begin
  {$IFDEF WINDOWS}
  if FUseRegistry then
  begin
    if FRegistry.OpenKeyReadOnly(Section) then
    begin
      if FRegistry.ValueExists(Key) then
        Result := FRegistry.ReadBool(Key)
      else
        Result := Default;
      FRegistry.CloseKey;
    end
    else
      Result := Default;
  end
  else
  {$ENDIF}
  begin
    Result := FConfigFile.ReadBool(Section, Key, Default);
  end;
end;

function TTWXConfig.WriteBool(const Section, Key: string; Data: Boolean): Boolean;
begin
  Result := True;
  try
    {$IFDEF WINDOWS}
    if FUseRegistry then
    begin
      if FRegistry.OpenKey(Section, True) then
      begin
        FRegistry.WriteBool(Key, Data);
        FRegistry.CloseKey;
      end
      else
        Result := False;
    end
    else
    {$ENDIF}
    begin
      FConfigFile.WriteBool(Section, Key, Data);
    end;
  except
    Result := False;
  end;
end;

// Windows API compatibility functions
{$IFNDEF WINDOWS}
function GetCurrentDir: string;
begin
  Result := SysUtils.GetCurrentDir;
end;

function DirectoryExists(const Directory: string): Boolean;
begin
  Result := SysUtils.DirectoryExists(Directory);
end;

function CreateDir(const Dir: string): Boolean;
begin
  Result := SysUtils.CreateDir(Dir);
end;
{$ENDIF}

// Cross-platform system functions
function TWX_GetCurrentProcessId: Cardinal;
begin
  {$IFDEF WINDOWS}
  Result := GetCurrentProcessId;
  {$ELSE}
  Result := FpGetpid;
  {$ENDIF}
end;

function TWX_GetSystemInfo: string;
begin
  {$IFDEF WINDOWS}
  Result := 'Windows';
  {$ENDIF}
  {$IFDEF LINUX}
  Result := 'Linux';
  {$ENDIF}
  {$IFDEF DARWIN}
  Result := 'macOS';
  {$ENDIF}
  {$IF not defined(WINDOWS) and not defined(LINUX) and not defined(DARWIN)}
  Result := 'Unknown OS';
  {$ENDIF}
end;

function TWX_GetUserDir: string;
begin
  {$IFDEF WINDOWS}
  Result := GetEnvironmentVariable('USERPROFILE');
  {$ELSE}
  Result := GetEnvironmentVariable('HOME');
  {$ENDIF}
  if Result = '' then
    Result := GetCurrentDir;
end;

function TWX_GetAppDataDir: string;
begin
  {$IFDEF WINDOWS}
  Result := GetEnvironmentVariable('APPDATA') + PathSep + 'TWXProxy';
  {$ELSE}
  Result := TWX_GetUserDir + '/.local/share/twxproxy';
  {$ENDIF}
end;

function TWX_GetConfigDir: string;
begin
  {$IFDEF WINDOWS}
  Result := GetEnvironmentVariable('APPDATA') + PathSep + 'TWXProxy';
  {$ELSE}
  Result := TWX_GetUserDir + '/.config/twxproxy';
  {$ENDIF}
end;

// Cross-platform file operations
function TWX_DirectoryExists(const Directory: string): Boolean;
begin
  Result := SysUtils.DirectoryExists(Directory);
end;

function TWX_CreateDir(const Dir: string): Boolean;
begin
  Result := ForceDirectories(Dir);
end;

function TWX_SetFileReadOnly(const FileName: string; ReadOnly: Boolean): Boolean;
{$IFDEF WINDOWS}
var
  Attrs: Cardinal;
{$ENDIF}
begin
  {$IFDEF WINDOWS}
  Attrs := GetFileAttributes(PChar(FileName));
  if Attrs <> INVALID_FILE_ATTRIBUTES then
  begin
    if ReadOnly then
      Attrs := Attrs or FILE_ATTRIBUTE_READONLY
    else
      Attrs := Attrs and not FILE_ATTRIBUTE_READONLY;
    Result := SetFileAttributes(PChar(FileName), Attrs);
  end
  else
    Result := False;
  {$ELSE}
  if ReadOnly then
    Result := FpChmod(FileName, S_IRUSR or S_IRGRP or S_IROTH) = 0
  else
    Result := FpChmod(FileName, S_IRUSR or S_IWUSR or S_IRGRP or S_IROTH) = 0;
  {$ENDIF}
end;

function TWX_GetFileSize(const FileName: string): Int64;
var
  F: File;
begin
  Result := -1;
  if TWX_FileExists(FileName) then
  begin
    try
      AssignFile(F, FileName);
      Reset(F, 1);
      Result := FileSize(F);
      CloseFile(F);
    except
      Result := -1;
    end;
  end;
end;

function TWX_FileExists(const FileName: string): Boolean;
begin
  Result := FileExists(FileName);
end;

// Cross-platform hardware identification (replaces registry-based)
function TWX_GetHardwareID1: Cardinal;
{$IFDEF LINUX}
var
  F: TextFile;
  Line: string;
  CPUInfo: string;
  I: Integer;
{$ENDIF}
begin
  Result := 30; // Default fallback
  
  {$IFDEF WINDOWS}
  // Use system UUID or CPU info
  // This is a simplified version - in production you'd use GetSystemInfo
  Result := 30 xor Cardinal(GetCurrentProcessId);
  {$ENDIF}
  
  {$IFDEF LINUX}
  try
    if FileExists('/proc/cpuinfo') then
    begin
      AssignFile(F, '/proc/cpuinfo');
      Reset(F);
      CPUInfo := '';
      while not Eof(F) do
      begin
        ReadLn(F, Line);
        if Pos('model name', Line) > 0 then
        begin
          CPUInfo := Line;
          Break;
        end;
      end;
      CloseFile(F);
      
      // Simple hash of CPU model name
      for I := 1 to Length(CPUInfo) do
        Result := Result xor Ord(CPUInfo[I]);
    end;
  except
    // Keep default value
  end;
  {$ENDIF}
  
  {$IFDEF DARWIN}
  // macOS implementation would use system_profiler or sysctl
  Result := 30 xor Cardinal(FpGetpid);
  {$ENDIF}
end;

function TWX_GetHardwareID2: Cardinal;
{$IFDEF LINUX}
var
  F: TextFile;
  MachineId: string;
  I: Integer;
{$ENDIF}
begin
  Result := 20; // Default fallback
  
  {$IFDEF WINDOWS}
  // Use another system identifier
  Result := 20 xor Cardinal(GetTickCount and $FFFF);
  {$ENDIF}
  
  {$IFDEF LINUX}
  try
    if FileExists('/etc/machine-id') then
    begin
      AssignFile(F, '/etc/machine-id');
      Reset(F);
      if not Eof(F) then
      begin
        ReadLn(F, MachineId);
        // Simple hash of machine ID
        for I := 1 to Length(MachineId) do
          Result := Result xor Ord(MachineId[I]);
      end;
      CloseFile(F);
    end;
  except
    // Keep default value
  end;
  {$ENDIF}
  
  {$IFDEF DARWIN}
  // macOS implementation
  Result := 20 xor Cardinal(FpGetpid shr 4);
  {$ENDIF}
end;

function TWX_GetMachineGUID: string;
{$IFDEF LINUX}
var
  F: TextFile;
{$ENDIF}
begin
  {$IFDEF WINDOWS}
  // On Windows, could read from registry HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Cryptography\MachineGuid
  Result := IntToHex(TWX_GetHardwareID1, 8) + '-' + IntToHex(TWX_GetHardwareID2, 8);
  {$ENDIF}
  
  {$IFDEF LINUX}
  try
    if FileExists('/etc/machine-id') then
    begin
      AssignFile(F, '/etc/machine-id');
      Reset(F);
      if not Eof(F) then
        ReadLn(F, Result)
      else
        Result := IntToHex(TWX_GetHardwareID1, 8) + '-' + IntToHex(TWX_GetHardwareID2, 8);
      CloseFile(F);
    end
    else
      Result := IntToHex(TWX_GetHardwareID1, 8) + '-' + IntToHex(TWX_GetHardwareID2, 8);
  except
    Result := IntToHex(TWX_GetHardwareID1, 8) + '-' + IntToHex(TWX_GetHardwareID2, 8);
  end;
  {$ENDIF}
  
  {$IFDEF DARWIN}
  // macOS implementation would use system_profiler SPHardwareDataType
  Result := IntToHex(TWX_GetHardwareID1, 8) + '-' + IntToHex(TWX_GetHardwareID2, 8);
  {$ENDIF}
end;

// String utility functions
function StrToIntSafe(const S: string): Integer;
begin
  try
    Result := StrToInt(S);
  except
    Result := 0;
  end;
end;

function StripFileExtension(const FileName: string): string;
begin
  Result := ChangeFileExt(FileName, '');
end;

function ShortFilename(const FileName: string): string;
begin
  Result := ExtractFileName(FileName);
end;

// Cross-platform process operations
function TWX_OpenProcess(ProcessId: Cardinal): Cardinal;
begin
  {$IFDEF WINDOWS}
  Result := OpenProcess(PROCESS_TERMINATE, FALSE, ProcessId);
  {$ELSE}
  // On Unix, we don't need handles for kill operations, just return the PID
  Result := ProcessId;
  {$ENDIF}
end;

function TWX_TerminateProcess(ProcessHandle, ProcessId: Cardinal): Boolean;
begin
  {$IFDEF WINDOWS}
  Result := TerminateProcess(ProcessHandle, 0);
  {$ELSE}
  // Use Unix kill signal
  Result := FpKill(ProcessId, SIGTERM) = 0;
  {$ENDIF}
end;

function TWX_CloseHandle(Handle: Cardinal): Boolean;
begin
  {$IFDEF WINDOWS}
  Result := CloseHandle(Handle);
  {$ELSE}
  // On Unix, no handle cleanup needed for our use case
  Result := True;
  {$ENDIF}
end;

// Cross-platform file operations (Windows API compatible)
function TWX_CreateFile(const FileName: string; DesiredAccess, ShareMode: Cardinal): Cardinal;
var
  F: File;
begin
  {$IFDEF WINDOWS}
  Result := CreateFile(PChar(FileName), DesiredAccess, ShareMode, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  {$ELSE}
  // Cross-platform file access check
  Result := Cardinal(-1); // INVALID_HANDLE_VALUE equivalent
  if FileExists(FileName) then
  begin
    try
      AssignFile(F, FileName);
      {$I-} // Disable I/O error checking
      Reset(F, 1);
      {$I+} // Enable I/O error checking
      if IOResult = 0 then
      begin
        CloseFile(F);
        Result := 1; // Success, return non-zero handle
      end;
    except
      // File access failed
    end;
  end;
  {$ENDIF}
end;

function TWX_QueryPerformanceFrequency(var Frequency: Int64): Boolean;
begin
  {$IFDEF WINDOWS}
  Result := QueryPerformanceFrequency(Frequency);
  {$ELSE}
  // On Unix, use a standard frequency (microseconds)
  Frequency := 1000000; // 1MHz equivalent
  Result := True;
  {$ENDIF}
end;

function TWX_QueryPerformanceCounter(var Counter: Int64): Boolean;
begin
  {$IFDEF WINDOWS}
  Result := QueryPerformanceCounter(Counter);
  {$ELSE}
  // On Unix, use system time in microseconds
  Counter := Round(Now * 24 * 60 * 60 * 1000000); // Convert to microseconds
  Result := True;
  {$ENDIF}
end;

// Cross-platform UI operations
procedure TWX_ShowMessage(const Msg: string);
begin
  {$IFDEF WINDOWS}
  MessageBox(0, PChar(Msg), 'Error', MB_ICONERROR or MB_OK);
  {$ELSE}
  // For console applications or cross-platform, write to stderr
  WriteLn(StdErr, 'Error: ', Msg);
  {$ENDIF}
end;

procedure TWX_PlaySound(const SoundFile: string);
begin
  {$IFDEF WINDOWS}
  // Use Windows PlaySound API
  {$ELSE}
  // On Unix, could use system command or just ignore
  // WriteLn('Sound: ', SoundFile); // Debug/placeholder
  {$ENDIF}
end;

function TWX_ShellExecute(const FileName: string): Boolean;
begin
  {$IFDEF WINDOWS}
  Result := ShellExecute(0, 'open', PChar(FileName), nil, nil, SW_SHOWNORMAL) > 32;
  {$ELSE}
  try
    Result := ExecuteProcess('xdg-open', [FileName]) = 0;
  except
    Result := False;
  end;
  {$ENDIF}
end;

function TWX_CopyFile(const Source, Dest: string): Boolean;
begin
  {$IFDEF WINDOWS}
  Result := CopyFile(PChar(Source), PChar(Dest), False);
  {$ELSE}
  try
    Result := ExecuteProcess('cp', [Source, Dest]) = 0;
  except
    Result := False;
  end;
  {$ENDIF}
end;

function TWX_GetFileTime(const FileName: string): TDateTime;
begin
  {$IFDEF WINDOWS}
  Result := FileDateToDateTime(FileAge(FileName));
  {$ELSE}
  Result := FileDateToDateTime(FileAge(FileName));
  {$ENDIF}
end;

procedure TWX_SetForegroundWindow(WindowHandle: PtrUInt);
begin
  {$IFDEF WINDOWS}
  SetForegroundWindow(WindowHandle);
  {$ELSE}
  // On Unix, this is typically handled by the window manager
  // Could use X11 calls here if needed
  {$ENDIF}
end;

// Cross-platform memory operations  
procedure TWX_ZeroMemory(Destination: Pointer; Length: PtrUInt);
begin
  FillChar(Destination^, Length, 0);
end;

procedure TWX_CopyMemory(Destination, Source: Pointer; Length: PtrUInt);
begin
  Move(Source^, Destination^, Length);
end;

// TTWXAuthSocket implementation
constructor TTWXAuthSocket.Create;
begin
  inherited Create;
  {$IFDEF WINDOWS}
  FWinSocket := TClientSocket.Create(nil);
  {$ELSE}
  FConnected := False;
  FHost := '';
  FPort := 80;
  {$ENDIF}
end;

destructor TTWXAuthSocket.Destroy;
begin
  {$IFDEF WINDOWS}
  if Assigned(FWinSocket) then
  begin
    FWinSocket.Active := False;
    FWinSocket.Free;
  end;
  {$ENDIF}
  inherited Destroy;
end;

function TTWXAuthSocket.GetConnected: Boolean;
begin
  {$IFDEF WINDOWS}
  Result := Assigned(FWinSocket) and FWinSocket.Active;
  {$ELSE}
  Result := FConnected;
  {$ENDIF}
end;

procedure TTWXAuthSocket.Connect;
begin
  {$IFDEF WINDOWS}
  if Assigned(FWinSocket) then
  begin
    FWinSocket.Host := FHost;
    FWinSocket.Port := FPort;
    FWinSocket.Active := True;
  end;
  {$ELSE}
  // Cross-platform implementation would use Synapse or other socket library
  // For now, just mark as connected for compilation
  FConnected := True;
  if Assigned(FOnConnect) then
    FOnConnect(Self);
  {$ENDIF}
end;

procedure TTWXAuthSocket.Disconnect;
begin
  {$IFDEF WINDOWS}
  if Assigned(FWinSocket) then
    FWinSocket.Active := False;
  {$ELSE}
  FConnected := False;
  {$ENDIF}
end;

procedure TTWXAuthSocket.Open;
begin
  Connect;  // Alias for Connect
end;

procedure TTWXAuthSocket.Close;
begin
  Disconnect;  // Alias for Disconnect
end;

procedure TTWXAuthSocket.SendText(const Text: string);
begin
  {$IFDEF WINDOWS}
  if Assigned(FWinSocket) and FWinSocket.Active then
    FWinSocket.Socket.SendText(Text);
  {$ELSE}
  // Cross-platform implementation would send via socket
  {$ENDIF}
end;

function TTWXAuthSocket.ReceiveText: string;
begin
  {$IFDEF WINDOWS}
  if Assigned(FWinSocket) and FWinSocket.Active then
    Result := FWinSocket.Socket.ReceiveText
  else
    Result := '';
  {$ELSE}
  // Cross-platform implementation would receive via socket
  Result := '';
  {$ENDIF}
end;

end.