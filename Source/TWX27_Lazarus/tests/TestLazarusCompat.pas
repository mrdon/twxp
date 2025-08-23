unit TestLazarusCompat;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testutils, testregistry,
  LazarusCompat;

type
  TTestLazarusCompat = class(TTestCase)
  private
    FTestDir: string;
    FTestFile: string;
    FConfig: TTWXConfig;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    // Cross-platform system functions tests
    procedure TestGetCurrentProcessId;
    procedure TestGetSystemInfo;
    procedure TestGetUserDir;
    procedure TestGetAppDataDir;
    procedure TestGetConfigDir;
    
    // File operations tests
    procedure TestDirectoryOperations;
    procedure TestFileExists;
    procedure TestCreateDir;
    procedure TestGetFileSize;
    procedure TestSetFileReadOnly;
    
    // Hardware identification tests
    procedure TestHardwareID1;
    procedure TestHardwareID2;
    procedure TestMachineGUID;
    
    // Configuration system tests
    procedure TestConfigStringOperations;
    procedure TestConfigIntegerOperations;
    procedure TestConfigBooleanOperations;
    procedure TestConfigPersistence;
    
    // String utility tests
    procedure TestStrToIntSafe;
    procedure TestStripFileExtension;
    procedure TestShortFilename;
  end;

implementation

procedure TTestLazarusCompat.SetUp;
begin
  FTestDir := TWX_GetUserDir + PathSep + 'twx_unit_test_' + IntToStr(Random(10000));
  FTestFile := FTestDir + PathSep + 'test.txt';
  FConfig := TTWXConfig.Create;
end;

procedure TTestLazarusCompat.TearDown;
begin
  FConfig.Free;
  // Cleanup test files
  try
    if TWX_FileExists(FTestFile) then
      DeleteFile(FTestFile);
    if TWX_DirectoryExists(FTestDir) then
      RemoveDir(FTestDir);
  except
    // Ignore cleanup errors
  end;
end;

// Cross-platform system functions tests

procedure TTestLazarusCompat.TestGetCurrentProcessId;
begin
  AssertTrue('Process ID should be > 0', TWX_GetCurrentProcessId > 0);
end;

procedure TTestLazarusCompat.TestGetSystemInfo;
var
  SysInfo: string;
begin
  SysInfo := TWX_GetSystemInfo;
  AssertTrue('System info should not be empty', SysInfo <> '');
  AssertTrue('System info should contain OS name', 
    (Pos('Windows', SysInfo) > 0) or (Pos('Linux', SysInfo) > 0) or (Pos('macOS', SysInfo) > 0));
end;

procedure TTestLazarusCompat.TestGetUserDir;
var
  UserDir: string;
begin
  UserDir := TWX_GetUserDir;
  AssertTrue('User directory should not be empty', UserDir <> '');
  AssertTrue('User directory should exist', TWX_DirectoryExists(UserDir));
end;

procedure TTestLazarusCompat.TestGetAppDataDir;
var
  AppDataDir: string;
begin
  AppDataDir := TWX_GetAppDataDir;
  AssertTrue('App data directory should not be empty', AppDataDir <> '');
  AssertTrue('App data directory should contain twxproxy', Pos('twxproxy', LowerCase(AppDataDir)) > 0);
end;

procedure TTestLazarusCompat.TestGetConfigDir;
var
  ConfigDir: string;
begin
  ConfigDir := TWX_GetConfigDir;
  AssertTrue('Config directory should not be empty', ConfigDir <> '');
  AssertTrue('Config directory should contain twxproxy', Pos('twxproxy', LowerCase(ConfigDir)) > 0);
end;

// File operations tests

procedure TTestLazarusCompat.TestDirectoryOperations;
begin
  AssertFalse('Test directory should not exist initially', TWX_DirectoryExists(FTestDir));
  AssertTrue('Should be able to create test directory', TWX_CreateDir(FTestDir));
  AssertTrue('Test directory should exist after creation', TWX_DirectoryExists(FTestDir));
end;

procedure TTestLazarusCompat.TestFileExists;
var
  TestContent: TStringList;
begin
  // Create test directory first
  TWX_CreateDir(FTestDir);
  
  AssertFalse('Test file should not exist initially', TWX_FileExists(FTestFile));
  
  // Create test file
  TestContent := TStringList.Create;
  try
    TestContent.Add('Test content');
    TestContent.SaveToFile(FTestFile);
  finally
    TestContent.Free;
  end;
  
  AssertTrue('Test file should exist after creation', TWX_FileExists(FTestFile));
end;

procedure TTestLazarusCompat.TestCreateDir;
var
  NestedDir: string;
begin
  NestedDir := FTestDir + PathSep + 'nested' + PathSep + 'deep';
  AssertTrue('Should be able to create nested directories', TWX_CreateDir(NestedDir));
  AssertTrue('Nested directory should exist', TWX_DirectoryExists(NestedDir));
end;

procedure TTestLazarusCompat.TestGetFileSize;
var
  TestContent: TStringList;
  FileSize: Int64;
  ExpectedSize: Integer;
begin
  // Create test directory and file
  TWX_CreateDir(FTestDir);
  
  TestContent := TStringList.Create;
  try
    TestContent.Add('Line 1');
    TestContent.Add('Line 2');
    TestContent.Add('Line 3');
    TestContent.SaveToFile(FTestFile);
    ExpectedSize := Length(TestContent.Text);
  finally
    TestContent.Free;
  end;
  
  FileSize := TWX_GetFileSize(FTestFile);
  AssertTrue('File size should be > 0', FileSize > 0);
  AssertTrue('File size should be reasonable', FileSize < 1000); // Small test file
end;

procedure TTestLazarusCompat.TestSetFileReadOnly;
var
  TestContent: TStringList;
begin
  // Create test directory and file
  TWX_CreateDir(FTestDir);
  
  TestContent := TStringList.Create;
  try
    TestContent.Add('Test content');
    TestContent.SaveToFile(FTestFile);
  finally
    TestContent.Free;
  end;
  
  AssertTrue('Should be able to set file read-only', TWX_SetFileReadOnly(FTestFile, True));
  AssertTrue('Should be able to remove read-only', TWX_SetFileReadOnly(FTestFile, False));
end;

// Hardware identification tests

procedure TTestLazarusCompat.TestHardwareID1;
var
  ID1: Cardinal;
begin
  ID1 := TWX_GetHardwareID1;
  AssertTrue('Hardware ID1 should be non-zero', ID1 <> 0);
  // Should be consistent across calls
  AssertEquals('Hardware ID1 should be consistent', ID1, TWX_GetHardwareID1);
end;

procedure TTestLazarusCompat.TestHardwareID2;
var
  ID2: Cardinal;
begin
  ID2 := TWX_GetHardwareID2;
  AssertTrue('Hardware ID2 should be non-zero', ID2 <> 0);
  // Should be consistent across calls
  AssertEquals('Hardware ID2 should be consistent', ID2, TWX_GetHardwareID2);
  // Should be different from ID1
  AssertTrue('Hardware ID2 should differ from ID1', ID2 <> TWX_GetHardwareID1);
end;

procedure TTestLazarusCompat.TestMachineGUID;
var
  GUID: string;
begin
  GUID := TWX_GetMachineGUID;
  AssertTrue('Machine GUID should not be empty', GUID <> '');
  AssertTrue('Machine GUID should be reasonable length', Length(GUID) > 10);
  // Should be consistent across calls
  AssertEquals('Machine GUID should be consistent', GUID, TWX_GetMachineGUID);
end;

// Configuration system tests

procedure TTestLazarusCompat.TestConfigStringOperations;
const
  TestSection = 'UnitTest';
  TestKey = 'StringTest';
  TestValue = 'Hello Unit Tests';
  DefaultValue = 'Default';
begin
  // Test writing and reading
  AssertTrue('Should be able to write string value', 
    FConfig.WriteString(TestSection, TestKey, TestValue));
  
  AssertEquals('Should read back the same string value', 
    TestValue, FConfig.ReadString(TestSection, TestKey, DefaultValue));
    
  // Test default value for non-existent key
  AssertEquals('Should return default for non-existent key',
    DefaultValue, FConfig.ReadString(TestSection, 'NonExistentKey', DefaultValue));
end;

procedure TTestLazarusCompat.TestConfigIntegerOperations;
const
  TestSection = 'UnitTest';
  TestKey = 'IntegerTest';
  TestValue = 12345;
  DefaultValue = -1;
begin
  // Test writing and reading
  AssertTrue('Should be able to write integer value', 
    FConfig.WriteInteger(TestSection, TestKey, TestValue));
  
  AssertEquals('Should read back the same integer value', 
    TestValue, FConfig.ReadInteger(TestSection, TestKey, DefaultValue));
    
  // Test default value for non-existent key
  AssertEquals('Should return default for non-existent key',
    DefaultValue, FConfig.ReadInteger(TestSection, 'NonExistentKey', DefaultValue));
end;

procedure TTestLazarusCompat.TestConfigBooleanOperations;
const
  TestSection = 'UnitTest';
  TestKey = 'BooleanTest';
  TestValue = True;
  DefaultValue = False;
begin
  // Test writing and reading
  AssertTrue('Should be able to write boolean value', 
    FConfig.WriteBool(TestSection, TestKey, TestValue));
  
  AssertEquals('Should read back the same boolean value', 
    TestValue, FConfig.ReadBool(TestSection, TestKey, DefaultValue));
    
  // Test default value for non-existent key
  AssertEquals('Should return default for non-existent key',
    DefaultValue, FConfig.ReadBool(TestSection, 'NonExistentKey', DefaultValue));
end;

procedure TTestLazarusCompat.TestConfigPersistence;
var
  Config2: TTWXConfig;
const
  TestSection = 'PersistenceTest';
  TestKey = 'TestKey';
  TestValue = 'Persistence Test Value';
begin
  // Write with first config instance
  FConfig.WriteString(TestSection, TestKey, TestValue);
  
  // Read with new config instance
  Config2 := TTWXConfig.Create;
  try
    AssertEquals('Config should persist across instances', 
      TestValue, Config2.ReadString(TestSection, TestKey, ''));
  finally
    Config2.Free;
  end;
end;

// String utility tests

procedure TTestLazarusCompat.TestStrToIntSafe;
begin
  AssertEquals('Should convert valid number', 123, StrToIntSafe('123'));
  AssertEquals('Should convert negative number', -456, StrToIntSafe('-456'));
  AssertEquals('Should return 0 for invalid string', 0, StrToIntSafe('invalid'));
  AssertEquals('Should return 0 for empty string', 0, StrToIntSafe(''));
  AssertEquals('Should return 0 for mixed string', 0, StrToIntSafe('123abc'));
end;

procedure TTestLazarusCompat.TestStripFileExtension;
begin
  AssertEquals('Should strip .txt extension', 'test', StripFileExtension('test.txt'));
  AssertEquals('Should strip .pas extension', 'unit', StripFileExtension('unit.pas'));
  AssertEquals('Should handle no extension', 'noext', StripFileExtension('noext'));
  AssertEquals('Should handle multiple dots', 'file.backup', StripFileExtension('file.backup.bak'));
  AssertEquals('Should handle path with extension', '/path/file', StripFileExtension('/path/file.ext'));
end;

procedure TTestLazarusCompat.TestShortFilename;
begin
  AssertEquals('Should extract filename', 'test.txt', ShortFilename('test.txt'));
  AssertEquals('Should extract from path', 'file.pas', ShortFilename('/path/to/file.pas'));
  AssertEquals('Should handle Windows path', 'file.exe', ShortFilename('C:\path\to\file.exe'));
  AssertEquals('Should handle mixed separators', 'file.txt', ShortFilename('/path\mixed/file.txt'));
end;

initialization
  RegisterTest(TTestLazarusCompat);
end.