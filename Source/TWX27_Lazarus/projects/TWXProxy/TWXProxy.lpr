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
program TWXProxy;

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms,
  Classes,
  {$IFDEF WINDOWS}Windows,{$ENDIF}
  SysUtils,
  Dialogs,
  FileCtrl,
  FormMain,
  FormSetup,
  FormHistory,
  FormAbout,
  FormLicense,
  FormUpgrade,
  FormScript,
  FormChangeIcon,
  Core,
  TWXProcess,
  Script,
  ScriptCmd,
  ScriptCmp,
  ScriptRef,
  Menu,
  Database,
  TCP,
  Utility,
  Bubble,
  Log,
  GUI,
  Observer,
  Persistence,
  Auth,
  Global,
  Ansi,
  Encryptor,
  LazarusCompat;

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.