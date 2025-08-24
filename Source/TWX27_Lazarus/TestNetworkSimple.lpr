{$mode objfpc}{$H+}
program TestNetworkSimple;

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils, TCP;

var
  Socket: ITWXSocketEx;
  
begin
  WriteLn('Testing network socket creation...');
  
  try
    {$IFDEF UNIX}
    Socket := TTWXSynapseSocketEx.CreateClient;
    WriteLn('Synapse client socket created successfully');
    Socket.Close;
    
    Socket := TTWXSynapseSocketEx.CreateServer;
    WriteLn('Synapse server socket created successfully');
    Socket.Close;
    {$ELSE}
    Socket := TTWXWinSocketEx.CreateClient(nil);
    WriteLn('Windows client socket created successfully');
    Socket.Close;
    
    Socket := TTWXWinSocketEx.CreateServer(nil);
    WriteLn('Windows server socket created successfully');
    Socket.Close;
    {$ENDIF}
    
    WriteLn('All network tests passed!');
    
  except
    on E: Exception do
    begin
      WriteLn('Error: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.