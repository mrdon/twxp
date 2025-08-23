# TWX Proxy Lazarus Cross-Platform Makefile
# Works on Linux, macOS, and Windows (with Make available)

# Detect operating system
ifeq ($(OS),Windows_NT)
    DETECTED_OS := Windows
    EXE_EXT := .exe
    PATH_SEP := \\
    LAZBUILD := lazbuild.exe
    MKDIR_P := if not exist
    COPY_CMD := copy
else
    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Linux)
        DETECTED_OS := Linux
    endif
    ifeq ($(UNAME_S),Darwin)
        DETECTED_OS := macOS
    endif
    EXE_EXT := 
    PATH_SEP := /
    LAZBUILD := lazbuild
    MKDIR_P := mkdir -p
    COPY_CMD := cp
endif

# Project settings
PROJECT_NAME := CapEdit
PROJECT_DIR := projects/$(PROJECT_NAME)
TEST_PROJECT_NAME := TWXTests
TEST_PROJECT_DIR := tests
SOURCE_DIR := source
BIN_DIR := bin
TARGET_ARCH := $(shell uname -m 2>/dev/null || echo "unknown")
TARGET_OS_LOWER := $(shell echo $(DETECTED_OS) | tr '[:upper:]' '[:lower:]')

# Output directories
ifeq ($(DETECTED_OS),Windows)
    OUTPUT_DIR := $(BIN_DIR)$(PATH_SEP)i386-win32
    TEST_OUTPUT_DIR := $(BIN_DIR)$(PATH_SEP)test-i386-win32
else
    OUTPUT_DIR := $(BIN_DIR)$(PATH_SEP)$(TARGET_ARCH)-$(TARGET_OS_LOWER)
    TEST_OUTPUT_DIR := $(BIN_DIR)$(PATH_SEP)test-debug-$(TARGET_OS_LOWER)64
endif

# Build targets
.PHONY: all clean capedit twxp twxproxy info help test

# Default target
all: info capedit twxp twxproxy

# Show build information
info:
	@echo "=== TWX Proxy Lazarus Build ==="
	@echo "Detected OS: $(DETECTED_OS)"
	@echo "Target: $(TARGET_ARCH)-$(TARGET_OS_LOWER)"
	@echo "Lazbuild: $(LAZBUILD)"
	@echo "Output Dir: $(OUTPUT_DIR)"
	@echo "================================"

# Build CapEdit
capedit:
	@echo "Building $(PROJECT_NAME)..."
ifeq ($(DETECTED_OS),Windows)
	$(MKDIR_P) "$(OUTPUT_DIR)" mkdir "$(OUTPUT_DIR)"
	$(LAZBUILD) --build-mode=Release $(PROJECT_DIR)$(PATH_SEP)$(PROJECT_NAME).lpi
	$(COPY_CMD) "$(PROJECT_DIR)$(PATH_SEP)$(PROJECT_NAME)$(EXE_EXT)" "$(OUTPUT_DIR)$(PATH_SEP)"
else
	$(MKDIR_P) $(OUTPUT_DIR)
	$(LAZBUILD) --build-mode=Release $(PROJECT_DIR)/$(PROJECT_NAME).lpi
	$(COPY_CMD) $(PROJECT_DIR)/$(PROJECT_NAME)$(EXE_EXT) $(OUTPUT_DIR)/
endif
	@echo "Build completed successfully!"
	@echo "Executable: $(OUTPUT_DIR)$(PATH_SEP)$(PROJECT_NAME)$(EXE_EXT)"

# Build TWXP
twxp:
	@echo "Building TWXP..."
ifeq ($(DETECTED_OS),Windows)
	$(MKDIR_P) "$(OUTPUT_DIR)" mkdir "$(OUTPUT_DIR)"
	$(LAZBUILD) --build-mode=Release projects$(PATH_SEP)TWXP$(PATH_SEP)TWXP.lpi
	$(COPY_CMD) "projects$(PATH_SEP)TWXP$(PATH_SEP)TWXP$(EXE_EXT)" "$(OUTPUT_DIR)$(PATH_SEP)"
else
	$(MKDIR_P) $(OUTPUT_DIR)
	$(LAZBUILD) --build-mode=Release projects/TWXP/TWXP.lpi
	$(COPY_CMD) projects/TWXP/TWXP$(EXE_EXT) $(OUTPUT_DIR)/
endif
	@echo "TWXP build completed successfully!"
	@echo "Executable: $(OUTPUT_DIR)$(PATH_SEP)TWXP$(EXE_EXT)"

# Build TWXProxy
twxproxy:
	@echo "Building TWXProxy..."
ifeq ($(DETECTED_OS),Windows)
	$(MKDIR_P) "$(OUTPUT_DIR)" mkdir "$(OUTPUT_DIR)"
	$(LAZBUILD) --build-mode=Release projects$(PATH_SEP)TWXProxy$(PATH_SEP)TWXProxy.lpi
	$(COPY_CMD) "projects$(PATH_SEP)TWXProxy$(PATH_SEP)TWXProxy$(EXE_EXT)" "$(OUTPUT_DIR)$(PATH_SEP)"
else
	$(MKDIR_P) $(OUTPUT_DIR)
	$(LAZBUILD) --build-mode=Release projects/TWXProxy/TWXProxy.lpi
	$(COPY_CMD) projects/TWXProxy/TWXProxy$(EXE_EXT) $(OUTPUT_DIR)/
endif
	@echo "TWXProxy build completed successfully!"
	@echo "Executable: $(OUTPUT_DIR)$(PATH_SEP)TWXProxy$(EXE_EXT)"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
ifeq ($(DETECTED_OS),Windows)
	if exist "$(PROJECT_DIR)$(PATH_SEP)lib" rmdir /s /q "$(PROJECT_DIR)$(PATH_SEP)lib"
	if exist "$(PROJECT_DIR)$(PATH_SEP)$(PROJECT_NAME)$(EXE_EXT)" del "$(PROJECT_DIR)$(PATH_SEP)$(PROJECT_NAME)$(EXE_EXT)"
	if exist "$(BIN_DIR)" rmdir /s /q "$(BIN_DIR)"
else
	rm -rf $(PROJECT_DIR)/lib
	rm -f $(PROJECT_DIR)/$(PROJECT_NAME)$(EXE_EXT)
	rm -rf $(BIN_DIR)
endif
	@echo "Clean completed!"

# Debug build
debug:
	@echo "Building $(PROJECT_NAME) in Debug mode..."
ifeq ($(DETECTED_OS),Windows)
	$(MKDIR_P) "$(OUTPUT_DIR)" mkdir "$(OUTPUT_DIR)"
	$(LAZBUILD) --build-mode=Debug $(PROJECT_DIR)$(PATH_SEP)$(PROJECT_NAME).lpi
	$(COPY_CMD) "$(PROJECT_DIR)$(PATH_SEP)$(PROJECT_NAME)$(EXE_EXT)" "$(OUTPUT_DIR)$(PATH_SEP)"
else
	$(MKDIR_P) $(OUTPUT_DIR)
	$(LAZBUILD) --build-mode=Debug $(PROJECT_DIR)/$(PROJECT_NAME).lpi
	$(COPY_CMD) $(PROJECT_DIR)/$(PROJECT_NAME)$(EXE_EXT) $(OUTPUT_DIR)/
endif
	@echo "Debug build completed!"

# Install (copy to system directory - placeholder for future)
install: capedit
	@echo "Install target not implemented yet."
	@echo "Executable available at: $(OUTPUT_DIR)$(PATH_SEP)$(PROJECT_NAME)$(EXE_EXT)"

# Build and run unit tests
test:
	@echo "Building and running unit tests..."
ifeq ($(DETECTED_OS),Windows)
	$(MKDIR_P) "$(TEST_OUTPUT_DIR)" mkdir "$(TEST_OUTPUT_DIR)"
	$(LAZBUILD) --build-mode=Debug $(TEST_PROJECT_DIR)$(PATH_SEP)$(TEST_PROJECT_NAME).lpi
	"$(TEST_OUTPUT_DIR)$(PATH_SEP)$(TEST_PROJECT_NAME)$(EXE_EXT)" --all --format=plain --progress
else
	$(MKDIR_P) $(TEST_OUTPUT_DIR)
	$(LAZBUILD) --build-mode=Debug-Linux64 $(TEST_PROJECT_DIR)/$(TEST_PROJECT_NAME).lpi
	$(TEST_OUTPUT_DIR)/$(TEST_PROJECT_NAME)$(EXE_EXT) --all --format=plain --progress
endif
	@echo "Unit tests completed!"

# Help target
help:
	@echo "TWX Proxy Lazarus Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  all      - Build all projects (default)"
	@echo "  capedit  - Build CapEdit application"
	@echo "  twxp     - Build TWXP main application"
	@echo "  twxproxy - Build TWXProxy server application"
	@echo "  debug    - Build in debug mode"
	@echo "  test     - Build and run unit tests"
	@echo "  clean    - Clean build artifacts"
	@echo "  install  - Install built executables (placeholder)"
	@echo "  info     - Show build information"
	@echo "  help     - Show this help message"
	@echo ""
	@echo "Usage:"
	@echo "  make         # Build everything"
	@echo "  make capedit # Build just CapEdit"
	@echo "  make test    # Run unit tests"
	@echo "  make clean   # Clean build files"
	@echo "  make debug   # Debug build"