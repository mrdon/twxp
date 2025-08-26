program test_simple;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils, 
  Interfaces, // this includes the LCL widgetset
  Forms;

var
  Form1: TForm;

begin
  WriteLn('Starting application...');
  Application.Initialize;
  WriteLn('Application initialized.');
  
  try
    WriteLn('Creating form...');
    Form1 := TForm.Create(nil);
    WriteLn('Form created successfully!');
    Form1.Caption := 'Test';
    Form1.Show;
    Application.Run;
  except
    on E: Exception do
    begin
      WriteLn('Error: ', E.ClassName, ': ', E.Message);
    end;
  end;
end.