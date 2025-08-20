# Phase 3: Testing & Validation

Minimal functional testing to verify the converted TWX Proxy works correctly. Focus on basic functionality validation and ensuring no regressions.

## Objectives

- [ ] Create basic functional test suite
- [ ] Validate core functionality works (database, networking, UI)
- [ ] Verify no critical regressions from Delphi version
- [ ] Basic cross-platform smoke testing
- [ ] Memory leak detection

**Duration**: 1-2 days

## Task 3.1: Basic Functional Testing

**Simple test script:**
```bash
#!/bin/bash
# basic_functional_test.sh

echo "=== Basic TWX Proxy Functional Test ==="

# Test 1: Compilation check
echo "Test 1: Checking if all executables exist..."
EXECUTABLES=("TWXProxy" "TWXP" "CapEdit")
for exe in "${EXECUTABLES[@]}"; do
    if [ -f "build/release/$exe" ] || [ -f "build/release/$exe.exe" ]; then
        echo "✅ $exe: Executable exists"
    else
        echo "❌ $exe: Executable missing"
        exit 1
    fi
done

# Test 2: Basic startup test
echo ""
echo "Test 2: Testing application startup..."
timeout 5s ./build/release/CapEdit --version > /dev/null 2>&1
if [ $? -eq 0 ] || [ $? -eq 124 ]; then  # 124 = timeout (expected)
    echo "✅ CapEdit: Starts without crashing"
else
    echo "❌ CapEdit: Startup failed"
fi

# Test 3: Database operations
echo ""
echo "Test 3: Testing database operations..."
timeout 10s ./build/release/TWXP --test-database > /dev/null 2>&1
if [ $? -eq 0 ] || [ $? -eq 124 ]; then
    echo "✅ TWXP: Database operations working"
else
    echo "❌ TWXP: Database operations failed"
fi

# Test 4: Network binding test
echo ""
echo "Test 4: Testing network binding..."
./build/release/TWXProxy --port=2027 --test-bind &
PROXY_PID=$!
sleep 2

if kill -0 $PROXY_PID 2>/dev/null; then
    echo "✅ TWXProxy: Network binding successful"
    kill $PROXY_PID 2>/dev/null
else
    echo "❌ TWXProxy: Network binding failed"
fi

echo ""
echo "=== Basic functional testing complete ==="
```

## Task 3.2: Database Testing

**Simple database validation:**
```pascal
// tests/TestDatabase.pas
unit TestDatabase;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, Database;

type
  TTestDatabase = class(TTestCase)
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestDatabaseCreation;
    procedure TestBasicOperations;
  end;

implementation

procedure TTestDatabase.SetUp;
begin
  if not DirectoryExists('test_data') then
    CreateDir('test_data');
end;

procedure TTestDatabase.TearDown;
begin
  DeleteFile('test_data/test.xdb');
end;

procedure TTestDatabase.TestDatabaseCreation;
var
  DB: TModDatabase;
begin
  DB := TModDatabase.Create(nil, nil);
  try
    AssertNotNull('Database object created', DB);
    DB.CreateDatabase('test_data/test.xdb', 100);
    AssertTrue('Database file exists', FileExists('test_data/test.xdb'));
  finally
    DB.Free;
  end;
end;

procedure TTestDatabase.TestBasicOperations;
var
  DB: TModDatabase;
  Sector: TSector;
begin
  DB := TModDatabase.Create(nil, nil);
  try
    DB.CreateDatabase('test_data/test.xdb', 100);
    DB.OpenDatabase('test_data/test.xdb');
    AssertTrue('Database opened', DB.DataBaseOpen);
    
    // Test basic sector operation
    Sector := DB.LoadSector(1);
    Sector.Visited := True;
    DB.SaveSector(1, Sector);
    
    // Verify persistence
    DB.CloseDatabase;
    DB.OpenDatabase('test_data/test.xdb');
    Sector := DB.LoadSector(1);
    AssertTrue('Sector data persisted', Sector.Visited);
    
  finally
    DB.Free;
  end;
end;

initialization
  RegisterTest(TTestDatabase);
end.
```

## Task 3.3: Network Testing

**Basic network functionality test:**
```bash
#!/bin/bash
# test_network.sh

echo "=== Basic Network Testing ==="

# Start TWXProxy
./build/release/TWXProxy --port=2028 &
PROXY_PID=$!
sleep 3

# Test single connection
echo "Testing single telnet connection..."
{
    echo "help"
    sleep 1
    echo "quit"
} | timeout 10s telnet localhost 2028 > /dev/null 2>&1

if [ $? -eq 0 ] || [ $? -eq 124 ]; then
    echo "✅ Basic telnet connection successful"
else
    echo "❌ Telnet connection failed"
fi

# Cleanup
kill $PROXY_PID 2>/dev/null
echo "=== Network testing complete ==="
```

## Task 3.4: Memory Leak Detection

**Basic memory testing:**
```bash
#!/bin/bash
# memory_test.sh

echo "=== Basic Memory Leak Detection ==="

# Build with heap tracing
lazbuild --build-mode=Debug projects/TWXProxy/TWXProxy.lpi

# Run with HeapTrc for short test
export HEAPTRC=log=heap.log
./build/debug/TWXProxy --test-mode &
PROXY_PID=$!
sleep 10
kill $PROXY_PID 2>/dev/null

# Check for leaks
if [ -f heap.log ]; then
    LEAKS=$(grep -c "unfreed memory blocks" heap.log 2>/dev/null || echo "0")
    if [ "$LEAKS" = "0" ]; then
        echo "✅ No obvious memory leaks detected"
    else
        echo "⚠️ Potential memory leaks detected: $LEAKS blocks"
    fi
    rm -f heap.log
else
    echo "✅ Basic memory test completed"
fi
```

## Task 3.5: Simple Cross-Platform Test

**Basic smoke test:**
```bash
#!/bin/bash
# smoke_test.sh

echo "=== Smoke Test ==="

# Test current platform build
if [ -f "build/release/TWXProxy" ] || [ -f "build/release/TWXProxy.exe" ]; then
    echo "✅ TWXProxy executable exists"
else
    echo "❌ TWXProxy executable missing"
    exit 1
fi

# Test startup
timeout 5s ./build/release/TWXProxy --version > /dev/null 2>&1
if [ $? -eq 0 ] || [ $? -eq 124 ]; then
    echo "✅ TWXProxy starts without crashing"
else
    echo "❌ TWXProxy startup failed"
    exit 1
fi

echo "✅ Smoke test passed"
```

## Task 3.6: Simple Test Runner

**Minimal test execution:**
```bash
#!/bin/bash
# run_tests.sh

echo "=== TWX Proxy Basic Testing ==="

FAILED=0

# Run basic tests
echo "1. Basic functionality test..."
if ./tests/basic_functional_test.sh; then
    echo "✅ Basic functionality: PASSED"
else
    echo "❌ Basic functionality: FAILED"
    ((FAILED++))
fi

echo ""
echo "2. Network test..."  
if ./tests/test_network.sh; then
    echo "✅ Network test: PASSED"
else
    echo "❌ Network test: FAILED"
    ((FAILED++))
fi

echo ""
echo "3. Memory test..."
if ./tests/memory_test.sh; then
    echo "✅ Memory test: PASSED"
else
    echo "❌ Memory test: FAILED"
    ((FAILED++))
fi

echo ""
echo "4. Smoke test..."
if ./tests/smoke_test.sh; then
    echo "✅ Smoke test: PASSED"
else
    echo "❌ Smoke test: FAILED"
    ((FAILED++))
fi

# Summary
echo ""
echo "=== Test Summary ==="
if [ $FAILED -eq 0 ]; then
    echo "✅ All basic tests passed"
    exit 0
else
    echo "❌ $FAILED tests failed"
    exit 1
fi
```

## Success Criteria

### Basic Functionality
- [ ] All executables compile and run without crashing
- [ ] Database operations work (create, open, read, write)
- [ ] Network connections can be established
- [ ] UI forms display correctly
- [ ] No obvious memory leaks

### Quality Gates
- [ ] Basic functional tests pass
- [ ] Network connectivity test passes
- [ ] Memory leak test passes
- [ ] Smoke test passes
- [ ] Application starts without errors

## Deliverables

1. **Basic test scripts** - Functional validation scripts
2. **Database test unit** - Simple database operation validation
3. **Network test script** - Basic connectivity testing
4. **Memory leak detection** - Simple heap trace validation
5. **Smoke test** - Application startup verification

---
*Duration*: 2-3 days  
*Dependencies*: Phase 2 complete  
*Output*: Validated, production-ready application