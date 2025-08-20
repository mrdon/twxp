# Phase 4: Deployment & Polish

Create basic deployment packages and finalize the conversion. Focus on creating installable packages and basic documentation.

## Objectives

- [ ] Create installation packages for Windows/Linux
- [ ] Package all required files and dependencies
- [ ] Create basic user documentation
- [ ] Version the release and tag in source control
- [ ] Create simple migration guide for users

**Duration**: 1-2 days

## Task 4.1: Windows Installation Package

**Create basic Windows installer (NSIS):**
```nsis
; TWXProxy-Installer.nsi
!define PRODUCT_NAME "TWX Proxy"
!define PRODUCT_VERSION "2.7.0"
!define PRODUCT_PUBLISHER "TWX Development Team"
!define PRODUCT_DIR_REGKEY "Software\Microsoft\Windows\CurrentVersion\App Paths\TWXProxy.exe"
!define PRODUCT_UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"

Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
OutFile "TWXProxy-${PRODUCT_VERSION}-Setup.exe"
InstallDir "$PROGRAMFILES\TWXProxy"
ShowInstDetails show
ShowUnInstDetails show

Section "MainSection" SEC01
  SetOutPath "$INSTDIR"
  File "build\release\TWXProxy.exe"
  File "build\release\TWXP.exe"
  File "build\release\CapEdit.exe"
  
  ; Copy data directory
  SetOutPath "$INSTDIR\data"
  File /r "data\*"
  
  ; Copy scripts directory  
  SetOutPath "$INSTDIR\scripts"
  File /r "scripts\*"
  
  ; Create shortcuts
  CreateDirectory "$SMPROGRAMS\TWX Proxy"
  CreateShortCut "$SMPROGRAMS\TWX Proxy\TWX Proxy.lnk" "$INSTDIR\TWXProxy.exe"
  CreateShortCut "$SMPROGRAMS\TWX Proxy\TWX Player.lnk" "$INSTDIR\TWXP.exe"
  CreateShortCut "$SMPROGRAMS\TWX Proxy\Capture Editor.lnk" "$INSTDIR\CapEdit.exe"
  CreateShortCut "$DESKTOP\TWX Proxy.lnk" "$INSTDIR\TWXProxy.exe"
  
  ; File associations
  WriteRegStr HKCR ".xdb" "" "TWXProxyDatabase"
  WriteRegStr HKCR "TWXProxyDatabase" "" "TWX Proxy Database"
  WriteRegStr HKCR "TWXProxyDatabase\shell\open\command" "" '"$INSTDIR\TWXP.exe" "%1"'
SectionEnd

Section -Post
  WriteUninstaller "$INSTDIR\uninst.exe"
  WriteRegStr ${PRODUCT_DIR_REGKEY} "" "$INSTDIR\TWXProxy.exe"
  WriteRegStr ${PRODUCT_UNINST_KEY} "DisplayName" "$(^Name)"
  WriteRegStr ${PRODUCT_UNINST_KEY} "UninstallString" "$INSTDIR\uninst.exe"
  WriteRegStr ${PRODUCT_UNINST_KEY} "DisplayVersion" "${PRODUCT_VERSION}"
  WriteRegStr ${PRODUCT_UNINST_KEY} "Publisher" "${PRODUCT_PUBLISHER}"
SectionEnd

Section Uninstall
  Delete "$INSTDIR\uninst.exe"
  Delete "$INSTDIR\TWXProxy.exe"
  Delete "$INSTDIR\TWXP.exe"
  Delete "$INSTDIR\CapEdit.exe"
  
  RMDir /r "$INSTDIR\data"
  RMDir /r "$INSTDIR\scripts"
  RMDir "$INSTDIR"
  
  Delete "$SMPROGRAMS\TWX Proxy\*"
  RMDir "$SMPROGRAMS\TWX Proxy"
  Delete "$DESKTOP\TWX Proxy.lnk"
  
  DeleteRegKey ${PRODUCT_UNINST_KEY}
  DeleteRegKey ${PRODUCT_DIR_REGKEY}
  DeleteRegKey HKCR "TWXProxyDatabase"
  DeleteRegKey HKCR ".xdb"
SectionEnd
```

**Build installer script:**
```batch
@echo off
REM build_installer.bat

echo Building Windows installer...

REM Build release version
lazbuild --build-mode=Release projects\TWXProxy\TWXProxy.lpi
lazbuild --build-mode=Release projects\TWXP\TWXP.lpi
lazbuild --build-mode=Release projects\CapEdit\CapEdit.lpi

REM Create installer with NSIS
"C:\Program Files (x86)\NSIS\makensis.exe" TWXProxy-Installer.nsi

if exist "TWXProxy-*-Setup.exe" (
    echo ✅ Installer created successfully
) else (
    echo ❌ Installer creation failed
    exit /b 1
)
```

## Task 4.2: Linux Package

**Create Debian package:**
```bash
#!/bin/bash
# create_deb_package.sh

PACKAGE_NAME="twxproxy"
VERSION="2.7.0"
ARCH="amd64"
BUILD_DIR="debian_package"

echo "Creating Debian package for TWX Proxy..."

# Clean and create package structure
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/$PACKAGE_NAME/usr/bin"
mkdir -p "$BUILD_DIR/$PACKAGE_NAME/usr/share/applications"
mkdir -p "$BUILD_DIR/$PACKAGE_NAME/usr/share/doc/$PACKAGE_NAME"
mkdir -p "$BUILD_DIR/$PACKAGE_NAME/usr/share/$PACKAGE_NAME/data"
mkdir -p "$BUILD_DIR/$PACKAGE_NAME/usr/share/$PACKAGE_NAME/scripts"
mkdir -p "$BUILD_DIR/$PACKAGE_NAME/DEBIAN"

# Copy binaries
cp build/release/TWXProxy "$BUILD_DIR/$PACKAGE_NAME/usr/bin/"
cp build/release/TWXP "$BUILD_DIR/$PACKAGE_NAME/usr/bin/"
cp build/release/CapEdit "$BUILD_DIR/$PACKAGE_NAME/usr/bin/"

# Copy data and scripts
cp -r data/* "$BUILD_DIR/$PACKAGE_NAME/usr/share/$PACKAGE_NAME/data/" 2>/dev/null || true
cp -r scripts/* "$BUILD_DIR/$PACKAGE_NAME/usr/share/$PACKAGE_NAME/scripts/" 2>/dev/null || true

# Create desktop entry
cat > "$BUILD_DIR/$PACKAGE_NAME/usr/share/applications/twxproxy.desktop" << EOF
[Desktop Entry]
Name=TWX Proxy
Comment=Trade Wars X Proxy Server
Exec=TWXProxy
Icon=twxproxy
Terminal=false
Type=Application
Categories=Network;Game;
EOF

# Create copyright file
cat > "$BUILD_DIR/$PACKAGE_NAME/usr/share/doc/$PACKAGE_NAME/copyright" << EOF
This package was created from TWX Proxy source code.
License: GPL-2+
EOF

# Create control file
cat > "$BUILD_DIR/$PACKAGE_NAME/DEBIAN/control" << EOF
Package: $PACKAGE_NAME
Version: $VERSION
Section: games
Priority: optional
Architecture: $ARCH
Maintainer: TWX Development Team <twx@example.com>
Description: Trade Wars X Proxy
 Cross-platform Trade Wars proxy server with scripting support.
 Converted from Delphi to FreePascal/Lazarus for better portability.
EOF

# Set permissions
chmod 755 "$BUILD_DIR/$PACKAGE_NAME/usr/bin/"*
chmod -R 755 "$BUILD_DIR/$PACKAGE_NAME/DEBIAN"

# Build package
dpkg-deb --build "$BUILD_DIR/$PACKAGE_NAME" "${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"

if [ -f "${PACKAGE_NAME}_${VERSION}_${ARCH}.deb" ]; then
    echo "✅ Debian package created: ${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
    echo "Install with: sudo dpkg -i ${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
else
    echo "❌ Package creation failed"
    exit 1
fi

# Cleanup
rm -rf "$BUILD_DIR"
```

## Task 4.3: Basic Documentation

**Create README for distribution:**
```markdown
# TWX Proxy 2.7.0 - Lazarus Edition

TWX Proxy is a Trade Wars X proxy server with scripting support, now converted from Delphi to FreePascal/Lazarus for cross-platform compatibility.

## What's New in Lazarus Edition

- **Cross-platform support**: Runs on Windows, Linux, and macOS
- **Open source toolchain**: Built with FreePascal/Lazarus
- **Improved compatibility**: Better Unicode and modern OS support
- **Same functionality**: All original features preserved

## System Requirements

### Windows
- Windows 7 or later
- 50MB free disk space
- Network access for proxy functionality

### Linux
- Any modern Linux distribution
- 50MB free disk space  
- Network access for proxy functionality

## Quick Start

### Windows
1. Run the installer: `TWXProxy-2.7.0-Setup.exe`
2. Launch TWX Proxy from Start Menu
3. Configure your game connection in Setup

### Linux
1. Install the package: `sudo dpkg -i twxproxy_2.7.0_amd64.deb`
2. Run from command line: `TWXProxy`
3. Configure your game connection in Setup

## Applications Included

- **TWXProxy** - Main proxy server
- **TWXP** - TWX Player (database browser)  
- **CapEdit** - Capture file editor

## Configuration

Configuration files are stored in:
- **Windows**: Program installation directory
- **Linux**: `~/.config/twxproxy/`

## Migration from Original Delphi Version

Your existing databases and scripts should work without modification. The file formats are unchanged.

1. Copy your `.xdb` database files to the new data directory
2. Copy your script files to the new scripts directory  
3. Your settings will be migrated automatically on first run

## Support

This is a community conversion project. For issues specific to the Lazarus version:
- Check the GitHub repository for known issues
- Report bugs through the issue tracker

For general TWX Proxy usage questions, consult existing TWX documentation and forums.

## License

GPL v2+ - Same as original TWX Proxy
```

**Create CHANGELOG:**
```markdown
# TWX Proxy Changelog

## Version 2.7.0 - Lazarus Edition (2024-XX-XX)

### Major Changes
- Complete conversion from Delphi to FreePascal/Lazarus
- Cross-platform support (Windows, Linux, macOS)
- Replaced proprietary socket components with Synapse

### Technical Improvements
- Modern Unicode string handling
- Better memory management
- Improved error handling
- Cross-platform file operations

### Compatibility
- All existing databases (.xdb files) remain compatible
- All existing scripts continue to work
- Configuration format unchanged

### Known Issues
- First run may be slightly slower while settings migrate
- Some Windows-specific registry settings moved to config files on Linux/macOS

### Migration Notes
- Automatic migration of settings on first startup
- Database files work without conversion
- Script files work without modification

---

## Previous Versions

See original TWX Proxy documentation for version history prior to Lazarus conversion.
```

## Task 4.4: Version Management

**Create version information:**
```pascal
// source/compat/TWXVersion.pas
unit TWXVersion;

{$mode objfpc}{$H+}

interface

const
  TWX_VERSION_MAJOR = 2;
  TWX_VERSION_MINOR = 7;
  TWX_VERSION_PATCH = 0;
  TWX_VERSION_BUILD = 1;
  
  TWX_VERSION_STRING = '2.7.0';
  TWX_VERSION_FULL = '2.7.0.1';
  TWX_EDITION = 'Lazarus Edition';
  
  TWX_BUILD_DATE = {$I %DATE%};
  TWX_BUILD_TIME = {$I %TIME%};

function GetTWXVersionString: string;
function GetTWXFullVersionString: string;

implementation

function GetTWXVersionString: string;
begin
  Result := TWX_VERSION_STRING;
end;

function GetTWXFullVersionString: string;
begin
  Result := TWX_VERSION_FULL + ' ' + TWX_EDITION + ' (Built: ' + TWX_BUILD_DATE + ')';
end;

end.
```

**Update all project version resources:**
```pascal
// Add to each .lpr file
uses TWXVersion;

// In initialization or main program
procedure ShowVersion;
begin
  WriteLn('TWX Proxy ' + GetTWXFullVersionString);
end;
```

## Task 4.5: Release Preparation

**Create release build script:**
```bash
#!/bin/bash
# build_release.sh

VERSION="2.7.0"
BUILD_DATE=$(date +"%Y-%m-%d")

echo "Building TWX Proxy $VERSION release..."

# Clean previous builds
rm -rf build/release
mkdir -p build/release

# Build all projects in release mode
echo "Building TWXProxy..."
lazbuild --build-mode=Release projects/TWXProxy/TWXProxy.lpi

echo "Building TWXP..."
lazbuild --build-mode=Release projects/TWXP/TWXP.lpi

echo "Building CapEdit..."  
lazbuild --build-mode=Release projects/CapEdit/CapEdit.lpi

# Verify all executables exist
EXECUTABLES=("TWXProxy" "TWXP" "CapEdit")
for exe in "${EXECUTABLES[@]}"; do
    if [ -f "build/release/$exe" ] || [ -f "build/release/$exe.exe" ]; then
        echo "✅ $exe built successfully"
    else
        echo "❌ $exe build failed"
        exit 1
    fi
done

# Create release directory structure
mkdir -p "release/TWXProxy-$VERSION"
cp build/release/* "release/TWXProxy-$VERSION/"

# Copy documentation
cp README.md "release/TWXProxy-$VERSION/"
cp CHANGELOG.md "release/TWXProxy-$VERSION/"

# Copy data and scripts if they exist
[ -d "data" ] && cp -r data "release/TWXProxy-$VERSION/" || true
[ -d "scripts" ] && cp -r scripts "release/TWXProxy-$VERSION/" || true

echo "✅ Release build complete: release/TWXProxy-$VERSION/"
echo "Version: $VERSION"
echo "Build date: $BUILD_DATE"
```

**Create archive packages:**
```bash
#!/bin/bash
# package_release.sh

VERSION="2.7.0"
RELEASE_DIR="release/TWXProxy-$VERSION"

if [ ! -d "$RELEASE_DIR" ]; then
    echo "❌ Release directory not found. Run build_release.sh first."
    exit 1
fi

echo "Creating release packages..."

# Create ZIP archive (cross-platform)
cd release
zip -r "TWXProxy-${VERSION}.zip" "TWXProxy-$VERSION/"
echo "✅ Created TWXProxy-${VERSION}.zip"

# Create tar.gz archive (Linux/Unix)
tar -czf "TWXProxy-${VERSION}.tar.gz" "TWXProxy-$VERSION/"
echo "✅ Created TWXProxy-${VERSION}.tar.gz"

cd ..

# File sizes
echo ""
echo "Package sizes:"
ls -lh release/*.zip release/*.tar.gz 2>/dev/null || true

echo ""
echo "Release packages ready in release/ directory"
```

## Task 4.6: Simple Migration Tool

**Basic database migration checker:**
```pascal
// tools/TWXMigrate.pas
program TWXMigrate;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes;

procedure CheckDatabase(const FileName: string);
var
  FileStream: TFileStream;
  Header: array[0..11] of Char;
begin
  if not FileExists(FileName) then
  begin
    WriteLn('❌ Database file not found: ', FileName);
    Exit;
  end;
  
  try
    FileStream := TFileStream.Create(FileName, fmOpenRead);
    try
      if FileStream.Size < 12 then
      begin
        WriteLn('❌ Database file too small: ', FileName);
        Exit;
      end;
      
      FileStream.ReadBuffer(Header, 12);
      
      if Copy(Header, 1, 12) = 'TWX Trade Wa' then
        WriteLn('✅ Valid TWX database: ', FileName)
      else
        WriteLn('⚠️ Unknown database format: ', FileName);
        
    finally
      FileStream.Free;
    end;
  except
    on E: Exception do
      WriteLn('❌ Error reading database: ', E.Message);
  end;
end;

procedure ShowUsage;
begin
  WriteLn('TWX Database Migration Checker');
  WriteLn('Usage: TWXMigrate <database.xdb>');
  WriteLn('       TWXMigrate --scan-directory <path>');
end;

var
  I: Integer;
  SearchRec: TSearchRec;
  ScanDir: string;
begin
  if ParamCount = 0 then
  begin
    ShowUsage;
    Exit;
  end;
  
  if (ParamCount = 2) and (ParamStr(1) = '--scan-directory') then
  begin
    ScanDir := ParamStr(2);
    WriteLn('Scanning directory: ', ScanDir);
    
    if FindFirst(ScanDir + '/*.xdb', faAnyFile, SearchRec) = 0 then
    begin
      repeat
        CheckDatabase(ScanDir + '/' + SearchRec.Name);
      until FindNext(SearchRec) <> 0;
      FindClose(SearchRec);
    end
    else
      WriteLn('No .xdb files found in directory');
  end
  else
  begin
    for I := 1 to ParamCount do
      CheckDatabase(ParamStr(I));
  end;
  
  WriteLn('Migration check complete.');
end.
```

## Success Criteria

### Package Creation
- [ ] Windows installer (NSIS) builds successfully
- [ ] Linux .deb package creates without errors
- [ ] All executables included in packages
- [ ] File associations work correctly
- [ ] Shortcuts/menu entries created

### Documentation
- [ ] README with installation instructions
- [ ] CHANGELOG documenting conversion changes
- [ ] Basic migration guide for existing users
- [ ] Version information properly embedded

### Release Management
- [ ] Version numbering consistent across all components
- [ ] Release builds clean and reproducible
- [ ] Archive packages created (ZIP, tar.gz)
- [ ] Migration tool validates existing databases

## Deliverables

1. **Windows installer** - NSIS-based setup.exe
2. **Linux package** - Debian .deb package
3. **Release archives** - ZIP and tar.gz distributions
4. **Documentation package** - README, CHANGELOG, migration guide
5. **Migration tool** - Database compatibility checker
6. **Version management** - Consistent versioning across components

---
*Duration*: 1-2 days  
*Dependencies*: Phase 3 complete  
*Output*: Distributable packages and documentation