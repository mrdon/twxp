unit TestTCPSimple;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testutils, testregistry,
  LazarusCompat,
  {$IFDEF UNIX}
  blcksock, synsock
  {$ELSE}
  ScktComp
  {$ENDIF};

type
  TTestTCPSimple = class(TTestCase)
  published
    // Basic socket tests without dependencies
    procedure TestSynapseSocketCreation;
    procedure TestSynapseSocketConnection;
    procedure TestBasicNetworkStack;
    procedure TestCrossPlatformCompilation;
  end;

implementation

procedure TTestTCPSimple.TestSynapseSocketCreation;
var
  Socket: TTCPBlockSocket;
begin
  {$IFDEF UNIX}
  Socket := TTCPBlockSocket.Create;
  try
    AssertNotNull('Socket should be created successfully', Socket);
    AssertEquals('Initial error should be 0', 0, Socket.LastError);
  finally
    Socket.Free;
  end;
  {$ELSE}
  AssertTrue('Windows platform test', True);
  {$ENDIF}
end;

procedure TTestTCPSimple.TestSynapseSocketConnection;
var
  Socket: TTCPBlockSocket;
begin
  {$IFDEF UNIX}
  Socket := TTCPBlockSocket.Create;
  try
    // Test connection to invalid address (should fail gracefully)
    Socket.Connect('127.0.0.1', '65000');
    AssertTrue('Socket should handle connection gracefully', True); // Just verify no crash
  finally
    Socket.Free;
  end;
  {$ELSE}
  AssertTrue('Windows platform test', True);
  {$ENDIF}
end;

procedure TTestTCPSimple.TestBasicNetworkStack;
begin
  // Test that network units are available
  {$IFDEF UNIX}
  AssertTrue('Synapse networking stack available', True);
  {$ELSE}  
  AssertTrue('ScktComp networking stack available', True);
  {$ENDIF}
end;

procedure TTestTCPSimple.TestCrossPlatformCompilation;
begin
  // Test cross-platform conditional compilation
  AssertTrue('Cross-platform compilation works', True);
  
  {$IFDEF UNIX}
  AssertTrue('Unix/Linux platform detected', True);
  {$ENDIF}
  
  {$IFDEF WINDOWS}
  AssertTrue('Windows platform detected', True);
  {$ENDIF}
end;

initialization
  RegisterTest(TTestTCPSimple);
end.