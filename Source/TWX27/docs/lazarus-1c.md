# Phase 1C: Network Layer Redesign

Replace Delphi ScktComp socket components with Synapse. Rewrite TCP.pas networking layer while preserving Telnet protocol handling.

## Objectives

- [ ] Replace TServerSocket/TClientSocket with Synapse equivalents
- [ ] Rewrite TCP.pas with socket abstraction layer
- [ ] Preserve existing Telnet protocol processing
- [ ] Convert Process.pas server/client architecture
- [ ] Validate complete TWXProxy networking functionality

**Duration**: 6-9 days

## Critical Files for Network Conversion

### Primary Target: TCP.pas
```pascal
// CURRENT DEPENDENCIES (to be replaced)
ScktComp,                    // TServerSocket, TClientSocket
//OverbyteICSTnCnx,         // Commented out ICS components
//OverbyteICSWSocket,       // Commented out ICS components

// CLASSES TO REPLACE
TTelnetServerSocket = class(TTelnetSocket)
  tcpServer : TServerSocket;     // Replace with TSynapseServer

TTelnetClientSocket = class(TTelnetSocket)  
  tcpClient : TClientSocket;     // Replace with TSynapseClient
```

### Secondary Targets
```pascal
Process.pas    - Uses TCP classes for server/client communication
FormMain.pas   - Socket status display and control
GUI.pas        - Network status integration
```

## Task 1C.1: Install Synapse Package

### Install via Online Package Manager
```bash
# In Lazarus IDE:
# Tools > Online Package Manager
# Search: "synapse"
# Install: "Synapse TCP/IP Library"
# Rebuild IDE when prompted
```

### Manual Installation (if needed)
```bash
#!/bin/bash
# install_synapse.sh

echo "Installing Synapse manually..."

# Download Synapse
cd /tmp
wget https://github.com/geby/synapse/archive/master.zip
unzip master.zip
cd synapse-master

# Copy to Lazarus directory
SYNAPSE_DIR="/usr/share/lazarus/components/synapse"
sudo mkdir -p "$SYNAPSE_DIR"
sudo cp -r source/* "$SYNAPSE_DIR/"

echo "Synapse installed to $SYNAPSE_DIR"
echo "Add to project search paths: $SYNAPSE_DIR"
```

## Task 1C.2: Create Socket Abstraction Interface

**Create source/compat/TWXSockets.pas:**
```pascal
unit TWXSockets;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, 
  blcksock, synsock;  // Synapse units

type
  // Socket event types
  TTWXSocketDataEvent = procedure(Sender: TObject; const Data: string) of object;
  TTWXSocketErrorEvent = procedure(Sender: TObject; ErrorCode: Integer; const ErrorMsg: string) of object;
  TTWXSocketConnectEvent = procedure(Sender: TObject) of object;
  TTWXSocketDisconnectEvent = procedure(Sender: TObject) of object;

  // Abstract socket interface
  ITWXSocket = interface
    ['{12345678-1234-1234-1234-123456789ABC}']
    function Connected: Boolean;
    procedure Connect(const Host: string; Port: Word);
    procedure Disconnect;
    function SendData(const Data: string): Integer;
    function ReceiveData: string;
    procedure SetOnData(const Value: TTWXSocketDataEvent);
    procedure SetOnError(const Value: TTWXSocketErrorEvent);
    procedure SetOnConnect(const Value: TTWXSocketConnectEvent);
    procedure SetOnDisconnect(const Value: TTWXSocketDisconnectEvent);
  end;

  // Synapse TCP client implementation
  TTWXSynapseClient = class(TInterfacedObject, ITWXSocket)
  private
    FSocket: TTCPBlockSocket;
    FOnData: TTWXSocketDataEvent;
    FOnError: TTWXSocketErrorEvent;
    FOnConnect: TTWXSocketConnectEvent;
    FOnDisconnect: TTWXSocketDisconnectEvent;
    FConnected: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    
    // ITWXSocket implementation
    function Connected: Boolean;
    procedure Connect(const Host: string; Port: Word);
    procedure Disconnect;
    function SendData(const Data: string): Integer;
    function ReceiveData: string;
    procedure SetOnData(const Value: TTWXSocketDataEvent);
    procedure SetOnError(const Value: TTWXSocketErrorEvent);
    procedure SetOnConnect(const Value: TTWXSocketConnectEvent);
    procedure SetOnDisconnect(const Value: TTWXSocketDisconnectEvent);
  end;

  // Synapse TCP server implementation
  TTWXSynapseServer = class
  private
    FListenSocket: TTCPBlockSocket;
    FPort: Word;
    FActive: Boolean;
    FOnClientConnect: TTWXSocketConnectEvent;
    FClients: TList;
    procedure HandleClientConnection(ClientSocket: TTCPBlockSocket);
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure Listen(Port: Word);
    procedure Stop;
    property Active: Boolean read FActive;
    property OnClientConnect: TTWXSocketConnectEvent read FOnClientConnect write FOnClientConnect;
  end;

implementation

{ TTWXSynapseClient }

constructor TTWXSynapseClient.Create;
begin
  inherited Create;
  FSocket := TTCPBlockSocket.Create;
  FConnected := False;
end;

destructor TTWXSynapseClient.Destroy;
begin
  if FConnected then
    Disconnect;
  FSocket.Free;
  inherited Destroy;
end;

function TTWXSynapseClient.Connected: Boolean;
begin
  Result := FConnected and (FSocket.LastError = 0);
end;

procedure TTWXSynapseClient.Connect(const Host: string; Port: Word);
begin
  FSocket.Connect(Host, IntToStr(Port));
  FConnected := (FSocket.LastError = 0);
  
  if FConnected then
  begin
    if Assigned(FOnConnect) then
      FOnConnect(Self);
  end
  else
  begin
    if Assigned(FOnError) then
      FOnError(Self, FSocket.LastError, FSocket.LastErrorDesc);
  end;
end;

procedure TTWXSynapseClient.Disconnect;
begin
  if FConnected then
  begin
    FSocket.CloseSocket;
    FConnected := False;
    if Assigned(FOnDisconnect) then
      FOnDisconnect(Self);
  end;
end;

function TTWXSynapseClient.SendData(const Data: string): Integer;
begin
  if FConnected then
  begin
    FSocket.SendString(Data);
    Result := Length(Data);
    if FSocket.LastError <> 0 then
    begin
      if Assigned(FOnError) then
        FOnError(Self, FSocket.LastError, FSocket.LastErrorDesc);
      Result := -1;
    end;
  end
  else
    Result := -1;
end;

function TTWXSynapseClient.ReceiveData: string;
begin
  Result := '';
  if FConnected then
  begin
    Result := FSocket.RecvPacket(1000); // 1 second timeout
    if (FSocket.LastError <> 0) and (FSocket.LastError <> WSAETIMEDOUT) then
    begin
      if Assigned(FOnError) then
        FOnError(Self, FSocket.LastError, FSocket.LastErrorDesc);
    end;
  end;
end;

procedure TTWXSynapseClient.SetOnData(const Value: TTWXSocketDataEvent);
begin
  FOnData := Value;
end;

procedure TTWXSynapseClient.SetOnError(const Value: TTWXSocketErrorEvent);
begin
  FOnError := Value;
end;

procedure TTWXSynapseClient.SetOnConnect(const Value: TTWXSocketConnectEvent);
begin
  FOnConnect := Value;
end;

procedure TTWXSynapseClient.SetOnDisconnect(const Value: TTWXSocketDisconnectEvent);
begin
  FOnDisconnect := Value;
end;

{ TTWXSynapseServer }

constructor TTWXSynapseServer.Create;
begin
  inherited Create;
  FListenSocket := TTCPBlockSocket.Create;
  FClients := TList.Create;
  FActive := False;
end;

destructor TTWXSynapseServer.Destroy;
begin
  Stop;
  FListenSocket.Free;
  FClients.Free;
  inherited Destroy;
end;

procedure TTWXSynapseServer.Listen(Port: Word);
begin
  FPort := Port;
  FListenSocket.Bind('0.0.0.0', IntToStr(Port));
  FListenSocket.Listen;
  FActive := (FListenSocket.LastError = 0);
  
  // In real implementation, this would run in a thread
  // For now, just set up the listening socket
end;

procedure TTWXSynapseServer.Stop;
begin
  if FActive then
  begin
    FListenSocket.CloseSocket;
    FActive := False;
  end;
end;

procedure TTWXSynapseServer.HandleClientConnection(ClientSocket: TTCPBlockSocket);
begin
  // Handle new client connection
  if Assigned(FOnClientConnect) then
    FOnClientConnect(Self);
end;

end.
```

## Task 1C.3: Rewrite TCP.pas Core Classes

**Conversion Strategy for TTelnetSocket:**
```pascal
// BEFORE (Delphi ScktComp)
TTelnetServerSocket = class(TTelnetSocket)
private
  tcpServer : TServerSocket;
public
  procedure tcpServerOnGetSocket(Sender: TObject; Socket: Integer; var ClientSocket: TCustomServerClientWinSocket);
  procedure tcpServerOnClientConnect(Sender: TObject; Socket: TCustomWinSocket);
  procedure tcpServerOnClientDisconnect(Sender: TObject; Socket: TCustomWinSocket);
  procedure tcpServerOnClientRead(Sender: TObject; Socket: TCustomWinSocket);
end;

// AFTER (Synapse)
TTelnetServerSocket = class(TTelnetSocket)
private
  FServer: TTWXSynapseServer;
  FClients: TList; // List of ITWXSocket
public
  procedure OnClientConnect(Sender: TObject);
  procedure OnClientDisconnect(Sender: TObject);  
  procedure OnClientData(Sender: TObject; const Data: string);
  procedure OnClientError(Sender: TObject; ErrorCode: Integer; const ErrorMsg: string);
end;
```

**ProcessTelnet Method - No Changes Needed:**
```pascal
// This core method runs unmodified - it's pure Pascal string processing
// The Telnet protocol logic itself doesn't need any changes for Lazarus
function TTelnetSocket.ProcessTelnet(S: string; Socket: TCustomWinSocket): string;
var
  I: Integer;
  Func: TFunc;
  OutString: string;
  C: Char;
begin
  // ALL EXISTING TELNET LOGIC REMAINS UNCHANGED
  // This is just string manipulation - no Delphi-specific code
  
  OutString := '';
  Func := None;
  
  for I := 1 to Length(S) do
  begin
    C := S[I];
    case Func of
      None:
        if C = #255 then  // IAC (Interpret As Command)
          Func := IAC
        else
          OutString := OutString + C;
      // ... rest of existing logic unchanged
    end;
  end;
  
  Result := OutString;
end;

// ONLY the socket parameter type needs updating:
// Change: Socket: TCustomWinSocket  
// To:     Socket: ITWXSocket
// But the method body remains identical
```

## Task 1C.4: Convert TModServer Class

**Key Changes in TCP.pas TModServer:**
```pascal
TModServer = class(TTelnetServerSocket, IModServer)
private
  FServer: TTWXSynapseServer;        // Replace tcpServer
  FClientSockets: array[0..255] of ITWXSocket; // Replace TCustomWinSocket array
  
  procedure OnServerClientConnect(Sender: TObject);
  procedure OnServerClientDisconnect(Sender: TObject);
  procedure OnServerClientData(Sender: TObject; const Data: string);
  
public  
  constructor Create(AOwner: TComponent; PersistenceManager: TPersistenceManager); override;
  destructor Destroy; override;
  
  procedure Activate; override;
  procedure Deactivate; override;
  
  // IModServer interface  
  procedure Broadcast(Msg: string); override;
  procedure ClientMessage(Msg: string); override;
  function ClientsConnected: Integer; override;
end;
```

**Constructor Conversion:**
```pascal
constructor TModServer.Create(AOwner: TComponent; PersistenceManager: TPersistenceManager);
var
  I: Integer;
begin
  inherited Create(AOwner, PersistenceManager);
  
  // Initialize client array
  for I := 0 to 255 do
    FClientSockets[I] := nil;
    
  // Create Synapse server
  FServer := TTWXSynapseServer.Create;
  FServer.OnClientConnect := OnServerClientConnect;
  
  FCurrentClient := -1;
  FBufferOut := TStringList.Create;
  
  // Rest of initialization...
end;
```

**Activate Method Conversion:**
```pascal
procedure TModServer.Activate;
begin
  if not FServer.Active then
  begin
    FServer.Listen(FListenPort);
    if FServer.Active then
      TWXServer.ClientMessage('Server listening on port ' + IntToStr(FListenPort))
    else
      raise Exception.Create('Failed to start server on port ' + IntToStr(FListenPort));
  end;
end;
```

## Task 1C.5: Convert TModClient Class

**TModClient Socket Replacement:**
```pascal
TModClient = class(TTelnetClientSocket, IModClient)  
private
  FClient: ITWXSocket;               // Replace tcpClient
  FConnected: Boolean;
  FAutoReconnect: Boolean;
  
  procedure OnClientConnect(Sender: TObject);
  procedure OnClientDisconnect(Sender: TObject);
  procedure OnClientData(Sender: TObject; const Data: string);
  procedure OnClientError(Sender: TObject; ErrorCode: Integer; const ErrorMsg: string);
  
public
  constructor Create(AOwner: TComponent; PersistenceManager: TPersistenceManager); override;
  destructor Destroy; override;
  
  // IModClient interface
  procedure Connect(Address: string; Port: Word); override;
  procedure Disconnect; override;  
  procedure Send(OutText: string); override;
  function Connected: Boolean; override;
end;
```

**Connect Method Implementation:**
```pascal
procedure TModClient.Connect(Address: string; Port: Word);
begin
  if not Assigned(FClient) then
  begin
    FClient := TTWXSynapseClient.Create;
    FClient.SetOnConnect(OnClientConnect);
    FClient.SetOnDisconnect(OnClientDisconnect);
    FClient.SetOnData(OnClientData);
    FClient.SetOnError(OnClientError);
  end;
  
  if not FClient.Connected then
  begin
    TWXServer.ClientMessage('Connecting to ' + Address + ':' + IntToStr(Port) + '...');
    FClient.Connect(Address, Port);
  end;
end;
```

## Task 1C.6: Threading Considerations

**Server Threading (if needed):**
```pascal
// Create separate unit: source/core/TWXServerThread.pas
unit TWXServerThread;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, TWXSockets;

type
  TTWXServerThread = class(TThread)
  private
    FServer: TTWXSynapseServer;
    FOnClientConnect: TTWXSocketConnectEvent;
  protected
    procedure Execute; override;
  public
    constructor Create(AServer: TTWXSynapseServer);
    property OnClientConnect: TTWXSocketConnectEvent read FOnClientConnect write FOnClientConnect;
  end;

implementation

constructor TTWXServerThread.Create(AServer: TTWXSynapseServer);
begin
  FServer := AServer;
  inherited Create(False); // Start immediately
end;

procedure TTWXServerThread.Execute;
var
  ClientSocket: TTCPBlockSocket;
begin
  while not Terminated do
  begin
    if FServer.Active then
    begin
      // Accept connections in thread
      // Implementation depends on threading requirements
    end;
    Sleep(100); // Prevent CPU hogging
  end;
end;

end.
```

## Task 1C.7: Update Project Dependencies

**Add Synapse to TWXP.lpi:**
```xml
<RequiredPackages Count="2">
  <Item1>
    <PackageName Value="LCL"/>
  </Item1>
  <Item2>
    <PackageName Value="SynapsePak"/>
  </Item2>
</RequiredPackages>
```

**Update uses clauses in TCP.pas:**
```pascal
uses
  SysUtils, Windows, Classes,
  // Remove: ScktComp, OverbyteICS*
  // Add: Synapse units
  blcksock, synsock, synautil,
  ExtCtrls, Database, Core, TWXSockets, TWXCompat;
```

## Task 1C.8: Message System Conversion

**Windows Message System Replacement:**
```pascal
// BEFORE (Windows-specific message system)
procedure TMessageHandler.OnApplicationMessage(var Msg: TMsg; var Handled: Boolean);
var
  NotificationEvent: TNotificationEvent;
begin
  if (Msg.Message = WM_USER) and (Msg.wParam <> 47806) then
  begin
    NotificationEvent := TNotificationEvent(Pointer(Msg.wParam)^);
    NotificationEvent(Pointer(Msg.lParam));
    Dispose(Pointer(Msg.wParam));
    Handled := True;
  end;
end;

// AFTER (Cross-platform event system)
// Replace Windows messages with direct event notifications
type
  TTWXNotificationEvent = procedure(Sender: TObject; Data: Pointer) of object;
  
  TTWXEventDispatcher = class
  private
    FEventHandlers: TList;
  public
    procedure RegisterHandler(Handler: TTWXNotificationEvent);
    procedure UnregisterHandler(Handler: TTWXNotificationEvent);
    procedure DispatchEvent(Sender: TObject; Data: Pointer);
  end;

// Usage: Replace PostMessage(Application.Handle, WM_USER, ...)
// With: EventDispatcher.DispatchEvent(Self, EventData);
```

## Task 1C.9: Testing & Validation

**Create Network Test Suite:**
```pascal
// tests/TestNetworking.pas
unit TestNetworking;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  TWXSockets, TCP;

type
  TTestNetworking = class(TTestCase)
  private
    FClient: ITWXSocket;
    FServer: TTWXSynapseServer;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestSocketCreation;
    procedure TestClientConnection;
    procedure TestServerListening;
    procedure TestDataTransmission;
    procedure TestTelnetProcessing;
  end;

implementation

procedure TTestNetworking.SetUp;
begin
  FClient := TTWXSynapseClient.Create;
  FServer := TTWXSynapseServer.Create;
end;

procedure TTestNetworking.TearDown;
begin
  FClient := nil; // Interface will free automatically
  FServer.Free;
end;

procedure TTestNetworking.TestSocketCreation;
begin
  AssertNotNull('Client socket should be created', FClient);
  AssertNotNull('Server should be created', FServer);
  AssertFalse('Client should not be connected initially', FClient.Connected);
  AssertFalse('Server should not be active initially', FServer.Active);
end;

procedure TTestNetworking.TestServerListening;
begin
  FServer.Listen(2023); // Use non-standard port for testing
  AssertTrue('Server should be listening', FServer.Active);
end;

procedure TTestNetworking.TestTelnetProcessing;
var
  TelnetSocket: TTelnetSocket;
  Input, Output: string;
begin
  TelnetSocket := TTelnetSocket.Create(nil);
  try
    // Test basic string (no Telnet commands)
    Input := 'Hello World';
    Output := TelnetSocket.ProcessTelnet(Input, nil); // nil for interface
    AssertEquals('Basic string should pass through', Input, Output);
    
    // Test Telnet IAC sequence
    Input := 'Before' + #255 + #251 + #1 + 'After'; // IAC WILL ECHO
    Output := TelnetSocket.ProcessTelnet(Input, nil);
    AssertEquals('Telnet commands should be filtered', 'BeforeAfter', Output);
  finally
    TelnetSocket.Free;
  end;
end;

initialization
  RegisterTest(TTestNetworking);
end.
```

**Functional Test Script:**
```bash
#!/bin/bash
# test_networking.sh

echo "=== Testing TWXProxy Networking ==="

# Start TWXProxy in background
./build/release/TWXProxy &
PROXY_PID=$!

# Wait for startup
sleep 2

# Test basic connection
echo "Testing telnet connection..."
timeout 5s telnet localhost 23 < /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Telnet connection successful"
else
    echo "❌ Telnet connection failed"
fi

# Test with multiple clients
echo "Testing multiple connections..."
for i in {1..3}; do
    timeout 2s telnet localhost 23 < /dev/null &
done
wait

# Cleanup
kill $PROXY_PID 2>/dev/null

echo "=== Network testing complete ==="
```

## Task 1C.10: Validation Checklist

### Compilation Success
- [ ] TCP.pas compiles with Synapse dependencies
- [ ] TWXProxy.exe links and builds successfully
- [ ] TWXP.exe builds with networking components  
- [ ] All socket abstraction interfaces compile
- [ ] No Delphi ScktComp dependencies remain
- [ ] Synapse package integration working

### Functional Validation
- [ ] TWXProxy starts and listens on configured port
- [ ] Telnet clients can connect successfully
- [ ] Telnet protocol processing preserved (IAC, WILL, etc.)
- [ ] Multiple client connections supported
- [ ] Client/server disconnection handled gracefully
- [ ] Message routing between clients works
- [ ] No socket handle leaks detected

### Integration Testing
- [ ] Database operations work with networking active
- [ ] Script engine integrates with network events
- [ ] UI forms display network status correctly
- [ ] Application shutdown closes sockets cleanly
- [ ] Cross-platform networking validated (Linux/Windows)

## Deliverables

1. **TWXSockets.pas** - Socket abstraction layer with Synapse implementation
2. **Converted TCP.pas** - Core networking with preserved Telnet handling
3. **Updated TWXProxy.lpr** - Complete networking application
4. **Network test suite** - Automated testing for socket functionality
5. **Performance validation** - Networking performance benchmarks
6. **Complete TWX Proxy** - Fully functional cross-platform application

**Outcome**: Complete Delphi to Lazarus conversion with functional networking layer.

---
*Duration*: 6-9 days  
*Risk*: HIGH (networking complexity)  
*Dependencies*: Phase 1B complete  
*Output*: Complete TWX Proxy application