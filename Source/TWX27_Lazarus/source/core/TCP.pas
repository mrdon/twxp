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
unit TCP;

interface

uses
  SysUtils,
  Classes,
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SyncObjs,
  LazarusCompat,
  {$IFDEF FPC}
  ExtCtrls,
  {$ELSE}
  ExtCtrls,
  {$ENDIF}
  Database,
  Core,
  {$IFDEF WINDOWS}
  Windows,
  ScktComp
  {$ELSE}
  // Cross-platform networking with Synapse
  blcksock,
  synsock,
  synautil
  {$ENDIF};

const
  OP_SB   = #250;
  OP_WILL = #251;
  OP_WONT = #252;
  OP_DO   = #253;
  OP_DONT = #254;

type
  TClientType = (ctStandard, ctDeaf, ctRejected, ctMute, ctStream);
  TDisplayMode = (ctSilent, ctQuiet, ctNormal, ctVerbose);

  // Cross-platform socket wrapper interface
  ITWXSocket = interface
    ['{550E8400-E29B-41D4-A716-446655440000}']
    function SendText(const Data: string): Integer;
    function ReceiveBuf(var Buffer: array of Char; Count: Integer): Integer;
    function Connect(const Host: string; Port: Word): Boolean;
    procedure Disconnect;
    function Connected: Boolean;
    procedure Close;
  end;

    // Cross-platform socket event handler interface
  ITWXSocketEventHandler = interface
    ['{550E8401-E29B-41D4-A716-446655440000}']
    procedure OnSocketConnect(Socket: ITWXSocket);
    procedure OnSocketDisconnect(Socket: ITWXSocket);
    procedure OnSocketRead(Socket: ITWXSocket);
    procedure OnSocketError(Socket: ITWXSocket; ErrorCode: Integer);
  end;

  // Extended socket interface with event handling
  ITWXSocketEx = interface(ITWXSocket)
    ['{550E8402-E29B-41D4-A716-446655440000}']
    procedure SetEventHandler(Handler: ITWXSocketEventHandler);
    function GetRemoteAddress: string;
    procedure Listen(Port: Word);
    function Accept: ITWXSocketEx;
    procedure SetNonBlocking(Value: Boolean);
    function HasData: Boolean;
  end;

{$IFDEF WINDOWS}
  // Windows implementation using ScktComp
  TTWXWinSocket = class(TInterfacedObject, ITWXSocket)
  private
    FSocket: TCustomWinSocket;
    FOwnsSocket: Boolean;
  public
    constructor Create(Socket: TCustomWinSocket; OwnsSocket: Boolean = False);
    destructor Destroy; override;
    function SendText(const Data: string): Integer;
    function ReceiveBuf(var Buffer: array of Char; Count: Integer): Integer;
    function Connect(const Host: string; Port: Word): Boolean;
    procedure Disconnect;
    function Connected: Boolean;
    procedure Close;
  end;

  // Windows extended socket for server operations
  TTWXWinSocketEx = class(TTWXWinSocket, ITWXSocketEx)
  private
    FEventHandler: ITWXSocketEventHandler;
    FServerSocket: TServerSocket;
    FClientSocket: TClientSocket;
    FIsServer: Boolean;
  public
    constructor CreateServer(AOwner: TComponent);
    constructor CreateClient(AOwner: TComponent);
    destructor Destroy; override;
    procedure SetEventHandler(Handler: ITWXSocketEventHandler);
    function GetRemoteAddress: string;
    procedure Listen(Port: Word);
    function Accept: ITWXSocketEx;
    procedure SetNonBlocking(Value: Boolean);
    function HasData: Boolean;
    // Event handlers
    procedure HandleConnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure HandleDisconnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure HandleRead(Sender: TObject; Socket: TCustomWinSocket);
    procedure HandleError(Sender: TObject; Socket: TCustomWinSocket; ErrorEvent: TErrorEvent; var ErrorCode: Integer);
    procedure HandleWrite(Sender: TObject; Socket: TCustomWinSocket);
  end;
{$ELSE}
  // Linux implementation using Synapse
  TTWXSynapseSocket = class(TInterfacedObject, ITWXSocket)
  private
    FSocket: TTCPBlockSocket;
    FOwnsSocket: Boolean;
  public
    constructor Create(Socket: TTCPBlockSocket = nil);
    destructor Destroy; override;
    function SendText(const Data: string): Integer;
    function ReceiveBuf(var Buffer: array of Char; Count: Integer): Integer;
    function Connect(const Host: string; Port: Word): Boolean;
    procedure Disconnect;
    function Connected: Boolean;
    procedure Close;
  end;

  // Linux extended socket for server operations
  TTWXSynapseSocketEx = class(TTWXSynapseSocket, ITWXSocketEx)
  private
    FEventHandler: ITWXSocketEventHandler;
    FServerSocket: TTCPBlockSocket;
    FIsServer: Boolean;
    FPort: Word;
    FConnectedClients: TList;
    FClientLock: TCriticalSection;
  protected
    procedure AddClient(Client: ITWXSocketEx);
    procedure RemoveClient(Client: ITWXSocketEx);
    function GetClientCount: Integer;
  public
    constructor CreateServer;
    constructor CreateClient;
    constructor CreateFromSocket(Socket: TTCPBlockSocket);
    destructor Destroy; override;
    procedure SetEventHandler(Handler: ITWXSocketEventHandler);
    function GetRemoteAddress: string;
    procedure Listen(Port: Word);
    function Accept: ITWXSocketEx;
    procedure SetNonBlocking(Value: Boolean);
    function HasData: Boolean;
  end;
{$ENDIF}

  TTelnetSocket = class(TTWXModule)
  type
    TFunc = (None, IAC, Op, Sub, Command, Done); // EP - Set here to persist between receives
  private
    FOptionSent : array[0..255] of Boolean;
    function ProcessTelnet(S : string; Socket : ITWXSocket) : string;
  end;

  TTelnetServerSocket = class(TTelnetSocket)
  private
    tcpServer : ITWXSocketEx;
  end;

  TTelnetClientSocket = class(TTelnetSocket)
  private
    tcpClient : ITWXSocketEx;
  end;

  // Thread for handling individual client connections
  TClientHandlerThread = class(TThread)
  private
    FClientSocket: ITWXSocket;
    FEventHandler: ITWXSocketEventHandler;
  protected
    procedure Execute; override;
  public
    constructor Create(ClientSocket: ITWXSocket; EventHandler: ITWXSocketEventHandler);
    destructor Destroy; override;
  end;

  // Thread for accepting incoming connections
  TServerAcceptThread = class(TThread)
  private
    FServerSocket: ITWXSocketEx;
    FEventHandler: ITWXSocketEventHandler;
    FClientThreads: TList;
  protected
    procedure Execute; override;
  public
    constructor Create(ServerSocket: ITWXSocketEx; EventHandler: ITWXSocketEventHandler);
    destructor Destroy; override;
    procedure StopAllClients;
  end;

  TQuickText = class
  private
    Search : string;
    Replace : string;
  end;

  TCP437 = class
  private
    Search : string;
    Replace : string;
    Mode : Integer;
  end;


  TModServer = class(TTelnetServerSocket, IModServer, ITWXSocketEventHandler)
  private
    FClientTypes     : array[0..255] of TClientType;
    FClientEchoMarks : array[0..255] of Boolean;
    FCurrentClient   : Integer;
    FBufferOut       : TStringList;
    FBufTimer        : TTimer;
    FStreamEnabled,
    FAllowLerkers    : Boolean;
    FLerkerAddress   : String;
    FAcceptExternal  : Boolean;
    FExternalAddress : String;
    FBroadCastMsgs   : Boolean;
    FLocalEcho       : Boolean;

    // Client connection tracking for cross-platform
    FConnectedClients : TList;
    FClientLock : TCriticalSection;  // Thread safety for client list access
    FAcceptThread : TServerAcceptThread;

    // MB - Strings to hold TW2002 color codes and user color codes
    SystemQuickText, UserQuickText, CP437Text : TList ;
    CP437Mode : Integer;


  private
    function GetClientType(Index : Integer) : TClientType;
    procedure SetClientType(Index : Integer; Value : TClientType);
    function GetClientCount : Integer;
    function GetClientAddress(Index : Integer) : string;
    function GetSocketIndex(S : ITWXSocket) : Integer;
    function GetListenPort: Word;
    procedure SetListenPort(Value: Word);

    { IModServer }
    function GetStreamEnabled: Boolean;
    procedure SetStreamEnabled(Value: Boolean);
    function GetAllowLerkers: Boolean;
    procedure SetAllowLerkers(Value: Boolean);
    function GetLerkerAddress: String;
    procedure SetLerkerAddress(Value: String);
    function GetAcceptExternal: Boolean;
    procedure SetAcceptExternal(Value: Boolean);
    function GetExternalAddress: String;
    procedure SetExternalAddress(Value: String);
    function GetBroadCastMsgs: Boolean;
    procedure SetBroadCastMsgs(Value: Boolean);
    function GetLocalEcho: Boolean;
    procedure SetLocalEcho(Value: Boolean);
    procedure AddSystemQuickText(Search, Replace : string);

  protected
    // Cross-platform event handlers
    // Internal event handling methods
    procedure HandleClientConnect(Socket: ITWXSocket);
    procedure HandleClientDisconnect(Socket: ITWXSocket);
    procedure HandleClientError(Socket: ITWXSocket; ErrorCode: Integer);
    procedure HandleClientRead(Socket: ITWXSocket);
    procedure OnBufTimer(Sender : TObject);

    // ITWXSocketEventHandler methods
    procedure OnSocketConnect(Socket: ITWXSocket);
    procedure OnSocketDisconnect(Socket: ITWXSocket);
    procedure OnSocketRead(Socket: ITWXSocket);
    procedure OnSocketError(Socket: ITWXSocket; ErrorCode: Integer);

  public
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;

    procedure Broadcast(Text : string; AMarkEcho : Boolean = TRUE; BroadcastDeaf : Boolean = FALSE; Buffered : Boolean = FALSE; CP437 : Boolean = FALSE);
    procedure ClientMessage(MessageText : string);
    procedure AddBuffer(Text : string);
    procedure StopVarDump;
    procedure NotifyScriptLoad;
    procedure NotifyScriptStop;

    procedure AddQuickText(Search, Replace : string);
    procedure ClearQuickText(Search : string = '');
    function ApplyQuickText(Text : string) : string;
    procedure AddCP437Text(Search, Replace : string; Mode : Integer = 0);
    function ApplyCP437Text(Text : string) : string;

    property ClientTypes[Index : Integer] : TClientType read GetClientType write SetClientType;
    property ClientCount : Integer read GetClientCount;
    property ClientAddresses[Index : Integer] : string read GetClientAddress;

    procedure Activate;
    procedure Deactivate;

  published
    property ListenPort: Word read GetListenPort write SetListenPort;
    property StreamEnabled: Boolean read GetStreamEnabled write SetStreamEnabled;
    property AllowLerkers: Boolean read GetAllowLerkers write SetAllowLerkers;
    property LerkerAddress: String read GetLerkerAddress write SetLerkerAddress;
    property AcceptExternal: Boolean read GetAcceptExternal write SetAcceptExternal;
    property ExternalAddress: String read GetExternalAddress write SetExternalAddress;
    property BroadCastMsgs: Boolean read GetBroadCastMsgs write SetBroadCastMsgs;
    property LocalEcho: Boolean read GetLocalEcho write SetLocalEcho;
  end;

  TModClient = class(TTelnetClientSocket, IModClient, ITWXSocketEventHandler)
  private
    tmrIdle,
    tmrReconnect    : TTimer;
    FFirstConnect,
    FReconnect,
    FUserDisconnect,
    FConnecting,
    FSendPending,
    FBlockExtended  : Boolean;
    FBytesSent,
    FReconnectDelay,
    FReconnectTock,
    FreconnectCount : Integer;
    FUnsentString   : String;
    IdleMinutes     : Integer;

  protected
    // ITWXSocketEventHandler methods
    procedure OnSocketConnect(Socket: ITWXSocket);
    procedure OnSocketDisconnect(Socket: ITWXSocket);
    procedure OnSocketRead(Socket: ITWXSocket);
    procedure OnSocketError(Socket: ITWXSocket; ErrorCode: Integer);
    
    // Legacy event handlers for internal use
    procedure HandleClientConnect(Socket: ITWXSocket);
    procedure HandleClientDisconnect(Socket: ITWXSocket);
    procedure HandleClientRead(Socket: ITWXSocket);
    procedure HandleClientError(Socket: ITWXSocket; ErrorCode: Integer);
    procedure tmrReconnectTimer(Sender: TObject);
    procedure tmrIdleTimer(Sender: TObject);

    function GetConnected : Boolean;

    { IModClient }
    function GetReconnect: Boolean;
    procedure SetReconnect(Value: Boolean);
    function GetReconnectDelay: Integer;
    procedure SetReconnectDelay(Value: Integer);

  public
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;

    procedure Send(Text : string);
    procedure Connect();
    procedure ConnectNow();
    procedure Disconnect;
    procedure CloseClient;

    property Connected : Boolean read GetConnected;

  published
    property Reconnect: Boolean read GetReconnect write SetReconnect;
    property ReconnectDelay: Integer read GetReconnectDelay write SetReconnectDelay;
    property BlockExtended: Boolean read FBlockExtended write FBlockExtended;
    property UserDisconnect: Boolean read FUserDisconnect write FUserDisconnect;
  end;

implementation

uses
  Global,
  Ansi,
  Utility,
  StrUtils,
  Dialogs,
  inifiles;

{$IFDEF WINDOWS}
// ***************** Windows Socket Implementation *********************

constructor TTWXWinSocket.Create(Socket: TCustomWinSocket; OwnsSocket: Boolean);
begin
  inherited Create;
  FSocket := Socket;
  FOwnsSocket := OwnsSocket;
end;

destructor TTWXWinSocket.Destroy;
begin
  if FOwnsSocket and Assigned(FSocket) then
    FSocket.Free;
  inherited;
end;

function TTWXWinSocket.SendText(const Data: string): Integer;
begin
  if Assigned(FSocket) then
    Result := FSocket.SendText(Data)
  else
    Result := 0;
end;

function TTWXWinSocket.ReceiveBuf(var Buffer: array of Char; Count: Integer): Integer;
begin
  if Assigned(FSocket) then
    Result := FSocket.ReceiveBuf(Buffer, Count)
  else
    Result := 0;
end;

function TTWXWinSocket.Connect(const Host: string; Port: Word): Boolean;
begin
  Result := False; // Base implementation doesn't support connect
end;

procedure TTWXWinSocket.Disconnect;
begin
  if Assigned(FSocket) then
    FSocket.Close;
end;

function TTWXWinSocket.Connected: Boolean;
begin
  Result := Assigned(FSocket) and FSocket.Connected;
end;

procedure TTWXWinSocket.Close;
begin
  Disconnect;
end;

// Extended Windows Socket Implementation
constructor TTWXWinSocketEx.CreateServer(AOwner: TComponent);
begin
  FIsServer := True;
  FServerSocket := TServerSocket.Create(AOwner);
  FServerSocket.OnClientConnect := HandleConnect;
  FServerSocket.OnClientDisconnect := HandleDisconnect;
  FServerSocket.OnClientRead := HandleRead;
  FServerSocket.OnClientError := HandleError;
  inherited Create(nil, False);
end;

constructor TTWXWinSocketEx.CreateClient(AOwner: TComponent);
begin
  FIsServer := False;
  FClientSocket := TClientSocket.Create(AOwner);
  FClientSocket.OnConnect := HandleConnect;
  FClientSocket.OnDisconnect := HandleDisconnect;
  FClientSocket.OnRead := HandleRead;
  FClientSocket.OnError := HandleError;
  FClientSocket.OnWrite := HandleWrite;
  inherited Create(nil, False);
end;

destructor TTWXWinSocketEx.Destroy;
begin
  if Assigned(FServerSocket) then
    FServerSocket.Free;
  if Assigned(FClientSocket) then
    FClientSocket.Free;
  inherited;
end;

procedure TTWXWinSocketEx.SetEventHandler(Handler: ITWXSocketEventHandler);
begin
  FEventHandler := Handler;
end;

function TTWXWinSocketEx.GetRemoteAddress: string;
begin
  if FIsServer and Assigned(FSocket) then
    Result := FSocket.RemoteAddress
  else if not FIsServer and Assigned(FClientSocket) and FClientSocket.Active then
    Result := FClientSocket.Socket.RemoteAddress
  else
    Result := '';
end;

procedure TTWXWinSocketEx.Listen(Port: Word);
begin
  if FIsServer and Assigned(FServerSocket) then
  begin
    FServerSocket.Port := Port;
    FServerSocket.Active := True;
  end;
end;

function TTWXWinSocketEx.Accept: ITWXSocketEx;
begin
  Result := nil; // Not implemented for this pattern
end;

procedure TTWXWinSocketEx.SetNonBlocking(Value: Boolean);
begin
  // Windows sockets are non-blocking by default in event model
end;

function TTWXWinSocketEx.HasData: Boolean;
begin
  Result := Assigned(FSocket) and (FSocket.ReceiveLength > 0);
end;

function TTWXWinSocketEx.Connect(const Host: string; Port: Word): Boolean;
begin
  if not FIsServer and Assigned(FClientSocket) then
  begin
    FClientSocket.Host := Host;
    FClientSocket.Port := Port;
    FClientSocket.Open;
    Result := True;
  end
  else
    Result := False;
end;

function TTWXWinSocketEx.Connected: Boolean;
begin
  if FIsServer then
    Result := Assigned(FServerSocket) and FServerSocket.Active
  else
    Result := Assigned(FClientSocket) and FClientSocket.Active;
end;

// Event handlers
procedure TTWXWinSocketEx.HandleConnect(Sender: TObject; Socket: TCustomWinSocket);
var
  SocketWrapper: ITWXSocket;
begin
  if Assigned(FEventHandler) then
  begin
    SocketWrapper := TTWXWinSocket.Create(Socket, False);
    FEventHandler.OnSocketConnect(SocketWrapper);
  end;
end;

procedure TTWXWinSocketEx.HandleDisconnect(Sender: TObject; Socket: TCustomWinSocket);
var
  SocketWrapper: ITWXSocket;
begin
  if Assigned(FEventHandler) then
  begin
    SocketWrapper := TTWXWinSocket.Create(Socket, False);
    FEventHandler.OnSocketDisconnect(SocketWrapper);
  end;
end;

procedure TTWXWinSocketEx.HandleRead(Sender: TObject; Socket: TCustomWinSocket);
var
  SocketWrapper: ITWXSocket;
begin
  if Assigned(FEventHandler) then
  begin
    SocketWrapper := TTWXWinSocket.Create(Socket, False);
    FEventHandler.OnSocketRead(SocketWrapper);
  end;
end;

procedure TTWXWinSocketEx.HandleError(Sender: TObject; Socket: TCustomWinSocket; ErrorEvent: TErrorEvent; var ErrorCode: Integer);
var
  SocketWrapper: ITWXSocket;
begin
  if Assigned(FEventHandler) then
  begin
    SocketWrapper := TTWXWinSocket.Create(Socket, False);
    FEventHandler.OnSocketError(SocketWrapper, ErrorCode);
  end;
  ErrorCode := 0; // Suppress error
end;

procedure TTWXWinSocketEx.HandleWrite(Sender: TObject; Socket: TCustomWinSocket);
begin
  // Socket is ready for writing - used for client send buffering
  // This will be handled by the client code as needed
end;

{$ELSE}

// ***************** Synapse Socket Implementation *********************

constructor TTWXSynapseSocket.Create(Socket: TTCPBlockSocket);
begin
  inherited Create;
  if Socket = nil then
  begin
    FSocket := TTCPBlockSocket.Create;
    FOwnsSocket := True;
  end
  else
  begin
    FSocket := Socket;
    FOwnsSocket := False;
  end;
end;

destructor TTWXSynapseSocket.Destroy;
begin
  if FOwnsSocket and Assigned(FSocket) then
    FSocket.Free;
  inherited;
end;

function TTWXSynapseSocket.SendText(const Data: string): Integer;
begin
  if Assigned(FSocket) and (Data <> '') then
  begin
    FSocket.SendString(Data);
    Result := Length(Data);
    if FSocket.LastError <> 0 then
      Result := 0;
  end
  else
    Result := 0;
end;

function TTWXSynapseSocket.ReceiveBuf(var Buffer: array of Char; Count: Integer): Integer;
var
  Data: string;
begin
  Result := 0;
  if Assigned(FSocket) and (Count > 0) then
  begin
    Data := FSocket.RecvBufferStr(Count, 0);
    if Length(Data) > 0 then
    begin
      Result := Length(Data);
      if Result > Count then
        Result := Count;
      Move(Data[1], Buffer[0], Result);
    end;
  end;
end;

function TTWXSynapseSocket.Connect(const Host: string; Port: Word): Boolean;
begin
  Result := False;
  if Assigned(FSocket) then
  begin
    FSocket.Connect(Host, IntToStr(Port));
    Result := FSocket.LastError = 0;
  end;
end;

procedure TTWXSynapseSocket.Disconnect;
begin
  if Assigned(FSocket) then
    FSocket.CloseSocket;
end;

function TTWXSynapseSocket.Connected: Boolean;
begin
  Result := Assigned(FSocket) and (FSocket.Socket <> INVALID_SOCKET) and (FSocket.LastError = 0);
end;

procedure TTWXSynapseSocket.Close;
begin
  Disconnect;
end;

// Extended Synapse Socket Implementation
constructor TTWXSynapseSocketEx.CreateServer;
begin
  inherited Create(nil);
  FIsServer := True;
  FConnectedClients := TList.Create;
  FClientLock := TCriticalSection.Create;
end;

constructor TTWXSynapseSocketEx.CreateClient;
begin
  inherited Create(nil);
  FIsServer := False;
  FConnectedClients := nil;
  FClientLock := nil;
end;

constructor TTWXSynapseSocketEx.CreateFromSocket(Socket: TTCPBlockSocket);
begin
  inherited Create(Socket);
  FIsServer := False;
  FConnectedClients := nil;
  FClientLock := nil;
end;

destructor TTWXSynapseSocketEx.Destroy;
begin
  if Assigned(FConnectedClients) then
  begin
    FClientLock.Acquire;
    try
      FConnectedClients.Clear;
      FConnectedClients.Free;
    finally
      FClientLock.Release;
    end;
  end;
  if Assigned(FClientLock) then
    FClientLock.Free;
  inherited;
end;

procedure TTWXSynapseSocketEx.SetEventHandler(Handler: ITWXSocketEventHandler);
begin
  FEventHandler := Handler;
end;

procedure TTWXSynapseSocketEx.AddClient(Client: ITWXSocketEx);
begin
  if not FIsServer or not Assigned(FConnectedClients) then
    Exit;
    
  FClientLock.Acquire;
  try
    FConnectedClients.Add(Pointer(Client));
  finally
    FClientLock.Release;
  end;
end;

procedure TTWXSynapseSocketEx.RemoveClient(Client: ITWXSocketEx);
begin
  if not FIsServer or not Assigned(FConnectedClients) then
    Exit;
    
  FClientLock.Acquire;
  try
    FConnectedClients.Remove(Pointer(Client));
  finally
    FClientLock.Release;
  end;
end;

function TTWXSynapseSocketEx.GetClientCount: Integer;
begin
  Result := 0;
  if not FIsServer or not Assigned(FConnectedClients) then
    Exit;
    
  FClientLock.Acquire;
  try
    Result := FConnectedClients.Count;
  finally
    FClientLock.Release;
  end;
end;

function TTWXSynapseSocketEx.GetRemoteAddress: string;
begin
  if Assigned(FSocket) then
    Result := FSocket.GetRemoteSinIP
  else
    Result := '';
end;

procedure TTWXSynapseSocketEx.Listen(Port: Word);
begin
  if FIsServer and Assigned(FSocket) then
  begin
    FPort := Port;
    FSocket.CreateSocket;
    FSocket.SetLinger(True, 1000);
    FSocket.Bind('0.0.0.0', IntToStr(Port));
    FSocket.Listen;
  end;
end;

function TTWXSynapseSocketEx.Accept: ITWXSocketEx;
var
  ClientSocket: TTCPBlockSocket;
  ClientWrapper: TTWXSynapseSocketEx;
begin
  Result := nil;
  if FIsServer and Assigned(FSocket) and FSocket.CanRead(1000) then
  begin
    ClientSocket := TTCPBlockSocket.Create;
    ClientSocket.Socket := FSocket.Accept;
    if FSocket.LastError = 0 then
    begin
      ClientWrapper := TTWXSynapseSocketEx.CreateFromSocket(ClientSocket);
      AddClient(ClientWrapper);
      Result := ClientWrapper;
      if Assigned(FEventHandler) then
        FEventHandler.OnSocketConnect(ClientWrapper);
    end
    else
      ClientSocket.Free;
  end;
end;

procedure TTWXSynapseSocketEx.SetNonBlocking(Value: Boolean);
begin
  if Assigned(FSocket) then
    FSocket.NonBlockMode := Value;
end;

function TTWXSynapseSocketEx.HasData: Boolean;
begin
  Result := Assigned(FSocket) and FSocket.CanRead(0);
end;

{$ENDIF}


// ***************** TModServer Implementation *********************



procedure TModServer.AfterConstruction;
begin
  inherited;

  Randomize();

  {$IFDEF WINDOWS}
  tcpServer := TTWXWinSocketEx.CreateServer(Self);
  {$ELSE}
  tcpServer := TTWXSynapseSocketEx.CreateServer;
  {$ENDIF}
  tcpServer.SetEventHandler(Self);

  FConnectedClients := TList.Create;
  FClientLock := TCriticalSection.Create;  // Initialize thread safety
  FAcceptThread := nil;
  FBufferOut := TStringList.Create;
  FBufTimer := TTimer.Create(Self);
  FBufTimer.OnTimer := OnBufTimer;
  FBufTimer.Interval := 1;
  FBufTimer.Enabled := FALSE;

  // set defaults
 BroadCastMsgs := True;

  // mb - Cleate lists for quicktext
  SystemQuickText := TList.Create;
  UserQuickText := Tlist.Create;

  // initialize system quicktexts
  AddSystemQuickText('~a', '^[0;30m');
  AddSystemQuickText('~b', '^[0;31m');
  AddSystemQuickText('~c', '^[0;32m');
  AddSystemQuickText('~d', '^[0;33m');
  AddSystemQuickText('~e', '^[0;34m');
  AddSystemQuickText('~f', '^[0;35m');
  AddSystemQuickText('~g', '^[0;36m');
  AddSystemQuickText('~h', '^[0;37m');
  AddSystemQuickText('~A', '^[1;30m');
  AddSystemQuickText('~B', '^[1;31m');
  AddSystemQuickText('~C', '^[1;32m');
  AddSystemQuickText('~D', '^[1;33m');
  AddSystemQuickText('~E', '^[1;34m');
  AddSystemQuickText('~F', '^[1;35m');
  AddSystemQuickText('~G', '^[1;36m');
  AddSystemQuickText('~H', '^[1;37m');
  AddSystemQuickText('~i', '^[40m');
  AddSystemQuickText('~j', '^[41m');
  AddSystemQuickText('~k', '^[42m');
  AddSystemQuickText('~l', '^[43m');
  AddSystemQuickText('~m', '^[44m');
  AddSystemQuickText('~n', '^[45m');
  AddSystemQuickText('~o', '^[46m');
  AddSystemQuickText('~p', '^[47m');
  AddSystemQuickText('~I', '^[5;40m');
  AddSystemQuickText('~J', '^[5;41m');
  AddSystemQuickText('~K', '^[5;42m');
  AddSystemQuickText('~L', '^[5;43m');
  AddSystemQuickText('~M', '^[5;44m');
  AddSystemQuickText('~N', '^[5;45m');
  AddSystemQuickText('~O', '^[5;46m');
  AddSystemQuickText('~P', '^[5;47m');
  AddSystemQuickText('~!', '^[2J^[H');
  AddSystemQuickText('~@', chr(13) + '^[0m^[0K');
  AddSystemQuickText('~0', '^[0m');
  AddSystemQuickText('~1', '^[0m^[1;36m');
  AddSystemQuickText('~2', '^[0m^[1;33m');
  AddSystemQuickText('~3', '^[0m^[35m');
  AddSystemQuickText('~4', '^[0m^[1;44m');
  AddSystemQuickText('~5', '^[0m^[32m');
  AddSystemQuickText('~6', '^[0m^[1;5;37m');
  AddSystemQuickText('~7', '^[0m^[1;37m');
  AddSystemQuickText('~8', '^[0m^[1;5;31m');
  AddSystemQuickText('~9', '^[0m^[30;47m');
  AddSystemQuickText('~s', '[s');
  AddSystemQuickText('~u', '[u');
  AddSystemQuickText('~-', '---------------------------------------------------------------------');
  AddSystemQuickText('~=', '=====================================================================');
  AddSystemQuickText('~+', '-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-');

  // MB - Create strings for Text to CP437 conversion
  CP437Mode := 0;
  CP437Text := Tlist.Create;
  addCP437Text('/-', #218 + #196);
  addCP437Text('-\', #196 + #191);
  addCP437Text('\-', #192 + #196);
  addCP437Text('-/', #196 + #217);
  addCP437Text('/=', #201 + #205);
  addCP437Text('=\', #205 + #187);
  addCP437Text('\=', #200 + #205);
  addCP437Text('=/', #205 + #188);
  addCP437Text('-.-', #196 + #194 + #196, 1);
  addCP437Text('-+-', #196 + #197 + #196, 1);
  addCP437Text('-^-', #196 + #193 + #196, 1);
  addCP437Text('=.=', #205 + #209 + #205, 1);
  addCP437Text('=+=', #205 + #216 + #205, 1);
  addCP437Text('=^=', #205 + #207 + #205, 1);
  addCP437Text('-.-', #196 + #210 + #196, 2);
  addCP437Text('-+-', #196 + #215 + #196, 2);
  addCP437Text('-^-', #196 + #208 + #196, 2);
  addCP437Text('=.=', #205 + #203 + #205, 2);
  addCP437Text('=+=', #205 + #206 + #205, 2);
  addCP437Text('=^=', #205 + #202 + #205, 2);
  addCP437Text('|-', #195 + #196, 1);
  addCP437Text('-|', #196 + #180, 1);
  addCP437Text('|=', #198 + #205, 1);
  addCP437Text('=|', #205 + #181, 1);
  addCP437Text('|-', #199 + #196, 2);
  addCP437Text('-|', #196 + #182, 2);
  addCP437Text('|=', #204 + #205, 2);
  addCP437Text('=|', #205 + #185, 2);
  addCP437Text('-- ', #196 + #196 + ' ');
  addCP437Text('== ', #205 + #205 + ' ');
  addCP437Text('= ', #254 + ' ');
  addCP437Text('- ', #255 + ' ');
  addCP437Text('-=', #255 + #254);
  addCP437Text('=-', #254 + #255);
  addCP437Text('-', #196);
  addCP437Text('=', #205);
  addCP437Text(#254, '=');
  addCP437Text(#255, '-');

  // CP437 single line vertical mode
  addCP437Text('|', #179, 1);

  // CP437 double line vertical mode
  addCP437Text('|', #186, 2);

end;

procedure TModServer.BeforeDestruction;
begin
  // Stop the accept thread if it's running
  if Assigned(FAcceptThread) then
  begin
    FAcceptThread.Terminate;
    FAcceptThread.WaitFor;
    FAcceptThread.Free;
    FAcceptThread := nil;
  end;
  
  tcpServer := nil; // Interface reference will be cleaned up
  FConnectedClients.Free;
  FClientLock.Free;  // Cleanup thread safety
  FBufferOut.Free;
  FBufTimer.Free;

  while (SystemQuickText.Count > 0) do
  begin
    TQuickText(SystemQuickText[0]).Free;
    SystemQuickText.Delete(0);
  end;
  SystemQuickText.Free;

  while (UserQuickText.Count > 0) do
  begin
    TQuickText(UserQuickText[0]).Free;
    UserQuickText.Delete(0);
  end;
  UserQuickText.Free;

  inherited;

  while (CP437Text.Count > 0) do
  begin
    TCP437(CP437Text[0]).Free;
    CP437Text.Delete(0);
  end;
  CP437Text.Free;

end;

function TModServer.ApplyQuickText(Text : string) : string;
var
  I : Integer;
begin
    // Store literal Tildes as null
    Text := stringreplace(Text, '~~', chr(255), [rfReplaceAll]);

    // Apply bot specific tagged line
    if pos('~_', Text) > 0 then
      Text := stringreplace(Text, '~_',
      leftstr('---------------------------------------------------------------------',
      67 - TWXInterpreter.ActiveBotTagLength) + TWXInterpreter.ActiveBotTag + '--', [rfReplaceAll]);


    // Apply user QuickText strings
    for I := 0 to UserQuickText.Count - 1 do
    begin
      Text := stringreplace(Text, TQuickText(UserQuickText[I]).Search,
              TQuickText(UserQuickText[I]).Replace, [rfReplaceAll]);
    end;

    // Apply system QuickText strings
    for I := 0 to SystemQuickText.Count - 1 do
    begin
      Text := stringreplace(Text, TQuickText(SystemQuickText[I]).Search,
              TQuickText(SystemQuickText[I]).Replace, [rfReplaceAll]);
    end;

    // convert Null characters to literal ~ in final string
    Text := stringreplace(Text, chr(255), '~', [rfReplaceAll]);

    // replace "^[" with literal "<esc>[" in result
    result := stringreplace(Text, '^[', chr(27) + '[', [rfReplaceAll]);
end;

function TModServer.ApplyCP437Text(Text : string) : string;
var
  I : Integer;
begin
    // Set vertical mode to single or double based on first corner
    if (pos('/-', Text) > 0) then
      CP437Mode := 1;
    if (pos('/=', Text) > 0) then
      CP437Mode := 2;

    // Convert text strings to CP437
    for I := 0 to CP437Text.Count - 1 do
    begin
      if (CP437Mode < 2) and (TCP437(CP437Text[I]).Mode < 2) then
        Text := stringreplace(Text, TCP437(CP437Text[I]).Search,
                TCP437(CP437Text[I]).Replace, [rfReplaceAll])
      else if (CP437Mode = 2) and ((TCP437(CP437Text[I]).Mode =0) or
              (TCP437(CP437Text[I]).Mode = 2)) then
        Text := stringreplace(Text, TCP437(CP437Text[I]).Search,
                TCP437(CP437Text[I]).Replace, [rfReplaceAll]);
    end;

    result := Text;
end;

procedure TModServer.AddSystemQuickText(Search, Replace : string);
var
  NewText : TQuickText;
begin
  // build new Syhstem QuickText
  NewText := TQuickText.Create;
  NewText.Search  := Search;
  NewText.Replace := Replace;

  SystemQuickText.Add(NewText);
end;

procedure TModServer.AddQuickText(Search, Replace : string);
var
  NewText : TQuickText;
begin
  // Make sure there is no existing User QuickText
  ClearQuickText(Search);

  // build new User QuickText
  NewText := TQuickText.Create;
  NewText.Search  := Search;
  NewText.Replace := ApplyQuickText(Replace);

  UserQuickText.Add(NewText);
end;

procedure TModServer.AddCP437Text(Search, Replace : string; Mode : Integer = 0);
var
  NewText : TCP437;
begin
  // build new Syhstem QuickText
  NewText := TCP437.Create;
  NewText.Search  := Search;
  NewText.Replace := Replace;
  NewText.Mode := Mode;

  CP437Text.Add(NewText);
end;


procedure TModServer.ClearQuickText(Search : string = '');
var
  I : Integer;
begin
  if (Search = '') then
    begin
       while (UserQuickText.Count > 0) do
    begin
      TQuickText(UserQuickText[0]).Free;
      UserQuickText.Delete(0);
    end;
  end
  else
  begin
    for I := 0 to UserQuickText.Count - 1 do
    begin
      if TQuickText(UserQuickText[I]).Search = Search then
      begin
        TQuickText(UserQuickText[I]).Free;
        UserQuickText.Delete(I);
        break;
      end;
    end;
  end;
end;

procedure TModServer.Broadcast(Text : string; AMarkEcho : Boolean = TRUE; BroadcastDeaf : Boolean = FALSE; Buffered : Boolean = FALSE; CP437 : Boolean = FALSE);
var
  I : Integer;
  Stream : String;
  InAnsi : Boolean;
begin
  if (Length(Text) = 0) then
    Exit;

  Text := ApplyQuickText(Text);

  if CP437 = True then
    Text := ApplyCP437Text(Text);

  Stream := Text;
  for I := 0 to length(Stream) do
  begin
    if (Stream[I] = #27) then
      InAnsi := TRUE;

    if (InAnsi = FALSE) then
      if (Stream[I] >= '0') and (Stream[I] <= '9') then
        Stream[I] := chr(255);

    if ((Stream[I] >= chr(65)) and (Stream[I] <= chr(90))) or ((Stream[I] >= chr(97)) and (Stream[I] <= chr(122))) then
      InAnsi := FALSE;
  end;

  for I := 0 to 2 do
    Stream := stringreplace(Stream,  chr(255) +  chr(255), chr(255), [rfReplaceAll]);

  Stream := stringreplace(Stream,  chr(255), '1', [rfReplaceAll]);

  if not (Buffered) and (FBufferOut.Count > 0) then
  begin
    // we still have data going out of the buffer, add to it for a later broadcast
    FBufferOut.Add(Text);
    Exit;
  end;

  // Thread-safe client list access
  FClientLock.Acquire;
  try
    for I := 0 to FConnectedClients.Count - 1 do
      if (BroadcastDeaf) or (ClientTypes[I] <> ctDeaf) then
      begin
        try
          if (AMarkEcho) and (FClientEchoMarks[I]) then
            ITWXSocket(FConnectedClients[I]).SendText(#255 + #0 + Text + #255 + #1)
          else
            if ClientTypes[I] = ctStream then
              ITWXSocket(FConnectedClients[I]).SendText(Stream)
            else
              ITWXSocket(FConnectedClients[I]).SendText(Text);
        except
          {$IFDEF WINDOWS}
          OutputDebugString(PChar('Unexpected error sending broadcast message'));
          {$ELSE}
          // Log error on non-Windows platforms
          WriteLn('Unexpected error sending broadcast message');
          {$ENDIF}
        end;
      end;
  finally
    FClientLock.Release;
  end;
end;

procedure TModServer.ClientMessage(MessageText : string);
begin
  if (TWXMenu.CurrentMenu <> nil) then
    Broadcast(#13 + ANSI_CLEARLINE + endl + ANSI_15 + MessageText + ANSI_7 + endl + TWXMenu.GetPrompt)
  else if (TWXClient.Connected) and (Length(TWXExtractor.CurrentLine) > 0) then
    Broadcast(#13 + ANSI_CLEARLINE + endl + ANSI_15 + MessageText + ANSI_7 + endl + endl + TWXExtractor.CurrentANSILine)
  else
    Broadcast(endl + ANSI_15 + MessageText + ANSI_7 + endl);
end;

procedure TModServer.AddBuffer(Text : string);
begin
  // add text to outgoing buffer
  FBufferOut.Append(Text);
  FBufTimer.Enabled := TRUE;
end;

procedure TModServer.StopVarDump;
var
  I : Integer;
  Found : Boolean;
begin
  // Find the index of 'Variable Dump Complete.'
  FBufTimer.Enabled := FALSE;
  Found := FALSE;
  for I := FBufferOut.Count - 1 downto 0 do
  begin
    if Found = TRUE then
      FBufferOut.Delete(I)
    else if (Pos('Variable Dump Complete.', FBufferOut[I]) > 0) then
    begin
      Found := TRUE;
      FBufferOut.Delete(I);
    end;
  end;
  FBufTimer.Enabled := TRUE;
end;

procedure TModServer.NotifyScriptLoad;
var
  I : Integer;
begin
  if (FConnectedClients.Count > 0) then
    for I := 0 to FConnectedClients.Count - 1 do
      if (FClientEchoMarks[I]) then
        ITWXSocket(FConnectedClients[I]).SendText(#255 + #2);
end;

procedure TModServer.NotifyScriptStop;
var
  I : Integer;
begin
  if (FConnectedClients.Count > 0) then
    for I := 0 to FConnectedClients.Count - 1 do
    Begin
      if (FClientEchoMarks[I]) then
        ITWXSocket(FConnectedClients[I]).SendText(#255 + #3);

      // MB - Clear the Deaf flag if there are no other scripts running.
      if (TWXInterpreter.Count = 0) then
        TWXServer.ClientTypes[I] := ctStandard;
    End;
end;

// Cross-platform socket handling implemented via ITWXSocketEventHandler interface methods:
// - OnSocketConnect
// - OnSocketDisconnect  
// - OnSocketRead
// - OnSocketError

procedure TModServer.OnBufTimer(Sender : TObject);
begin
  if (FBufferOut.Count > 0) then
  begin
    Broadcast(FBufferOut[0], TRUE, FALSE, TRUE);
    FBufferOut.Delete(0);
  end
  else
    FBufTimer.Enabled := FALSE;
end;

function TModServer.GetClientType(Index : Integer) : TClientType;
begin
  Result := FClientTypes[Index];
end;

function TModServer.GetClientCount : Integer;
begin
  FClientLock.Acquire;
  try
    Result := FConnectedClients.Count;
  finally
    FClientLock.Release;
  end;
end;





function TModServer.GetClientAddress(Index : Integer) : string;
begin
  FClientLock.Acquire;
  try
    if (Index >= 0) and (Index < FConnectedClients.Count) then
      Result := (ITWXSocketEx(FConnectedClients[Index])).GetRemoteAddress
    else
      Result := '';
  finally
    FClientLock.Release;
  end;
end;

procedure TModServer.SetClientType(Index : Integer; Value : TClientType);
begin
  FClientTypes[Index] := Value;
end;

function TModServer.GetSocketIndex(S : ITWXSocket) : Integer;
begin
  Result := FConnectedClients.IndexOf(S);
end;

procedure TModServer.SetListenPort(Value : Word);
begin
  TWXDatabase.ListenPort := Value;
  // Port will be set when Activate is called
end;

function TModServer.GetListenPort : Word;
begin
  Result := TWXDatabase.ListenPort;
end;

procedure TModServer.Activate;
begin
  try
    tcpServer.Listen(TWXDatabase.ListenPort);
    
    // Start the threaded server for accepting multiple concurrent clients
    if not Assigned(FAcceptThread) then
    begin
      FAcceptThread := TServerAcceptThread.Create(tcpServer, Self);
    end;
  except
    MessageDlg('Unable to bind a listening socket on port ' + IntToStr(TWXDatabase.ListenPort) + '.' + endl + 'You will need to change it before you can connect to TWX Proxy.', mtWarning, [mbOK], 0);
  end;
end;

procedure TModServer.Deactivate;
begin
  // Stop the accept thread first
  if Assigned(FAcceptThread) then
  begin
    FAcceptThread.Terminate;
    FAcceptThread.WaitFor;
    FAcceptThread.Free;
    FAcceptThread := nil;
  end;
  
  tcpServer.Close;
end;

function TModServer.GetStreamEnabled: Boolean;
begin
  Result := FStreamEnabled;
end;

procedure TModServer.SetStreamEnabled(Value: Boolean);
begin
  FStreamEnabled := Value;
end;

function TModServer.GetAllowLerkers: Boolean;
begin
  Result := FAllowLerkers;
end;

procedure TModServer.SetAllowLerkers(Value: Boolean);
begin
  FAllowLerkers := Value;
end;

function TModServer.GetLerkerAddress: String;
begin
  Result := FLerkerAddress;
end;

procedure TModServer.SetLerkerAddress(Value: String);
begin
  FLerkerAddress := Value;
end;

function TModServer.GetAcceptExternal: Boolean;
begin
  Result := FAcceptExternal;
end;

procedure TModServer.SetAcceptExternal(Value: Boolean);
begin
  FAcceptExternal := Value;
end;

function TModServer.GetExternalAddress: String;
begin
  Result := FExternalAddress;
end;

procedure TModServer.SetExternalAddress(Value: String);
begin
  FExternalAddress := Value;
end;

function TModServer.GetBroadCastMsgs: Boolean;
begin
  Result := FBroadCastMsgs;
end;

procedure TModServer.SetBroadCastMsgs(Value: Boolean);
begin
  FBroadCastMsgs := Value;
end;

function TModServer.GetLocalEcho: Boolean;
begin
  Result := FLocalEcho;
end;

procedure TModServer.SetLocalEcho(Value: Boolean);
begin
  FLocalEcho := Value;
end;

// ITWXSocketEventHandler implementation for TModServer
procedure TModServer.OnSocketConnect(Socket: ITWXSocket);
begin
  HandleClientConnect(Socket);
end;

procedure TModServer.OnSocketDisconnect(Socket: ITWXSocket);
begin
  HandleClientDisconnect(Socket);
end;

procedure TModServer.OnSocketRead(Socket: ITWXSocket);
begin
  HandleClientRead(Socket);
end;

procedure TModServer.OnSocketError(Socket: ITWXSocket; ErrorCode: Integer);
begin
  HandleClientError(Socket, ErrorCode);
end;

// Cross-platform event handlers
procedure TModServer.HandleClientConnect(Socket: ITWXSocket);
const
  T_WILL = #255 + #251;
  T_WONT = #255 + #252;
  T_DO = #255 + #253;
  T_DONT = #255 + #254;
var
  IniFile       : TIniFile;
  LocalClient,
  Lerker        : Boolean;
  Index         : Integer;
  RemoteAddress,
  Address,
  TempAddress   : String;
  AddressList   : TStringList;
  SocketEx      : ITWXSocketEx;
begin
  // Add to connected clients list
  FConnectedClients.Add(Socket);
  Index := FConnectedClients.Count - 1;

  IniFile := TIniFile.Create(TWXGUI.ProgramDir + '\twxp.cfg');

  // Try to get remote address if socket supports extended interface
  if Supports(Socket, ITWXSocketEx, SocketEx) then
    RemoteAddress := SocketEx.GetRemoteAddress
  else
    RemoteAddress := 'Unknown';
  AddressList := TStringList.Create;

  if (RemoteAddress = '127.0.0.1') or
  (Copy(RemoteAddress, 1, 8) = '192.168.') or
  (Copy(RemoteAddress, 1, 3) = '10.')
  then
    LocalClient := TRUE
  else
    LocalClient := FALSE;

   try
     ExtractStrings([' '],[], pchar(ExternalAddress), AddressList);

     for Address in AddressList do
     begin
       if length(ExternalAddress) > 0 then
       begin
          TempAddress := stringreplace(Address, '.*', '',[rfReplaceAll, rfIgnoreCase]);
          if (Copy(RemoteAddress,1,length(TempAddress)) = TempAddress)
          then
            LocalClient := TRUE
       end;
     end;

     Lerker := FALSE;
     AddressList.Clear();
     ExtractStrings([' '],[], pchar(LerkerAddress), AddressList);

     for Address in AddressList do
     begin
        // Allow globsl wildcard
        if (Address = '*')  or (Address = '*.*.*.*') then
          Lerker := TRUE
        else
          if length(LerkerAddress) > 0 then
          begin
            TempAddress := stringreplace(Address, '.*', '',[rfReplaceAll, rfIgnoreCase]);
            if (Copy(RemoteAddress,1,length(TempAddress)) = TempAddress) then
              Lerker := TRUE;
          end;
     end;
   finally
     AddressList.Free;
   end;

   if (RemoteAddress = '127.0.0.1') or
      (AcceptExternal and LocalClient) or
      (AllowLerkers and Lerker) then
      Socket.SendText(endl + ANSI_12 + 'TWX Proxy Server ' + ANSI_11 + 'v' +
        ProgramVersion + chr(ReleaseNumber + 96) + ANSI_7 + ' (' + ReleaseVersion + ')' + endl)
   else
   begin
     // User not allowed
     Socket.SendText(ANSI_12 + 'External connections are disabled. Goodbye ' + RemoteAddress + '!');
     Sleep(500);
     FClientTypes[Index] := ctRejected;
     Socket.Close();
     if (BroadCastMsgs) then
       Broadcast(endl + ANSI_12 + 'Remote connection rejected from: ' + ANSI_14 + RemoteAddress + endl);
     exit;
   end;

    try
      if IniFile.ReadString('TWX Proxy', 'UpdateAvailable', 'False') = 'True' then
      begin
        Socket.SendText(endl + ANSI_15 +
          'An updated verion of TWX Proxy is available. To download please visit: ' + endl +
          'https://github.com/Tw2002/TWXP/wiki' + endl + ANSI_7);
      end;
    finally
      IniFile.Free;
    end;

  if (BroadCastMsgs) then
    Broadcast(endl + ANSI_13 + 'Active connection detected from: ' + ANSI_14 + RemoteAddress + endl)
  else
    Socket.SendText(endl + ANSI_13 + 'Active connection detected from: ' + ANSI_14 + RemoteAddress + endl);

  begin
    // Send Telnet "Are you there"
    Socket.SendText(#255 + OP_DO + #246);
    FClientEchoMarks[Index] := FALSE;

    if (AcceptExternal) or (AllowLerkers) then
      Socket.SendText(endl + ANSI_12 + 'WARNING: ' + ANSI_14 +
                      'With External Connections and/or Allow Lerkers enabled,' + endl +
                      'you are open to foreign users monitoring data remotely.' + endl);

    Socket.SendText(endl);

    if TWXDatabase.DataBaseOpen then
      Socket.SendText(ANSI_10 + 'Using Database ' + ANSI_14 + TWXDatabase.DatabaseName + ANSI_10 + ' w/ ' +
                      ANSI_14 + IntToStr(TWXDatabase.DBHeader.Sectors) + ANSI_10 + ' sectors and ' +
                      ANSI_14 + IntToStr(TWXDatabase.WarpCount) + ANSI_10 + ' warps' + endl);

    if (TWXLog.LogFileOpen) then
      Socket.SendText(ANSI_10 + 'You are logging to file: ' + ANSI_14 + TWXLog.LogFilename + endl);

    Socket.SendText(endl + ANSI_13 + 'There are currently ' + ANSI_11 + IntToStr(FConnectedClients.Count) +
                           ANSI_13 + ' active telnet connections' + endl);

    if (TWXClient.Connected) then
      Socket.SendText(ANSI_13 + 'You are connected to server: ' + ANSI_11 + TWXDatabase.DBHeader.Address + endl + ANSI_7)
    else
      Socket.SendText(ANSI_11 + 'No' + ANSI_13 + ' server connections detected' + endl);

    if ((LocalClient) and (AcceptExternal)) or (RemoteAddress = '127.0.0.1')then
    begin
      FClientTypes[Index] := ctStandard;
      Socket.SendText(endl + ANSI_2 + 'Press ' + ANSI_14 + TWXExtractor.MenuKey + ANSI_2 + ' to activate terminal menu' + endl + endl);
    end
    else
    begin
      if StreamEnabled then
        FClientTypes[Index] := ctStream
      else
        FClientTypes[Index] := ctMute;

        Socket.SendText(ANSI_12 + 'You are locked in view only mode' + ANSI_7 + endl + endl);
    end;

    TWXInterpreter.ProgramEvent('Client connected', '', FALSE);
  end;
end;

procedure TModServer.HandleClientDisconnect(Socket: ITWXSocket);
var
  I,
  Index : Integer;
  SocketEx: ITWXSocketEx;
  RemoteAddr: string;
begin
  Index := FConnectedClients.IndexOf(Socket);
  if Index = -1 then Exit;

  // manual client message to all sockets except the one disconnecting
  if (FClientTypes[Index] <> ctRejected) then
    for I := 0 to FConnectedClients.Count - 1 do
      if (ITWXSocket(FConnectedClients[I]) <> Socket) then
      begin
        if Supports(Socket, ITWXSocketEx, SocketEx) then
          RemoteAddr := SocketEx.GetRemoteAddress
        else
          RemoteAddr := 'Unknown';
        ITWXSocket(FConnectedClients[I]).SendText( endl + ANSI_7 + 'Connection lost from: ' + ANSI_15 + RemoteAddr + ANSI_7 + endl);
      end;

  // remove client from list
  FConnectedClients.Delete(Index);
  for I := Index to 254 do
  begin
    if I + 1 <= 255 then
    begin
      FClientTypes[I] := FClientTypes[I + 1];
      FClientEchoMarks[I] := FClientEchoMarks[I + 1];
    end;
  end;

  TWXInterpreter.ProgramEvent('Client disconnected', '', FALSE);
end;

procedure TModServer.HandleClientError(Socket: ITWXSocket; ErrorCode: Integer);
begin
  // Disable error message by not processing it
end;

procedure TModServer.HandleClientRead(Socket: ITWXSocket);
var
  InStr,
  InString : string;
  I        : Integer;
  Last     : Char;
  Buffer   : array[0..1023] of Char;
  BytesRead: Integer;
begin
  // terminate any logs that are playing
  TWXLog.EndPlayLog;

  // Read data from socket
  InStr := '';
  BytesRead := Socket.ReceiveBuf(Buffer, 1024);
  if BytesRead > 0 then
    SetString(InStr, Buffer, BytesRead);

  // remove any null characters after #13
  InString := '';
  Last := #0;
  if (Length(InStr) > 0) then
    for I := 1 to Length(InStr) do
    begin
      if not ((Last = #13) and ((InStr[I] = #0) or (InStr[I] = #10))) then
        InString := InString + InStr[I];

      Last := InStr[I];
    end;

  // process telnet commands
  InString := ProcessTelnet(InString, Socket);

  // TODO Process ANSI response for cursor position, screen size, scroll region, etc...

  // Ignore ANSI/VT100 Status report
  if ContainsText(InString, #27 + '[0n') then
    InString := StringReplace(InString, #27 + '[0n', '', [rfReplaceAll, rfIgnoreCase]);

  if (InString = '') then
    Exit;

  FCurrentClient := FConnectedClients.IndexOf(Socket);
  if FCurrentClient = -1 then Exit;

  if (ClientTypes[FCurrentClient] = ctMute) or
     (ClientTypes[FCurrentClient] = ctStream) then
    Exit; // mute / streaming clients can't talk

  // Process data for telnet commands
  if (TWXExtractor.ProcessOutBound(InString, FCurrentClient)) and (TWXClient.Connected) then
  begin
    TWXClient.Send(InString);

    if (LocalEcho) then
      Socket.SendText(InString);
  end;
end;



// ***************** TModClient Implementation *********************


procedure TModClient.AfterConstruction;
begin
  inherited;

  FConnecting := FALSE;
  FUserDisconnect := FALSE;
  FReconnectDelay := 15;
  FFirstConnect := TRUE;
  FReconnectTock := -1;
  FReconnectCount := 0;
  FBlockExtended := FALSE;

  tmrReconnect := TTimer.Create(Self);
  with (tmrReconnect) do
  begin
    Enabled := FALSE;
    Interval := 1000;
    OnTimer := tmrReconnectTimer;
  end;

  tmrIdle := TTimer.Create(Self);
  with (tmrIdle) do
  begin
    Enabled := FALSE;
    Interval := 60 * 1000;
    OnTimer := tmrIdleTimer;
  end;
end;

procedure TModClient.BeforeDestruction;
begin
  CloseClient();
  inherited;
end;

procedure TModClient.Send(Text : string);
var
  I: Integer;
  S: String;
begin
  if (Connected) and (Text <> '') then
  begin
    S := '';

    // MB - Strip extended characters and # from string, until TWGS version is detected.
    //      TWGS converts any extended character sent to the login prompt to '#', so
    //      this should help login when stray kepalive/sentinal scripts are running.
    if FBlockExtended then
    begin
      for I := 0 to Length(Text) do
        if ((Text[I] >= #32) and (Text[I] <= #128) and (Text[I] <> '#')) or (Text[I] = #8) or (Text[I] = #13) then
          S := S + Text[I];
    end
    else
    begin
      S := Text;
    end;

    FUnsentString := FUnsentString + S;
    try
      FBytesSent := tcpClient.SendText(FUnsentString);
    except
      // Error in SendText - could log this in cross-platform way if needed
    end;
    //if FBytesSent <> Length(Text) then
    if FBytesSent <> Length(FUnsentString) then
    begin
      FSendPending := TRUE;
      FUnsentString := Copy(FUnsentString, FBytesSent + 1, Length(FUnsentString) - FBytesSent);
    end
    else
    begin
      FSendPending := FALSE;
      FUnsentString := '';
    end;
    if (Text <> #27) then
      IdleMinutes := 0;
  end;
end;

procedure TModClient.Connect();
begin
  // MB - Allow a faster reconnect if it is the first request after a disconnect.
  if FFirstConnect then
  begin
    FFirstConnect := FALSE;
    tmrReconnect.Enabled := TRUE;
    FReconnectTock := 1;
  end;

  // MB - This function only enables the reconnect timer, so that
  //      extra connect commands from Mombot will be ignored.
  if (not Connected) and (not FConnecting) and (FReconnectTock < 0) then
  begin
    tmrReconnect.Enabled := TRUE;
    FReconnectTock := 3;
  end;
end;

procedure TModClient.ConnectNow();
begin
  if (Connected or FConnecting) or (tcpClient <> nil) then
    CloseClient();

  // See if we're allowed to connect
  if not (TWXDatabase.DatabaseOpen) then
  begin
    TWXServer.ClientMessage('Please create a database before attempting to connect to a server.');
    FUserDisconnect := TRUE;
    Exit;
  end;

  FUserDisconnect := FALSE;
  FConnecting := TRUE;
  FBlockExtended := TRUE;

  // MB - Moved socket creation here, to ensure there are no unflushed buffers.
  {$IFDEF WINDOWS}
  tcpClient := TTWXWinSocketEx.CreateClient(Self);
  {$ELSE}
  tcpClient := TTWXSynapseSocketEx.CreateClient;
  {$ENDIF}
  tcpClient.SetEventHandler(Self);

  FreconnectCount := FreconnectCount + 1;

  // Broadcast operation
  TWXServer.Broadcast(#13 + #27 + '[A' + #27 + '[K' + ANSI_13 + 'Attempting to connect to: ' +
                      ANSI_14 + TWXDatabase.DBHeader.Address + ANSI_13 + ':' + ANSI_14 + IntToStr(TWXDatabase.DBHeader.ServerPort) +
                      ANSI_13 + ' (' + ANSI_12 + IntToStr(FreconnectCount) + ANSI_13 + ')' + ANSI_15 + endl + #27 + '[K');

  // MB - No need for an exception trap here. It will callback onError instead of throwing an exception.
  tcpClient.Connect(TWXDatabase.DBHeader.Address, TWXDatabase.DBHeader.ServerPort);
end;

procedure TModClient.Disconnect;
begin
  TWXExtractor.CurrentLine := '';
  TWXServer.ClientMessage(ANSI_12 + 'Disconnecting from server...');

  // Make sure it doesn't try to reconnect
  FUserDisconnect := TRUE;
  tmrReconnect.Enabled := FALSE;
  FReconnectTock := -1;
  FreconnectCount := 0;
  FConnecting := FALSE;

  // Deactivate client - disconnect from server
  CloseClient;
end;

procedure TModClient.CloseClient;
begin
  try
    if tcpClient <> nil then
    begin
      tcpClient.Close;
      tcpClient := nil; // Interface reference will be cleaned up
    end;
  except
    // MB - It is normal for this exception to be thrown if the client is already disconnected.
    TWXServer.ClientMessage('Unexpected error while closing connection.');
  end;
  Sleep(500);
end;



// Legacy Windows methods removed - using cross-platform ITWXSocketEventHandler interface instead

procedure TModClient.tmrIdleTimer(Sender: TObject);
begin
  IdleMinutes := IdleMinutes + 1;

  if (IdleMinutes > 1) then
  begin

    // MB - Timeout a connection that is stuck in Connecting State
    if (FConnecting = TRUE) then
      ConnectNow();

    // MB - ReEnable the log file.
    if TWXLog.LogEnabled and (not TWXLog.LogData) then
    begin
      TWXLog.LogData := TRUE;
      //TWXServer.ClientMessage(endl + 'Logging renabled. (' + DateTimeToStr(Now) + ')' + endl);
      TWXLog.WriteLog(endl + endl + 'Logging renabled. (' + DateTimeToStr(Now) + ')' + endl + endl);
    end;

    // MB - Reverse keepalive for remote clients.
    if TWXServer.AllowLerkers or TWXServer.AcceptExternal then
      TWXServer.Broadcast(#27 + '[5n');  // Send ANSI/VT100 terminal status request
  end;
end;

procedure TModClient.tmrReconnectTimer(Sender: TObject);
begin
  FReconnectTock := FReconnectTock - 1;
  if FReconnectTock <= 0 then
  begin
    tmrReconnect.Enabled := FALSE;
    FReconnectTock := -1;
    if not FUserDisconnect then
      ConnectNow();
  end;
end;

function TModClient.GetConnected : Boolean;
begin
  try
    if tcpClient = nil then
      Result := FALSE
    else
      Result := tcpClient.Connected;
  except
    Result := False;
  end;
end;

function TModClient.GetReconnect: Boolean;
begin
  Result := FReconnect;
end;

procedure TModClient.SetReconnect(Value: Boolean);
begin
  FReconnect := Value;
end;

function TModClient.GetReconnectDelay: Integer;
begin
  Result := FReconnectDelay;
end;

procedure TModClient.SetReconnectDelay(Value: Integer);
begin
  If Value < 3 then
    FReconnectDelay := 3
  else
    FReconnectDelay := Value;
end;

// ITWXSocketEventHandler implementation for TModClient
procedure TModClient.OnSocketConnect(Socket: ITWXSocket);
begin
  HandleClientConnect(Socket);
end;

procedure TModClient.OnSocketDisconnect(Socket: ITWXSocket);
begin
  HandleClientDisconnect(Socket);
end;

procedure TModClient.OnSocketRead(Socket: ITWXSocket);
begin
  HandleClientRead(Socket);
end;

procedure TModClient.OnSocketError(Socket: ITWXSocket; ErrorCode: Integer);
begin
  HandleClientError(Socket, ErrorCode);
end;

// Cross-platform event handlers
procedure TModClient.HandleClientConnect(Socket: ITWXSocket);
begin
  // MB - Clear the buffer to prevent ##### being sent to the login prompt
  FSendPending := FALSE;
  FUnsentString := '';

  // We are now connected
  TWXGUI.Connected := True;

  TWXExtractor.Reset;
  FConnecting := FALSE;

  try
    // Send Initial Handshake
    if TWXDatabase.DBHeader.UseRlogin then
      Socket.SendText(#0 + TWXDatabase.DBHeader.LoginName + #0 + #0 + #0)
    else
      Socket.SendText(#255 + OP_DO + #246);
  except
    // Error sending telnet handshake - could log this in cross-platform way if needed
  end;

  // Broadcast event
  TWXServer.Broadcast( endl + ANSI_10 + 'Connection accepted. ' + ANSI_13 + '(' + ANSI_11 + DateTimeToStr(Now)+ ANSI_13 + ')' + endl);

  TWXInterpreter.ProgramEvent('Connection accepted', '', FALSE);
  TWXLog.WriteLog(endl + endl + '--------------------------------------------------------------------------------' +
                  endl + 'Connection accepted. (' + DateTimeToStr(Now) + ')' + endl);

  // Enable the idle timer.
  tmrIdle.Enabled := TRUE;
  IdleMinutes := 0;

  // manual event - trigger login script
  if (TWXDatabase.DBHeader.UseLogin) then
  begin
    // MB - disable login if specified in TWXP.CFG for active bot, unless running Vid's Login
    if (TWXInterpreter.ActiveLoginDisabled = False) or (Pos('0_', TWXDatabase.DBHeader.LoginScript) > 0)  then
    begin
      TWXInterpreter.StopAll(FALSE);
      if (Length(TWXInterpreter.ActiveLoginScript) > 0) and (Pos('0_', TWXDatabase.DBHeader.LoginScript) = 0) then
        TWXInterpreter.Load(FetchScript(TWXGUI.ProgramDir + '\scripts\' + TWXInterpreter.ActiveLoginScript, FALSE), TRUE)
      else
        TWXInterpreter.Load(FetchScript(TWXGUI.ProgramDir + '\scripts\' + TWXDatabase.DBHeader.LoginScript, FALSE), TRUE);
    end;
  end;
end;

procedure TModClient.HandleClientDisconnect(Socket: ITWXSocket);
begin
  // No longer connected
  TWXGUI.Connected := False;
  FreconnectCount := 0;

  if FConnecting then
  begin
    if (Reconnect) and not (FUserDisconnect) then
    begin
      // MB - disable reconnect if specified in TWXP.CFG for active bot, unless running Vid's Login
      if (TWXInterpreter.ActiveLoginDisabled = False) or (Pos('0_login', lowercase(TWXDatabase.DBHeader.LoginScript)) > 0)  then
      begin
        if FReconnectDelay < 3 then
          FReconnectDelay := 3;

        TWXServer.Broadcast( ANSI_12 +'Connect Canceled. ' + ANSI_10 + 'Reconnecting in ' + ANSI_11 + IntToStr(FReconnectdelay) + ANSI_10 + ' seconds...');
        tmrReconnect.Enabled := TRUE;
        FReconnectTock := FReconnectDelay;
      end;
    end
    else
    begin
      TWXServer.Broadcast( ANSI_12 + 'Connect Canceled.');
      TWXInterpreter.ProgramEvent('Connect Canceled.', '', FALSE);
      tmrReconnect.Enabled := FALSE;
      FReconnectTock := -1;
    end;
    FConnecting := FALSE;
    FFirstConnect := FALSE;
  end
  else
  begin
    // Reconnect if supposed to
    if (Reconnect) and not (FUserDisconnect) then
    begin
      // MB - disable reconnect if specified in TWXP.CFG for active bot, unless running Vid's Login
      if (TWXInterpreter.ActiveLoginDisabled = False) or (Pos('0_login', lowercase(TWXDatabase.DBHeader.LoginScript)) > 0)  then
      begin
        TWXServer.Broadcast( endl + endl + ANSI_12 + 'Connection lost.' + ANSI_13 + '(' + ANSI_11 + DateTimeToStr(Now)+ ANSI_13 + ')' + endl);
        TWXServer.Broadcast( ANSI_10 + 'Reconnecting in ' + ANSI_11 + '3' + ANSI_10 + ' seconds...');
        tmrReconnect.Enabled := TRUE;
        FReconnectTock := 3;
      end;
    end
    else
    begin
      TWXServer.Broadcast( endl + endl + ANSI_12 + 'Connection lost. ' + ANSI_13 + '(' + ANSI_11 + DateTimeToStr(Now)+ ANSI_13 + ')' + endl + endl);
      FFirstConnect := TRUE;
    end;

    TWXInterpreter.ProgramEvent('Connection Lost', '', FALSE);
    TWXLog.WriteLog(endl + 'Connection lost. (' + DateTimeToStr(Now) + ')');
  end;
end;

procedure TModClient.HandleClientRead(Socket: ITWXSocket);
var
  InString,
  NewString,
  XString  : string;
  BufSize : integer;
  Buffer : array[0..255] of char;
begin
  InString := '';
  // Read from client socket
  BufSize := Socket.ReceiveBuf(Buffer, 256);
  while BufSize > 0 do begin
    //InString := InString + Copy(Buffer, 1, BufSize);
    SetString(NewString, Buffer, BufSize);
    InString := InString + NewString;
    BufSize := Socket.ReceiveBuf(Buffer, 256);
  end;

  XString := ProcessTelnet(InString, Socket);

  if (TWXMenu.CurrentMenu <> nil) then
    // menu prompt
    XString := chr(13) + ANSI_CLEARLINE + ANSI_MOVEUP + XString + endl + TWXMenu.GetPrompt;

  // Broadcast data to clients
  TWXServer.BroadCast(XString, FALSE, FALSE);

  // Process data for active scripts
  TWXExtractor.ProcessInBound(InString);
end;

procedure TModClient.HandleClientError(Socket: ITWXSocket; ErrorCode: Integer);
begin
  if (Reconnect) then
  begin
    if FReconnectDelay < 3 then
      FReconnectDelay := 3;

    // MB - disable reconnect if specified in TWXP.CFG for active bot, unless running Vid's Login
    if (TWXInterpreter.ActiveLoginDisabled = False) or (Pos('0_login', lowercase(TWXDatabase.DBHeader.LoginScript)) > 0)  then
    begin
      TWXServer.Broadcast( ANSI_12 +'Failed to Connect. ' + ANSI_10 + 'Reconnecting in ' + ANSI_11 + IntToStr(FReconnectdelay) + ANSI_10 + ' seconds...');
      tmrReconnect.Enabled := TRUE;
      FReconnectTock := FReconnectDelay;
    end;
  end
  else
  begin
    TWXServer.Broadcast( ANSI_12 + 'Failed to Connect.');
    TWXInterpreter.ProgramEvent('Failed to Connect.', '', FALSE);
    tmrReconnect.Enabled := FALSE;
    FReconnectTock := -1;
  end;
  FConnecting := FALSE;
  FFirstConnect := FALSE;
  CloseClient();
end;

{ TTelnetSocket }

function TTelnetSocket.ProcessTelnet(S: string; Socket: ITWXSocket): string;
var
  //SktIndex,
  I          : Integer;
  Retn       : string;
  TNOp       : Char;
  Func       : TFunc;
  SentThisOp : Boolean;

  procedure TransmitOp(Func : Char; OpCode : Byte);
  begin
    if not (FOptionSent[OpCode]) then
    begin
    FOptionSent[OpCode] := TRUE;
    try
      Socket.SendText(#255 + Char(Func) + Char(OpCode));
    except
      // Error sending telnet response - could log this in cross-platform way if needed
    end;

      if (OpCode = Byte(S[I])) then
        SentThisOp := TRUE;
    end;
  end;

begin
  // process and remove telnet commands
  Retn := '';
  Func := None;
  TNOp := #0;

  for I := 1 to Length(S) do
  begin
    if (S[I] = #255) then
    begin
      if (Func = None) then
        Func := IAC
      else if (Func = IAC) then
        Func := None // two datamarks = #255 sent to server
      else if (Func = Op) or (Func = Command) then
        Func := Done;
    end
    else
    begin
      if (Func = IAC) then
      begin
        if (S[I] = OP_SB) then
          Func := Sub
        else if (S[I] = OP_DO) or (S[I] = OP_DONT) or (S[I] = OP_WILL) or (S[I] = OP_WONT) then
        begin
          Func := Op;
          TNOp := S[I];
        end
        else
          Func := Done;
      end
      else if (Func = Op) then
      begin
        Func := Command;
        SentThisOp := FALSE;

        // negotiate operations
        if (S[I] = #246) then
        begin
          // send telnet stuff - Suppress GA, Transmit Binary, Echo
          TransmitOp(OP_WILL, 3);
          TransmitOp(OP_WILL, 0);
          TransmitOp(OP_WILL, 1);
          Func := Done; // EP
        end
        else if (TNOp = OP_DO) then
        begin
          if (S[I] = #25) or (S[I] = #1) or (S[I] = #3) or (S[I] = #0) or (S[I] = #200) then
          begin
            TransmitOp(OP_WILL, Byte(S[I]));

            //if (S[I] = #200) then
              //FClientEchoMarks[SktIndex] := TRUE;
          end
          else
            TransmitOp(OP_WONT, Byte(S[I]));
          Func := Done; // EP
        end
        else if (TNOp = OP_WILL) then
        begin
          if (S[I] = #3) // suppress goahead
            or (S[I] = #0) // transmit binary
            or (S[I] = #1) // local echo
            then
            TransmitOp(OP_DO, Byte(S[I]))
          else
            TransmitOp(OP_DONT, Byte(S[I]));
          Func := Done; // EP
        end
        else if (TNOp = OP_DONT) then
        begin
          if (S[I] = #200) then
          begin
            // don't TWX Echo Mark
            //FClientEchoMarks[SktIndex] := FALSE;
            TransmitOp(OP_WONT, 200);
          end
          else
            TransmitOp(OP_WONT, Byte(S[I])); // EP
          Func := Done; // EP
        end
        else if (TNOp = OP_WONT) then // EP - This was missing from the server function
        begin
          // Just ignore it - EP
          Func := Done; // EP
        end;

        if (FOptionSent[Byte(S[I])]) and not (SentThisOp) then
          FOptionSent[Byte(S[I])] := FALSE;
      end // end (Function = Op)
      else if (Func = Sub) then
      begin
        if (S[I] = #240) then
          Func := Done; // EP
      end
      else if (Func = Command) then
        Func := Done; // EP - Some unknown command?
    end;

    if (Func = Done) then
      Func := None
    else if (Func = None) then
      Retn := Retn + S[I];
  end;

  Result := Retn;
end;

// TClientHandlerThread implementation
constructor TClientHandlerThread.Create(ClientSocket: ITWXSocket; EventHandler: ITWXSocketEventHandler);
begin
  FClientSocket := ClientSocket;
  FEventHandler := EventHandler;
  inherited Create(False); // Start immediately
end;

destructor TClientHandlerThread.Destroy;
begin
  if Assigned(FClientSocket) then
    FClientSocket.Close;
  inherited Destroy;
end;

procedure TClientHandlerThread.Execute;
var
  Buffer: array[0..4095] of Char;
  BytesReceived: Integer;
begin
  try
    // Notify connection established
    if Assigned(FEventHandler) then
      FEventHandler.OnSocketConnect(FClientSocket);
    
    // Main client handling loop
    while not Terminated and Assigned(FClientSocket) and FClientSocket.Connected do
    begin
      try
        // Check for incoming data
        BytesReceived := FClientSocket.ReceiveBuf(Buffer, Length(Buffer));
        if BytesReceived > 0 then
        begin
          if Assigned(FEventHandler) then
            FEventHandler.OnSocketRead(FClientSocket);
        end
        else if BytesReceived = 0 then
        begin
          // Connection closed by client
          Break;
        end;
        
        // Small sleep to prevent busy waiting
        Sleep(10);
      except
        on E: Exception do
        begin
          if Assigned(FEventHandler) then
            FEventHandler.OnSocketError(FClientSocket, 0);
          Break;
        end;
      end;
    end;
  finally
    // Notify disconnection
    if Assigned(FEventHandler) then
      FEventHandler.OnSocketDisconnect(FClientSocket);
  end;
end;

// TServerAcceptThread implementation
constructor TServerAcceptThread.Create(ServerSocket: ITWXSocketEx; EventHandler: ITWXSocketEventHandler);
begin
  FServerSocket := ServerSocket;
  FEventHandler := EventHandler;
  FClientThreads := TList.Create;
  inherited Create(False); // Start immediately
end;

destructor TServerAcceptThread.Destroy;
begin
  StopAllClients;
  FClientThreads.Free;
  inherited Destroy;
end;

procedure TServerAcceptThread.StopAllClients;
var
  i: Integer;
  ClientThread: TClientHandlerThread;
begin
  for i := 0 to FClientThreads.Count - 1 do
  begin
    ClientThread := TClientHandlerThread(FClientThreads[i]);
    ClientThread.Terminate;
    ClientThread.WaitFor;
    ClientThread.Free;
  end;
  FClientThreads.Clear;
end;

procedure TServerAcceptThread.Execute;
var
  ClientSocket: ITWXSocketEx;
  ClientThread: TClientHandlerThread;
  i: Integer;
begin
  while not Terminated and Assigned(FServerSocket) do
  begin
    try
      // Try to accept a new connection (non-blocking with timeout)
      ClientSocket := FServerSocket.Accept;
      if Assigned(ClientSocket) then
      begin
        // Create a new thread to handle this client
        ClientThread := TClientHandlerThread.Create(ClientSocket, FEventHandler);
        FClientThreads.Add(ClientThread);
      end;
      
      // Clean up finished threads
      for i := FClientThreads.Count - 1 downto 0 do
      begin
        ClientThread := TClientHandlerThread(FClientThreads[i]);
        if ClientThread.Finished then
        begin
          FClientThreads.Delete(i);
          ClientThread.Free;
        end;
      end;
      
      // Small delay to prevent busy waiting
      Sleep(50);
    except
      on E: Exception do
      begin
        // Log error but continue accepting connections
        Sleep(100);
      end;
    end;
  end;
end;

end.
