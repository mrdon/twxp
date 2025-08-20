# Phase 1B: Core Library Conversion

Convert all core Pascal units (Database, Script, Utility, etc.) and UI forms. Create compatibility framework for Windows API dependencies.

## Objectives

- [ ] Convert 13 core units to FreePascal compatibility
- [ ] Convert 10 form units with .dfm→.lfm
- [ ] Create TWXCompat.pas for Windows API abstractions
- [ ] Establish cross-platform file handling
- [ ] Validate all units compile without networking dependencies

**Duration**: 4-6 days

## Core Units to Convert

### Priority 1 (No Dependencies)
```
Database.pas     - Custom binary database engine
Utility.pas      - String/file utility functions  
Ansi.pas         - ANSI text processing
Global.pas       - Constants and global variables
Encryptor.pas    - Encryption utilities
```

### Priority 2 (Form Dependencies)
```
FormAbout.pas    - About dialog
FormHistory.pas  - History viewer
FormLicense.pas  - License dialog
FormSetup.pas    - Configuration dialog
FormUpgrade.pas  - Upgrade dialog
FormChangeIcon.pas - Icon selector
Debug.pas        - Debug window
```

### Priority 3 (Business Logic - No Delphi Dependencies)
```
Script.pas       - Scripting engine (pure Pascal string processing)
ScriptCmd.pas    - Script commands (pure Pascal logic)
ScriptCmp.pas    - Script compilation (pure Pascal AST parsing)
ScriptRef.pas    - Script references (pure Pascal data structures)
Menu.pas         - Menu management (standard VCL components)
```

**Note**: These files contain large amounts of Pascal code but no Delphi-specific dependencies. They convert using standard patterns - mainly adding `{$mode objfpc}{$H+}` and updating uses clauses.

## Task 1B.1: Create Compatibility Framework

**Create source/compat/TWXCompat.pas:**
```pascal
unit TWXCompat;
{$mode objfpc}{$H+}

interface

uses
  {$IFDEF WINDOWS}
  Windows,
  {$ELSE}
  LCLIntf, LCLType, BaseUnix, Unix,
  {$ENDIF}
  Classes, SysUtils, FileUtil;

const
  {$IFDEF WINDOWS}
  PathSep = '\';
  LineEnding = #13#10;
  {$ELSE}
  PathSep = '/';
  LineEnding = #10;
  {$ENDIF}

// File operations
function TWX_CreateFile(const FileName: string; Access, Share, Creation: DWord): THandle;
function TWX_CloseHandle(Handle: THandle): Boolean;
function TWX_GetCurrentDir: string;
function TWX_DirectoryExists(const Dir: string): Boolean;
function TWX_CreateDir(const Dir: string): Boolean;

// Search operations  
function TWX_FindFirst(const Path: string; Attr: Integer; var F: TSearchRec): Integer;
function TWX_FindNext(var F: TSearchRec): Integer;
procedure TWX_FindClose(var F: TSearchRec);

// String operations
function StrToIntSafe(const S: string): Integer;
function StripFileExtension(const FileName: string): string;
function ShortFilename(const FileName: string): string;

implementation

function TWX_CreateFile(const FileName: string; Access, Share, Creation: DWord): THandle;
begin
  {$IFDEF WINDOWS}
  Result := CreateFile(PChar(FileName), Access, Share, nil, Creation, FILE_ATTRIBUTE_NORMAL, 0);
  {$ELSE}
  // Unix file operations
  if FileExists(FileName) then
    Result := FileOpen(FileName, fmOpenReadWrite)
  else
    Result := FileCreate(FileName);
  {$ENDIF}
end;

function TWX_CloseHandle(Handle: THandle): Boolean;
begin
  {$IFDEF WINDOWS}
  Result := CloseHandle(Handle);
  {$ELSE}
  FileClose(Handle);
  Result := True;
  {$ENDIF}
end;

function TWX_GetCurrentDir: string;
begin
  Result := GetCurrentDir;
end;

function TWX_DirectoryExists(const Dir: string): Boolean;
begin
  Result := DirectoryExists(Dir);
end;

function TWX_CreateDir(const Dir: string): Boolean;
begin
  Result := CreateDir(Dir);
end;

function TWX_FindFirst(const Path: string; Attr: Integer; var F: TSearchRec): Integer;
begin
  Result := FindFirst(Path, Attr, F);
end;

function TWX_FindNext(var F: TSearchRec): Integer;
begin
  Result := FindNext(F);
end;

procedure TWX_FindClose(var F: TSearchRec);
begin
  FindClose(F);
end;

function StrToIntSafe(const S: string): Integer;
begin
  try
    Result := StrToInt(S);
  except
    Result := 0;
  end;
end;

function StripFileExtension(const FileName: string): string;
begin
  Result := ChangeFileExt(FileName, '');
end;

function ShortFilename(const FileName: string): string;
begin
  Result := ExtractFileName(FileName);
end;

end.
```

## Task 1B.2: Convert Core Units

### Database.pas Conversion

**Key Changes Required:**
```pascal
// BEFORE (Delphi)
uses
  Core, Classes, SysUtils;

// AFTER (Lazarus)  
unit Database;
{$mode objfpc}{$H+}

interface
uses
  Core, Classes, SysUtils, TWXCompat;
```

**File Operations Pattern:**
```pascal
// BEFORE (Windows API)
HFileRes := CreateFile(PChar('data\' + S.Name), GENERIC_READ or GENERIC_WRITE, 0, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
if HFileRes <> INVALID_HANDLE_VALUE then
begin
  CloseHandle(HFileRes);
end;

// AFTER (Cross-platform via TWXCompat.pas)
HFileRes := TWX_CreateFile('data' + PathSep + S.Name, GENERIC_READ or GENERIC_WRITE, 0, OPEN_EXISTING);
if HFileRes <> INVALID_HANDLE_VALUE then
begin
  TWX_CloseHandle(HFileRes);
end;

// NOTE: The database engine logic itself (reading/writing binary structures)
// remains completely unchanged - it's just Pascal file I/O operations
```

**Directory Search Pattern:**
```pascal
// BEFORE
if (FindFirst('data\*.xdb', faAnyfile, S) = 0) then
begin
  repeat
    // Process S.Name
  until (FindNext(S) <> 0);
  FindClose(S);
end;

// AFTER  
if (TWX_FindFirst('data' + PathSep + '*.xdb', faAnyfile, S) = 0) then
begin
  repeat
    // Process S.Name
  until (TWX_FindNext(S) <> 0);
  TWX_FindClose(S);
end;
```

### Script.pas Conversion

**Minimal Changes Required:**
```pascal
// BEFORE (Delphi)
uses
  Windows, Messages, Classes, SysUtils;

// AFTER (Lazarus)
unit Script;
{$mode objfpc}{$H+}

interface
uses
  {$IFDEF WINDOWS}
  Windows,
  {$ELSE}
  LCLIntf, LCLType,
  {$ENDIF}
  LMessages, Classes, SysUtils, TWXCompat;
```

**Path Construction Updates:**
```pascal
// BEFORE: ProgramDir + '\scripts\' + ScriptName
// AFTER:  ProgramDir + PathSep + 'scripts' + PathSep + ScriptName

// NOTE: The scripting engine itself (parsing, AST building, execution) 
// is pure Pascal logic and requires NO changes beyond basic unit conversion
// All the complex scripting logic remains identical
```

## Task 1B.3: Convert Form Units

### Form Header Template
```pascal
unit FormName;

{$mode objfpc}{$H+}

interface

uses
  {$IFDEF WINDOWS}
  Windows,
  {$ELSE}
  LCLIntf, LCLType,
  {$ENDIF}
  Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, ComCtrls, Menus,
  LMessages, TWXCompat;

type
  { TfrmName }
  
  TfrmName = class(TForm)
    // Component declarations
  private
    // Private methods
  public  
    // Public methods
  end;

var
  frmName: TfrmName;

implementation

{$R *.lfm}

// Implementation

end.
```

### DFM to LFM Conversion Script

**automated_form_convert.sh:**
```bash
#!/bin/bash

for dfm in backup/original/Form*.dfm; do
    if [ -f "$dfm" ]; then
        base=$(basename "$dfm" .dfm)
        lfm="source/forms/${base}.lfm"
        
        echo "Converting $dfm → $lfm"
        
        sed -e 's/Font\.Charset/Font.CharSet/g' \
            -e 's/= Memo1/= Memo/g' \
            -e 's/= Edit1/= Edit/g' \
            -e 's/Color = clBtnFace/Color = clDefault/g' \
            -e 's/Font\.Color = clWindowText/Font.Color = clDefault/g' \
            -e 's/ParentFont = True/ParentFont = False/g' \
            "$dfm" > "$lfm"
    fi
done
```

### FormSetup.pas Critical Changes

**Database Connection Handling:**
```pascal
// Path separators in database operations
procedure TfrmSetup.LoadDatabases;
var
  SR: TSearchRec;
begin
  lstDatabases.Clear;
  
  if TWX_FindFirst('data' + PathSep + '*.xdb', faAnyFile, SR) = 0 then
  begin
    repeat
      lstDatabases.Items.Add(StripFileExtension(SR.Name));
    until TWX_FindNext(SR) <> 0;
    TWX_FindClose(SR);
  end;
end;
```

## Task 1B.4: Handle Complex Components

### FormHistory.pas - ListView Components

**ListView compatibility:**
```pascal
// Delphi ListView code should work directly
procedure TfrmHistory.PopulateHistory;
var
  Item: TListItem;
begin
  ListView.Clear;
  Item := ListView.Items.Add;
  Item.Caption := 'Entry';
  Item.SubItems.Add('Details');
end;
```

### FormSetup.pas - Registry Access

**Registry operations (Windows-specific):**
```pascal
{$IFDEF WINDOWS}
uses Registry;

procedure TfrmSetup.SaveSettings;
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey('Software\TWXProxy', True) then
    begin
      Reg.WriteString('DatabasePath', edtDatabasePath.Text);
      Reg.CloseKey;
    end;
  finally
    Reg.Free;
  end;
end;
{$ENDIF}
```

## Task 1B.5: Create Build Integration

### Update Main Projects

**TWXP.lpr modifications:**
```pascal
program TWXP;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, 
  Forms,
  TWXCompat,    // Add compatibility layer
  FormMain, FormSetup, FormHistory, FormAbout,
  Database, Script, Menu, Utility, Global,
  // ... other units
  ;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Title := 'TWX Proxy';
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.CreateForm(TfrmSetup, frmSetup);
  Application.Run;
end.
```

### TWXP.lpi Search Paths

**Add to search paths:**
```
../source/core
../source/forms
../source/scripts  
../source/utils
../source/compat
../backup/original
```

## Task 1B.6: Compilation Testing

### Build All Projects Script

**build_all_1b.sh:**
```bash
#!/bin/bash
set -e

echo "=== Phase 1B Compilation Test ==="

PROJECTS=("CapEdit" "TWXP")  # TWXProxy requires networking (Phase 1C)

for project in "${PROJECTS[@]}"; do
    echo ""
    echo "Building $project..."
    
    if [ -f "projects/$project/$project.lpi" ]; then
        lazbuild --build-mode=Debug "projects/$project/$project.lpi" || {
            echo "❌ $project build failed"
            exit 1
        }
        echo "✅ $project compiled successfully"
    else
        echo "⚠️ $project project file not found"
    fi
done

echo ""
echo "=== All Phase 1B projects compiled successfully ==="
```

### Unit Testing Framework

**Create tests/TestCoreUnits.pas:**
```pascal
unit TestCoreUnits;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  Database, Script, Utility, TWXCompat;

type
  TTestCoreUnits = class(TTestCase)
  published
    procedure TestDatabaseCreation;
    procedure TestUtilityFunctions;
    procedure TestCompatFunctions;
    procedure TestScriptEngine;
  end;

implementation

procedure TTestCoreUnits.TestDatabaseCreation;
var
  DB: TModDatabase;
begin
  DB := TModDatabase.Create(nil, nil);
  try
    AssertNotNull('Database should be created', DB);
  finally
    DB.Free;
  end;
end;

procedure TTestCoreUnits.TestUtilityFunctions;
begin
  AssertEquals('StripFileExtension test', 'test', StripFileExtension('test.txt'));
  AssertEquals('ShortFilename test', 'file.txt', ShortFilename('/path/to/file.txt'));
end;

procedure TTestCoreUnits.TestCompatFunctions;
begin
  AssertTrue('Current dir should exist', TWX_DirectoryExists(TWX_GetCurrentDir));
  AssertEquals('StrToIntSafe test', 123, StrToIntSafe('123'));
  AssertEquals('StrToIntSafe invalid', 0, StrToIntSafe('invalid'));
end;

procedure TTestCoreUnits.TestScriptEngine;
var
  Script: TScript;
begin
  Script := TScript.Create;
  try
    AssertNotNull('Script should be created', Script);
  finally
    Script.Free;
  end;
end;

initialization
  RegisterTest(TTestCoreUnits);
end.
```

## Task 1B.7: Validation Checklist

### Compilation Success Criteria
- [ ] All core units (Database, Script, Utility, etc.) compile without errors
- [ ] All form units compile with converted .lfm files
- [ ] TWXCompat.pas provides all needed Windows API replacements
- [ ] TWXP.exe compiles and links successfully (minus networking)
- [ ] CapEdit.exe remains functional with enhanced core units
- [ ] Zero compiler warnings in Release mode
- [ ] All file path operations use PathSep constants
- [ ] Cross-platform compatibility validated

### Functional Testing
- [ ] TWXP application launches (will fail on TCP connect - expected)
- [ ] Setup form displays with database list populated  
- [ ] About/License/History dialogs display correctly
- [ ] File operations work across platforms
- [ ] No memory leaks detected in core units
- [ ] Script engine initializes without errors

## Deliverables

1. **Complete source/core/ directory** - All core units converted
2. **Complete source/forms/ directory** - All form units with .lfm files
3. **TWXCompat.pas** - Comprehensive Windows API compatibility layer
4. **Updated TWXP.lpi** - Project configuration with all units
5. **Test suite** - Unit tests for core functionality
6. **Build scripts** - Automated compilation for all non-networking projects

**Phase 1C Handoff**: Core application framework ready for networking layer integration.

---
*Duration*: 4-6 days  
*Risk*: LOW-MEDIUM (forms complexity)  
*Dependencies*: Phase 1A complete  
*Output*: Core application minus networking