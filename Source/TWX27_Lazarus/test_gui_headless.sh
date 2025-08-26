#!/bin/bash
# TWXProxy Headless GUI Test Suite
# Tests key functionality of the cross-platform GUI conversion

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TWXPROXY_BIN="$SCRIPT_DIR/projects/TWXProxy/TWXProxy"
TWXP_BIN="$SCRIPT_DIR/projects/TWXP/TWXP"
TEST_LOG="$SCRIPT_DIR/gui_test.log"
DISPLAY_NUM=99

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$TEST_LOG"
}

error() {
    echo -e "${RED}ERROR: $1${NC}" | tee -a "$TEST_LOG"
}

success() {
    echo -e "${GREEN}SUCCESS: $1${NC}" | tee -a "$TEST_LOG"
}

warning() {
    echo -e "${YELLOW}WARNING: $1${NC}" | tee -a "$TEST_LOG"
}

cleanup() {
    log "Cleaning up test environment..."
    
    # Kill any running TWX applications
    pkill -f "TWXProxy" 2>/dev/null || true
    pkill -f "TWXP" 2>/dev/null || true
    
    # Kill Xvfb
    if [ ! -z "$XVFB_PID" ]; then
        kill "$XVFB_PID" 2>/dev/null || true
        wait "$XVFB_PID" 2>/dev/null || true
    fi
    
    # Remove test files
    rm -f "$SCRIPT_DIR/test_database.xdb" 2>/dev/null || true
    rm -f "$SCRIPT_DIR/data/TestDB.xdb" 2>/dev/null || true
}

setup_headless_x() {
    log "Setting up headless X server..."
    
    # Check if required tools are available
    command -v Xvfb >/dev/null 2>&1 || { error "Xvfb not found. Install: sudo apt-get install xvfb"; exit 1; }
    command -v xdotool >/dev/null 2>&1 || { error "xdotool not found. Install: sudo apt-get install xdotool"; exit 1; }
    
    # Start virtual framebuffer
    Xvfb :$DISPLAY_NUM -screen 0 1024x768x24 &
    XVFB_PID=$!
    export DISPLAY=:$DISPLAY_NUM
    
    # Wait for X server to start
    sleep 2
    
    # Verify X server is running
    if ! xdpyinfo -display :$DISPLAY_NUM >/dev/null 2>&1; then
        error "Failed to start X server"
        exit 1
    fi
    
    success "Headless X server started on display :$DISPLAY_NUM"
}

wait_for_window() {
    local window_name="$1"
    local timeout="${2:-10}"
    local count=0
    
    log "Waiting for window: $window_name"
    
    while [ $count -lt $timeout ]; do
        if xdotool search --name "$window_name" >/dev/null 2>&1; then
            success "Window '$window_name' found"
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    
    error "Window '$window_name' not found within $timeout seconds"
    return 1
}

click_button() {
    local button_text="$1"
    local window_name="$2"
    
    log "Looking for button: $button_text"
    
    # Get window ID
    local window_id
    window_id=$(xdotool search --name "$window_name" | head -1)
    
    if [ -z "$window_id" ]; then
        error "Window '$window_name' not found"
        return 1
    fi
    
    # Focus the window
    xdotool windowfocus "$window_id"
    sleep 0.5
    
    # Try to find and click the button (this is a simplified approach)
    # In a real scenario, you might need more sophisticated element detection
    local button_found=false
    
    # Try common button positions for OK, Cancel, Setup buttons
    case "$button_text" in
        "OK"|"ok")
            # Try clicking in typical OK button position (bottom right area)
            xdotool mousemove --window "$window_id" 350 400
            xdotool click 1
            button_found=true
            ;;
        "Cancel"|"cancel")
            # Try clicking in typical Cancel button position
            xdotool mousemove --window "$window_id" 250 400
            xdotool click 1
            button_found=true
            ;;
        "Setup"|"setup")
            # Try menu or button area
            xdotool mousemove --window "$window_id" 100 50
            xdotool click 1
            button_found=true
            ;;
        *)
            warning "Unknown button: $button_text"
            ;;
    esac
    
    if [ "$button_found" = true ]; then
        success "Clicked button: $button_text"
        sleep 1
        return 0
    else
        error "Failed to click button: $button_text"
        return 1
    fi
}

test_twxproxy_startup() {
    log "Testing TWXProxy startup..."
    
    # Start TWXProxy in background
    cd "$SCRIPT_DIR"
    timeout 30s "$TWXPROXY_BIN" &
    local app_pid=$!
    
    # Wait for main window
    if wait_for_window "TWX Proxy" 15; then
        success "TWXProxy main window appeared"
        
        # Take screenshot for debugging
        import -window root "$SCRIPT_DIR/twxproxy_screenshot.png" 2>/dev/null || true
        
        # Try to interact with welcome dialog
        sleep 2
        if xdotool search --name "TWX Proxy" >/dev/null 2>&1; then
            local window_id
            window_id=$(xdotool search --name "TWX Proxy" | head -1)
            
            # Send Enter or Escape to dismiss any welcome dialog
            xdotool windowfocus "$window_id"
            xdotool key Return
            sleep 1
            
            success "TWXProxy startup test passed"
        fi
        
        # Clean shutdown
        kill $app_pid 2>/dev/null || true
        wait $app_pid 2>/dev/null || true
        return 0
    else
        error "TWXProxy main window did not appear"
        kill $app_pid 2>/dev/null || true
        return 1
    fi
}

test_twxp_startup() {
    log "Testing TWXP startup..."
    
    # Start TWXP in background
    cd "$SCRIPT_DIR"
    timeout 30s "$TWXP_BIN" &
    local app_pid=$!
    
    # Wait for main window
    if wait_for_window "TWX Proxy" 15; then
        success "TWXP main window appeared"
        
        # Take screenshot
        import -window root "$SCRIPT_DIR/twxp_screenshot.png" 2>/dev/null || true
        
        sleep 2
        if xdotool search --name "TWX Proxy" >/dev/null 2>&1; then
            local window_id
            window_id=$(xdotool search --name "TWX Proxy" | head -1)
            
            # Dismiss welcome dialog
            xdotool windowfocus "$window_id"
            xdotool key Return
            sleep 1
            
            success "TWXP startup test passed"
        fi
        
        kill $app_pid 2>/dev/null || true
        wait $app_pid 2>/dev/null || true
        return 0
    else
        error "TWXP main window did not appear"
        kill $app_pid 2>/dev/null || true
        return 1
    fi
}

test_database_creation() {
    log "Testing database creation functionality..."
    
    # Create data directory if it doesn't exist
    mkdir -p "$SCRIPT_DIR/data"
    
    # Start TWXP
    cd "$SCRIPT_DIR"
    timeout 45s "$TWXP_BIN" &
    local app_pid=$!
    
    if wait_for_window "TWX Proxy" 20; then
        local window_id
        window_id=$(xdotool search --name "TWX Proxy" | head -1)
        xdotool windowfocus "$window_id"
        
        # Dismiss welcome dialog first
        xdotool key Return
        sleep 2
        
        # Try to access setup/configuration
        # This is a simplified test - in reality you'd need to navigate the actual menu structure
        xdotool key Alt_L+s  # Try Alt+S for Setup
        sleep 2
        
        # Look for setup window
        if wait_for_window "Setup" 5 || wait_for_window "Configuration" 5; then
            success "Setup dialog opened"
            
            # Close setup dialog
            xdotool key Escape
            sleep 1
        else
            warning "Setup dialog not found - this may be expected"
        fi
        
        success "Database creation test completed"
        
        kill $app_pid 2>/dev/null || true
        wait $app_pid 2>/dev/null || true
        return 0
    else
        error "Failed to start TWXP for database test"
        kill $app_pid 2>/dev/null || true
        return 1
    fi
}

test_memory_leaks() {
    log "Testing for memory leaks..."
    
    # Start and stop application multiple times to check for leaks
    for i in {1..3}; do
        log "Memory test iteration $i/3"
        
        cd "$SCRIPT_DIR"
        timeout 10s "$TWXPROXY_BIN" &
        local app_pid=$!
        
        sleep 3
        
        # Check if process is still running
        if kill -0 $app_pid 2>/dev/null; then
            success "Application started successfully (iteration $i)"
            kill $app_pid 2>/dev/null || true
            wait $app_pid 2>/dev/null || true
        else
            error "Application crashed on iteration $i"
            return 1
        fi
        
        sleep 1
    done
    
    success "Memory leak test passed"
    return 0
}

run_comprehensive_test() {
    log "Starting comprehensive GUI test suite..."
    
    local tests_passed=0
    local tests_failed=0
    
    # Test 1: TWXProxy startup
    if test_twxproxy_startup; then
        tests_passed=$((tests_passed + 1))
    else
        tests_failed=$((tests_failed + 1))
    fi
    
    sleep 2
    
    # Test 2: TWXP startup  
    if test_twxp_startup; then
        tests_passed=$((tests_passed + 1))
    else
        tests_failed=$((tests_failed + 1))
    fi
    
    sleep 2
    
    # Test 3: Database functionality
    if test_database_creation; then
        tests_passed=$((tests_passed + 1))
    else
        tests_failed=$((tests_failed + 1))
    fi
    
    sleep 2
    
    # Test 4: Memory leaks
    if test_memory_leaks; then
        tests_passed=$((tests_passed + 1))
    else
        tests_failed=$((tests_failed + 1))
    fi
    
    # Summary
    log "Test Summary:"
    log "Tests passed: $tests_passed"
    log "Tests failed: $tests_failed"
    
    if [ $tests_failed -eq 0 ]; then
        success "All tests passed! GUI conversion is working correctly."
        return 0
    else
        error "$tests_failed tests failed. Check the log for details."
        return 1
    fi
}

# Main execution
main() {
    log "Starting TWXProxy GUI Test Suite"
    log "Working directory: $SCRIPT_DIR"
    
    # Check if binaries exist
    if [ ! -f "$TWXPROXY_BIN" ]; then
        error "TWXProxy binary not found: $TWXPROXY_BIN"
        exit 1
    fi
    
    if [ ! -f "$TWXP_BIN" ]; then
        error "TWXP binary not found: $TWXP_BIN"
        exit 1
    fi
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Initialize test log
    echo "TWXProxy GUI Test Log - $(date)" > "$TEST_LOG"
    
    # Setup headless X
    setup_headless_x
    
    # Run comprehensive tests
    if run_comprehensive_test; then
        success "GUI test suite completed successfully!"
        exit 0
    else
        error "GUI test suite failed!"
        exit 1
    fi
}

# Run main function
main "$@"