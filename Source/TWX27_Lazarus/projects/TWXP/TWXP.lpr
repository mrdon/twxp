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
program TWXP;

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms,
  Classes,
  {$IFDEF WINDOWS}Windows,{$ENDIF}
  SysUtils,
  Core,
  FormMain,
  FormAbout,
  FormSetup,
  FormHistory,
  FormLicense,
  FormUpgrade,
  FormScript,
  FormChangeIcon,
  GUI,
  Menu,
  Database,
  TCP,
  TWXProcess,
  Script,
  ScriptCmd,
  ScriptCmp,
  ScriptRef,
  Utility,
  Global,
  Observer,
  Log,
  Bubble,
  Persistence,
  Ansi,
  Encryptor,
  LazarusCompat;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  Application.Title := 'TWX Proxy';
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.