{$mode objfpc}{$H+}
unit FormChangeIcon;

interface

uses
  {$IFDEF WINDOWS}Windows, Messages, shellapi, comobj,{$ENDIF} SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ComCtrls;

type
  TfrmChangeIcon = class(TForm)
    IconListView: TListView;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmChangeIcon: TfrmChangeIcon;
  ImageList1: TimageList;

implementation

{$R *.lfm}

procedure TfrmChangeIcon.FormCreate(Sender: TObject);
begin
  // Icon extraction not supported in cross-platform version
  // TODO: Implement cross-platform icon handling
end;


procedure TfrmChangeIcon.FormDestroy(Sender: TObject);
begin
  ImageList1.free;
end;

end.
