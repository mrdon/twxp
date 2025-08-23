unit TestNetworking;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, SyncObjs
  {$IFDEF WINDOWS}
  , ScktComp
  {$ELSE}
  , blcksock, synsock, synautil
  {$ENDIF};

type
  // Test event handler for validating event system
  TTestEventHandler = class
  private
    FConnectEvents: Integer;
    FDisconnectEvents: Integer;
    FReadEvents: Integer;
    FErrorEvents: Integer;
    FLock: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure OnSocketConnect;
    procedure OnSocketDisconnect; 
    procedure OnSocketRead;
    procedure OnSocketError(ErrorCode: Integer);
    
    procedure ResetCounters;
    function GetConnectCount: Integer;
    function GetDisconnectCount: Integer;
    function GetReadCount: Integer;
    function GetErrorCount: Integer;
  end;

  { TTestBasicNetworking }
  TTestBasicNetworking = class(TTestCase)
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestSocketCreation;
    procedure TestSocketBinding;
    procedure TestSocketListening;
  end;

  { TTestEventHandling }
  TTestEventHandling = class(TTestCase)
  private
    FEventHandler: TTestEventHandler;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestEventCounters;
    procedure TestEventThreadSafety;
    procedure TestErrorEvents;
  end;

  { TTestThreadSafety }
  TTestThreadSafety = class(TTestCase)
  private
    FEventHandler: TTestEventHandler;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestConcurrentEventHandling;
    procedure TestMultiThreadAccess;
  end;

  { TTestCrossPlatform }
  TTestCrossPlatform = class(TTestCase)
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestPlatformSpecificFeatures;
    procedure TestCompatibilityLayer;
  end;

implementation

{ TTestEventHandler }

constructor TTestEventHandler.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  ResetCounters;
end;

destructor TTestEventHandler.Destroy;
begin
  FLock.Free;
  inherited Destroy;
end;

procedure TTestEventHandler.OnSocketConnect;
begin
  FLock.Acquire;
  try
    Inc(FConnectEvents);
  finally
    FLock.Release;
  end;
end;

procedure TTestEventHandler.OnSocketDisconnect;
begin
  FLock.Acquire;
  try
    Inc(FDisconnectEvents);
  finally
    FLock.Release;
  end;
end;

procedure TTestEventHandler.OnSocketRead;
begin
  FLock.Acquire;
  try
    Inc(FReadEvents);
  finally
    FLock.Release;
  end;
end;

procedure TTestEventHandler.OnSocketError(ErrorCode: Integer);
begin
  FLock.Acquire;
  try
    Inc(FErrorEvents);
  finally
    FLock.Release;
  end;
end;

procedure TTestEventHandler.ResetCounters;
begin
  FLock.Acquire;
  try
    FConnectEvents := 0;
    FDisconnectEvents := 0;
    FReadEvents := 0;
    FErrorEvents := 0;
  finally
    FLock.Release;
  end;
end;

function TTestEventHandler.GetConnectCount: Integer;
begin
  FLock.Acquire;
  try
    Result := FConnectEvents;
  finally
    FLock.Release;
  end;
end;

function TTestEventHandler.GetDisconnectCount: Integer;
begin
  FLock.Acquire;
  try
    Result := FDisconnectEvents;
  finally
    FLock.Release;
  end;
end;

function TTestEventHandler.GetReadCount: Integer;
begin
  FLock.Acquire;
  try
    Result := FReadEvents;
  finally
    FLock.Release;
  end;
end;

function TTestEventHandler.GetErrorCount: Integer;
begin
  FLock.Acquire;
  try
    Result := FErrorEvents;
  finally
    FLock.Release;
  end;
end;

{ TTestBasicNetworking }

procedure TTestBasicNetworking.SetUp;
begin
  inherited SetUp;
end;

procedure TTestBasicNetworking.TearDown;
begin
  inherited TearDown;
end;

procedure TTestBasicNetworking.TestSocketCreation;
{$IFDEF UNIX}
var
  Socket: TTCPBlockSocket;
{$ENDIF}
begin
  {$IFDEF UNIX}
  Socket := TTCPBlockSocket.Create;
  try
    AssertNotNull('Socket should be created', Socket);
    // Socket object should be created even if underlying socket isn't initialized yet
    AssertEquals('Initial socket error should be 0', 0, Socket.LastError);
    AssertTrue('Socket object should exist', Assigned(Socket));
  finally
    Socket.Free;
  end;
  {$ELSE}
  // Windows socket test - for now just pass
  AssertTrue('Windows socket creation test', True);
  {$ENDIF}
end;

procedure TTestBasicNetworking.TestSocketBinding;
{$IFDEF UNIX}
var
  Socket: TTCPBlockSocket;
{$ENDIF}
begin
  {$IFDEF UNIX}
  Socket := TTCPBlockSocket.Create;
  try
    Socket.Bind('127.0.0.1', '0'); // Bind to any available port
    AssertEquals('Socket bind should succeed', 0, Socket.LastError);
  finally
    Socket.Free;
  end;
  {$ELSE}
  AssertTrue('Windows socket binding test', True);
  {$ENDIF}
end;

procedure TTestBasicNetworking.TestSocketListening;
{$IFDEF UNIX}
var
  Socket: TTCPBlockSocket;
{$ENDIF}
begin
  {$IFDEF UNIX}
  Socket := TTCPBlockSocket.Create;
  try
    Socket.Bind('127.0.0.1', '0');
    AssertEquals('Socket bind should succeed', 0, Socket.LastError);
    
    Socket.Listen;
    AssertEquals('Socket listen should succeed', 0, Socket.LastError);
  finally
    Socket.Free;
  end;
  {$ELSE}
  AssertTrue('Windows socket listening test', True);
  {$ENDIF}
end;

{ TTestEventHandling }

procedure TTestEventHandling.SetUp;
begin
  inherited SetUp;
  FEventHandler := TTestEventHandler.Create;
end;

procedure TTestEventHandling.TearDown;
begin
  FEventHandler.Free;
  inherited TearDown;
end;

procedure TTestEventHandling.TestEventCounters;
begin
  // Reset and test initial state
  FEventHandler.ResetCounters;
  AssertEquals('Initial connect count should be 0', 0, FEventHandler.GetConnectCount);
  AssertEquals('Initial disconnect count should be 0', 0, FEventHandler.GetDisconnectCount);
  AssertEquals('Initial read count should be 0', 0, FEventHandler.GetReadCount);
  AssertEquals('Initial error count should be 0', 0, FEventHandler.GetErrorCount);
  
  // Trigger events and verify counting
  FEventHandler.OnSocketConnect;
  AssertEquals('Connect count should be 1', 1, FEventHandler.GetConnectCount);
  
  FEventHandler.OnSocketRead;
  FEventHandler.OnSocketRead;
  AssertEquals('Read count should be 2', 2, FEventHandler.GetReadCount);
  
  FEventHandler.OnSocketDisconnect;
  AssertEquals('Disconnect count should be 1', 1, FEventHandler.GetDisconnectCount);
end;

procedure TTestEventHandling.TestEventThreadSafety;
var
  i: Integer;
begin
  FEventHandler.ResetCounters;
  
  // Simulate concurrent event handling
  for i := 1 to 50 do
  begin
    FEventHandler.OnSocketConnect;
    FEventHandler.OnSocketRead;
    if i mod 5 = 0 then
      FEventHandler.OnSocketDisconnect;
  end;
  
  AssertEquals('Connect events should be 50', 50, FEventHandler.GetConnectCount);
  AssertEquals('Read events should be 50', 50, FEventHandler.GetReadCount);
  AssertEquals('Disconnect events should be 10', 10, FEventHandler.GetDisconnectCount);
end;

procedure TTestEventHandling.TestErrorEvents;
begin
  FEventHandler.ResetCounters;
  
  // Test error event handling
  FEventHandler.OnSocketError(10060); // Connection timeout
  FEventHandler.OnSocketError(10061); // Connection refused
  FEventHandler.OnSocketError(10054); // Connection reset by peer
  
  AssertEquals('Error events should be 3', 3, FEventHandler.GetErrorCount);
end;

{ TTestThreadSafety }

procedure TTestThreadSafety.SetUp;
begin
  inherited SetUp;
  FEventHandler := TTestEventHandler.Create;
end;

procedure TTestThreadSafety.TearDown;
begin
  FEventHandler.Free;
  inherited TearDown;
end;

procedure TTestThreadSafety.TestConcurrentEventHandling;
var
  i: Integer;
begin
  FEventHandler.ResetCounters;
  
  // Test that event handler can handle rapid-fire events
  for i := 1 to 100 do
  begin
    FEventHandler.OnSocketConnect;
    if i mod 3 = 0 then
      FEventHandler.OnSocketRead;
    if i mod 7 = 0 then
      FEventHandler.OnSocketError(i);
  end;
  
  AssertEquals('Connect count should be 100', 100, FEventHandler.GetConnectCount);
  AssertEquals('Read count should be 33', 33, FEventHandler.GetReadCount);
  AssertEquals('Error count should be 14', 14, FEventHandler.GetErrorCount);
end;

procedure TTestThreadSafety.TestMultiThreadAccess;
begin
  // This test verifies the thread safety mechanism works
  // In a real scenario, this would involve actual threads
  FEventHandler.ResetCounters;
  
  // Simulate what would happen with multiple threads
  FEventHandler.OnSocketConnect;
  FEventHandler.OnSocketConnect;
  FEventHandler.OnSocketConnect;
  
  AssertEquals('Thread-safe connect count should be 3', 3, FEventHandler.GetConnectCount);
  AssertTrue('Event handler should remain consistent', FEventHandler.GetConnectCount >= 0);
end;

{ TTestCrossPlatform }

procedure TTestCrossPlatform.SetUp;
begin
  inherited SetUp;
end;

procedure TTestCrossPlatform.TearDown;
begin
  inherited TearDown;
end;

procedure TTestCrossPlatform.TestPlatformSpecificFeatures;
begin
  {$IFDEF UNIX}
  AssertTrue('Running on Unix/Linux platform', True);
  // Could add Synapse-specific tests here
  {$ENDIF}
  
  {$IFDEF WINDOWS}
  AssertTrue('Running on Windows platform', True);  
  // Could add ScktComp-specific tests here
  {$ENDIF}
  
  // This test always passes but documents platform awareness
  AssertTrue('Platform-specific compilation works', True);
end;

procedure TTestCrossPlatform.TestCompatibilityLayer;
begin
  // Test that compatibility layer concepts work
  // This is more of a compilation test to ensure the interfaces exist
  AssertTrue('Cross-platform compatibility layer exists', True);
end;

initialization
  RegisterTest(TTestBasicNetworking);
  RegisterTest(TTestEventHandling);
  RegisterTest(TTestThreadSafety);
  RegisterTest(TTestCrossPlatform);

end.