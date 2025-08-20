# Phase 2: Platform-Specific Refactoring

Complete Windows API abstraction and implement cross-platform optimizations. Focus on configuration systems, file operations, and platform-specific features.

## Objectives

- [ ] Complete Windows API abstraction layer
- [ ] Replace Windows Registry with cross-platform configuration
- [ ] Implement platform-specific file operations
- [ ] Add Linux/macOS deployment configurations
- [ ] Validate cross-platform functionality

**Duration**: 4-6 days

## Task 2.1: Enhanced Windows API Compatibility

**Extend TWXCompat.pas with configuration system:**
```pascal
// Configuration abstraction (replaces Windows Registry)
{$IFDEF WINDOWS}
uses Registry;
{$ENDIF}

type
  TTWXConfig = class
  private
    {$IFDEF WINDOWS}
    FRegistry: TRegistry;
    FUseRegistry: Boolean;
    {$ENDIF}
    FConfigFile: TIniFile;
    function GetConfigDir: string;
  public
    constructor Create;
    destructor Destroy; override;
    
    function ReadString(const Section, Key, Default: string): string;
    function WriteString(const Section, Key, Data: string): Boolean;
    function ReadInteger(const Section, Key: string; Default: Integer): Integer;
    function WriteInteger(const Section, Key: string; Data: Integer): Boolean;
  end;

// NOTE: This abstracts Windows registry vs Linux/macOS config files
// The application logic using configuration remains unchanged

implementation

constructor TTWXRegistry.Create;
begin
  {$IFDEF WINDOWS}
  FUseRegistry := True;
  FRegistry := TRegistry.Create;
  FRegistry.RootKey := HKEY_CURRENT_USER;
  {$ELSE}
  FUseRegistry := False;
  FConfigFile := TIniFile.Create(GetUserDir + '.config/twxproxy/config.ini');
  {$ENDIF}
end;

function TTWXRegistry.ReadString(const Key, Value, Default: string): string;
begin
  {$IFDEF WINDOWS}
  if FUseRegistry then
  begin
    if FRegistry.OpenKeyReadOnly(Key) then
    begin
      Result := FRegistry.ReadString(Value);
      if Result = '' then Result := Default;
      FRegistry.CloseKey;
    end
    else
      Result := Default;
  end
  else
  {$ENDIF}
  begin
    Result := FConfigFile.ReadString('Settings', Key + '_' + Value, Default);
  end;
end;
```

**Process and system information:**
```pascal
// Cross-platform process management
function TWX_GetCurrentProcessId: Cardinal;
begin
  {$IFDEF WINDOWS}
  Result := GetCurrentProcessId;
  {$ELSE}
  Result := FpGetpid;
  {$ENDIF}
end;

function TWX_GetSystemInfo: string;
begin
  {$IFDEF WINDOWS}
  Result := 'Windows ' + GetWindowsVersionString;
  {$ELIF LINUX}
  Result := 'Linux ' + GetKernelVersion;
  {$ELIF DARWIN}
  Result := 'macOS ' + GetMacOSVersion;
  {$ELSE}
  Result := 'Unknown OS';
  {$ENDIF}
end;

// File attributes cross-platform
function TWX_SetFileReadOnly(const FileName: string; ReadOnly: Boolean): Boolean;
var
  Attrs: Cardinal;
begin
  {$IFDEF WINDOWS}
  Attrs := GetFileAttributes(PChar(FileName));
  if ReadOnly then
    Attrs := Attrs or FILE_ATTRIBUTE_READONLY
  else
    Attrs := Attrs and not FILE_ATTRIBUTE_READONLY;
  Result := SetFileAttributes(PChar(FileName), Attrs);
  {$ELSE}
  if ReadOnly then
    Result := FpChmod(FileName, S_IRUSR or S_IRGRP or S_IROTH) = 0
  else
    Result := FpChmod(FileName, S_IRUSR or S_IWUSR or S_IRGRP or S_IROTH) = 0;
  {$ENDIF}
end;
```

## Task 2.2: Configuration System Refactoring

**Replace hardcoded paths and registry usage in FormSetup.pas:**
```pascal
// BEFORE (Windows Registry)
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
      Reg.WriteInteger('ListenPort', StrToInt(edtPort.Text));
    end;
  finally
    Reg.Free;
  end;
end;

// AFTER (Cross-platform)
procedure TfrmSetup.SaveSettings;
var
  Config: TTWXRegistry;
begin
  Config := TTWXRegistry.Create;
  try
    Config.WriteString('Software\TWXProxy', 'DatabasePath', edtDatabasePath.Text);
    Config.WriteInteger('Software\TWXProxy', 'ListenPort', StrToInt(edtPort.Text));
  finally
    Config.Free;
  end;
end;
```

**Update TWXP.dpr initialization for cross-platform paths:**
```pascal
// BEFORE (Windows paths)
if not (DirectoryExists(ProgramDir + '\data')) then
  CreateDir(ProgramDir + '\data');
if not (DirectoryExists(ProgramDir + '\scripts')) then
  CreateDir(ProgramDir + '\scripts');
if not (DirectoryExists(ProgramDir + '\logs')) then
  CreateDir(ProgramDir + '\logs');

// AFTER (Cross-platform)
function GetDataDir: string;
begin
  {$IFDEF WINDOWS}
  Result := ProgramDir + PathSep + 'data';
  {$ELSE}
  Result := GetUserDir + '.local/share/twxproxy/data';
  {$ENDIF}
end;

function GetScriptsDir: string;
begin
  {$IFDEF WINDOWS}
  Result := ProgramDir + PathSep + 'scripts';
  {$ELSE}
  Result := GetUserDir + '.local/share/twxproxy/scripts';
  {$ENDIF}
end;

// Create directories
if not TWX_DirectoryExists(GetDataDir) then
  TWX_CreateDir(GetDataDir);
if not TWX_DirectoryExists(GetScriptsDir) then
  TWX_CreateDir(GetScriptsDir);
```

## Task 2.3: Platform-Specific Build Configurations

**Add platform-specific build modes to all .lpi files:**
```xml
<BuildModes Count="6">
  <Item1 Name="Debug-Win32" Default="True">
    <CompilerOptions>
      <Target>
        <Filename Value="../build/debug-win32/$(TargetFile)"/>
      </Target>
      <CodeGeneration>
        <TargetOS Value="win32"/>
        <TargetCPU Value="i386"/>
      </CodeGeneration>
      <Linking>
        <Options>
          <Win32>
            <GraphicApplication Value="True"/>
          </Win32>
        </Options>
      </Linking>
    </CompilerOptions>
  </Item1>
  
  <Item2 Name="Release-Win64">
    <CompilerOptions>
      <Target>
        <Filename Value="../build/release-win64/$(TargetFile)"/>
      </Target>
      <CodeGeneration>
        <TargetOS Value="win64"/>
        <TargetCPU Value="x86_64"/>
        <Optimizations>
          <OptimizationLevel Value="3"/>
        </Optimizations>
      </CodeGeneration>
    </CompilerOptions>
  </Item2>
  
  <Item3 Name="Debug-Linux64">
    <CompilerOptions>
      <Target>
        <Filename Value="../build/debug-linux64/$(TargetFile)"/>
      </Target>
      <CodeGeneration>
        <TargetOS Value="linux"/>
        <TargetCPU Value="x86_64"/>
      </CodeGeneration>
    </CompilerOptions>
  </Item3>
  
  <Item4 Name="Release-Linux64">
    <CompilerOptions>
      <Target>
        <Filename Value="../build/release-linux64/$(TargetFile)"/>
      </Target>
      <CodeGeneration>
        <TargetOS Value="linux"/>
        <TargetCPU Value="x86_64"/>
        <Optimizations>
          <OptimizationLevel Value="3"/>
        </Optimizations>
      </CodeGeneration>
    </CompilerOptions>
  </Item4>
  
  <Item5 Name="Debug-macOS64">
    <CompilerOptions>
      <Target>
        <Filename Value="../build/debug-macos64/$(TargetFile)"/>
      </Target>
      <CodeGeneration>
        <TargetOS Value="darwin"/>
        <TargetCPU Value="x86_64"/>
      </CodeGeneration>
    </CompilerOptions>
  </Item5>
  
  <Item6 Name="Release-macOS-arm64">
    <CompilerOptions>
      <Target>
        <Filename Value="../build/release-macos-arm64/$(TargetFile)"/>
      </Target>
      <CodeGeneration>
        <TargetOS Value="darwin"/>
        <TargetCPU Value="aarch64"/>
        <Optimizations>
          <OptimizationLevel Value="3"/>
        </Optimizations>
      </CodeGeneration>
    </CompilerOptions>
  </Item6>
</BuildModes>
```

## Task 2.4: Cross-Platform Service/Daemon Support

**Create service wrapper for TWXProxy:**
```pascal
// source/utils/TWXService.pas
unit TWXService;

{$mode objfpc}{$H+}

interface

{$IFDEF WINDOWS}
uses Windows, SysUtils, Classes;
{$ENDIF}

{$IFDEF LINUX}
uses BaseUnix, Unix, SysUtils, Classes;
{$ENDIF}

type
  TTWXService = class
  private
    FServiceName: string;
    FDisplayName: string;
    FRunning: Boolean;
  public
    constructor Create(const AServiceName, ADisplayName: string);
    
    function Install: Boolean;
    function Uninstall: Boolean;
    function Start: Boolean;
    function Stop: Boolean;
    function IsRunning: Boolean;
    
    property ServiceName: string read FServiceName;
    property Running: Boolean read FRunning;
  end;

implementation

{$IFDEF WINDOWS}
function TTWXService.Install: Boolean;
var
  SCManager, Service: SC_HANDLE;
  ServicePath: string;
begin
  Result := False;
  ServicePath := ParamStr(0);
  
  SCManager := OpenSCManager(nil, nil, SC_MANAGER_CREATE_SERVICE);
  if SCManager <> 0 then
  begin
    Service := CreateService(SCManager, PChar(FServiceName), PChar(FDisplayName),
      SERVICE_ALL_ACCESS, SERVICE_WIN32_OWN_PROCESS, SERVICE_AUTO_START,
      SERVICE_ERROR_NORMAL, PChar(ServicePath), nil, nil, nil, nil, nil);
    Result := Service <> 0;
    if Service <> 0 then CloseServiceHandle(Service);
    CloseServiceHandle(SCManager);
  end;
end;
{$ENDIF}

{$IFDEF LINUX}
function TTWXService.Install: Boolean;
var
  ServiceFile: TextFile;
  ServiceContent: string;
begin
  ServiceContent := 
    '[Unit]' + LineEnding +
    'Description=TWX Proxy Server' + LineEnding +
    'After=network.target' + LineEnding +
    LineEnding +
    '[Service]' + LineEnding +
    'Type=forking' + LineEnding +
    'ExecStart=' + ParamStr(0) + ' --daemon' + LineEnding +
    'Restart=always' + LineEnding +
    'User=twxproxy' + LineEnding +
    LineEnding +
    '[Install]' + LineEnding +
    'WantedBy=multi-user.target' + LineEnding;
    
  try
    AssignFile(ServiceFile, '/etc/systemd/system/' + FServiceName + '.service');
    Rewrite(ServiceFile);
    Write(ServiceFile, ServiceContent);
    CloseFile(ServiceFile);
    
    // Enable service
    fpSystem('systemctl enable ' + FServiceName + '.service');
    Result := True;
  except
    Result := False;
  end;
end;
{$ENDIF}
```

## Task 2.5: Font and UI Scaling

**Handle cross-platform UI differences:**
```pascal
// FormMain.pas OnCreate
procedure TfrmMain.FormCreate(Sender: TObject);
begin
  // Platform-specific UI adjustments
  {$IFDEF WINDOWS}
  // Windows: Use system font
  Font.Name := 'Segoe UI';
  Font.Size := 9;
  {$ENDIF}
  
  {$IFDEF LINUX}
  // Linux: Use system font with GTK scaling
  Font.Name := 'Liberation Sans';  
  Font.Size := 10;
  {$ENDIF}
  
  {$IFDEF DARWIN}
  // macOS: Use SF Pro or system font
  Font.Name := 'SF Pro Text';
  Font.Size := 13;
  {$ENDIF}
  
  // High DPI support
  if Screen.PixelsPerInch > 120 then
  begin
    ScaleBy(Screen.PixelsPerInch, 96);
  end;
end;
```

**Update forms for consistent appearance:**
```pascal
// Add to each form's OnCreate
procedure AdjustForPlatform;
begin
  {$IFDEF LINUX}
  // Linux forms often need slightly larger margins
  BorderSpacing.Around := 8;
  {$ENDIF}
  
  {$IFDEF DARWIN}  
  // macOS has different button spacing conventions
  if Assigned(btnOK) then btnOK.Height := 24;
  if Assigned(btnCancel) then btnCancel.Height := 24;
  {$ENDIF}
end;
```

## Task 2.6: File Association and MIME Types

**Windows file associations (.reg file):**
```ini
; twxproxy-associations.reg
Windows Registry Editor Version 5.00

[HKEY_CLASSES_ROOT\.xdb]
@="TWXProxyDatabase"

[HKEY_CLASSES_ROOT\TWXProxyDatabase]
@="TWX Proxy Database"

[HKEY_CLASSES_ROOT\TWXProxyDatabase\shell\open\command]
@="\"C:\\Program Files\\TWXProxy\\TWXP.exe\" \"%1\""

[HKEY_CLASSES_ROOT\.cts]
@="TWXProxyScript"

[HKEY_CLASSES_ROOT\TWXProxyScript\shell\open\command]
@="\"C:\\Program Files\\TWXProxy\\TWXP.exe\" \"%1\""
```

**Linux MIME types:**
```xml
<!-- twxproxy.xml for /usr/share/mime/packages/ -->
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
    <mime-type type="application/x-twx-database">
        <comment>TWX Proxy Database</comment>
        <glob pattern="*.xdb"/>
        <icon name="twxproxy-database"/>
    </mime-type>
    
    <mime-type type="application/x-twx-script">
        <comment>TWX Proxy Script</comment>
        <glob pattern="*.cts"/>
        <icon name="twxproxy-script"/>
    </mime-type>
</mime-info>
```

**Desktop entry file:**
```ini
# twxproxy.desktop
[Desktop Entry]
Name=TWX Proxy
Comment=Trade Wars X Proxy Server
Exec=twxproxy %F
Icon=twxproxy
Terminal=false
Type=Application
Categories=Network;Game;
MimeType=application/x-twx-database;application/x-twx-script;
StartupNotify=true
```

## Task 2.7: Cross-Platform Testing Script

**Create comprehensive platform test:**
```bash
#!/bin/bash
# test_cross_platform.sh

echo "=== Cross-Platform Compatibility Test ==="

# Test 1: File operations
echo "Testing file operations..."
mkdir -p test_temp
echo "Test data" > test_temp/test.txt

if [ -f test_temp/test.txt ]; then
    echo "✅ File creation successful"
else
    echo "❌ File creation failed"
fi

# Test 2: Directory operations  
./TWXProxy --test-dirs
if [ $? -eq 0 ]; then
    echo "✅ Directory operations successful"
else
    echo "❌ Directory operations failed"
fi

# Test 3: Configuration system
./TWXProxy --test-config
if [ $? -eq 0 ]; then
    echo "✅ Configuration system working"
else
    echo "❌ Configuration system failed"
fi

# Test 4: Network binding
./TWXProxy --test-bind --port=2023
if [ $? -eq 0 ]; then
    echo "✅ Network binding successful"
else
    echo "❌ Network binding failed"
fi

# Test 5: Database operations
./TWXP --test-database
if [ $? -eq 0 ]; then
    echo "✅ Database operations successful"
else  
    echo "❌ Database operations failed"
fi

# Cleanup
rm -rf test_temp

echo "=== Cross-platform testing complete ==="
```

## Task 2.8: Performance Optimization

**Platform-specific optimizations:**
```pascal
// TWXCompat.pas additions
{$IFDEF WINDOWS}
// Windows: Use memory-mapped files for large databases
function TWX_CreateFileMapping(const FileName: string): THandle;
begin
  Result := CreateFileMapping(INVALID_HANDLE_VALUE, nil, PAGE_READWRITE, 0, 1024*1024, nil);
end;
{$ENDIF}

{$IFDEF LINUX}
// Linux: Use sendfile() for efficient file transfers
function TWX_SendFile(OutFD, InFD: Integer; Offset: PtrInt; Count: Size_T): SSizeInt;
begin
  Result := FpSendFile(OutFD, InFD, @Offset, Count);
end;
{$ENDIF}

// Memory management optimization
procedure TWX_OptimizeMemory;
begin
  {$IFDEF WINDOWS}
  SetProcessWorkingSetSize(GetCurrentProcess, $FFFFFFFF, $FFFFFFFF);
  {$ENDIF}
  
  {$IFDEF LINUX}
  // Linux memory advice
  {$ENDIF}
end;
```

## Success Criteria

### Compilation Success
- [ ] All projects compile on Windows, Linux, macOS
- [ ] Platform-specific build modes configured
- [ ] No conditional compilation warnings
- [ ] Cross-platform compatibility unit complete
- [ ] Service/daemon support implemented

### Functional Validation  
- [ ] Configuration system works on all platforms
- [ ] File operations handle platform-specific paths
- [ ] UI scaling appropriate for each platform
- [ ] File associations registered correctly
- [ ] Service installation/removal working

### Quality Metrics
- [ ] Memory usage consistent across platforms
- [ ] Performance within 5% of Windows version
- [ ] No platform-specific crashes
- [ ] UI appearance consistent and native-looking
- [ ] All file paths use correct separators

## Deliverables

1. **Enhanced TWXCompat.pas** - Complete cross-platform abstraction
2. **TTWXRegistry class** - Cross-platform configuration system
3. **Platform build configurations** - All .lpi files updated
4. **Service/daemon support** - Installation and management
5. **Cross-platform test suite** - Automated platform validation
6. **File associations** - MIME types and registry entries

---
*Duration*: 4-6 days  
*Dependencies*: Phase 1C complete  
*Output*: Full cross-platform compatibility