program TestRunner;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils, consoletestrunner,
  // Import all test units
  TestLazarusCompat,
  TestTCP,
  TestNetworking,
  TestTradeWarsIntegration;

type
  TTWXTestRunner = class(TTestRunner)
  protected
    procedure WriteCustomHelp; override;
  end;

procedure TTWXTestRunner.WriteCustomHelp;
begin
  inherited WriteCustomHelp;
  WriteLn('TWX Proxy Cross-Platform Unit Tests');
  WriteLn('====================================');
  WriteLn('');
  WriteLn('These tests validate the cross-platform migration components:');
  WriteLn('- LazarusCompat: Cross-platform abstraction layer');
  WriteLn('- TCP: Network communication layer');
  WriteLn('- Networking: Phase 1C network layer validation');
  WriteLn('- TradeWarsIntegration: Real server connectivity tests');
  WriteLn('- Configuration system');
  WriteLn('- File operations');
  WriteLn('- Hardware identification');
  WriteLn('');
  WriteLn('Usage examples:');
  WriteLn('  ./TestRunner                    # Run all tests');
  WriteLn('  ./TestRunner --suite=TTestLazarusCompat  # Run specific test suite');
  WriteLn('  ./TestRunner --verbose          # Verbose output');
  WriteLn('');
end;

var
  App: TTWXTestRunner;

begin
  // Initialize random seed for test data
  Randomize;
  
  // Create and configure test runner
  App := TTWXTestRunner.Create(nil);
  try
    App.Title := 'TWX Proxy Cross-Platform Unit Tests';
    
    // Run the tests
    App.Initialize;
    App.Run;
  finally
    App.Free;
  end;
end.