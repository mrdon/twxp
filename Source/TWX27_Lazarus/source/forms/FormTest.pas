unit FormTest;

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs;

type
  TfrmTest = class(TForm)
  private

  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  frmTest: TfrmTest;

implementation

{$R *.lfm}

constructor TfrmTest.Create(AOwner: TComponent);
begin
  WriteLn('TfrmTest: Starting minimal constructor');
  inherited Create(AOwner);
  WriteLn('TfrmTest: SUCCESS - minimal form created!');
end;

end.