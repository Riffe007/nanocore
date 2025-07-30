# NanoCore Windows Build Script
# PowerShell-based build system for Windows

param(
    [string]$Platform = "win64",
    [string]$Arch = "x64",
    [string]$CC = "cl",
    [string]$AS = "nasm",
    [switch]$Clean,
    [switch]$Release,
    [switch]$Debug,
    [switch]$Verbose
)

# Build Configuration
$BuildDir = "build"
$ObjDir = "$BuildDir\obj"
$BinDir = "$BuildDir\bin"
$LibDir = "$BuildDir\lib"

# Source Directories
$AsmCoreDir = "asm\core"
$AsmDevicesDir = "asm\devices"
$AsmLabsDir = "asm\labs"
$GlueDir = "glue"
$CliDir = "cli"
$TestDir = "tests"

# Compiler Flags
$CFLAGS = @(
    "/O2",                    # Optimize for speed
    "/arch:AVX2",            # Enable AVX2 instructions
    "/MT",                    # Multi-threaded static runtime
    "/W3",                    # Warning level 3
    "/D_CRT_SECURE_NO_WARNINGS",  # Disable security warnings
    "/DWIN32_LEAN_AND_MEAN", # Exclude rarely used headers
    "/DNOMINMAX"             # Don't define min/max macros
)

if ($Debug) {
    $CFLAGS = @("/Od", "/Zi", "/MTd", "/W3", "/D_CRT_SECURE_NO_WARNINGS", "/DWIN32_LEAN_AND_MEAN", "/DNOMINMAX")
}

$ASFLAGS = @(
    "-f", "win64",           # Windows 64-bit format
    "-g",                    # Include debug info
    "-F", "cv8"              # CodeView debug format
)

$LDFLAGS = @(
    "/SUBSYSTEM:CONSOLE",    # Console subsystem
    "/MACHINE:X64"           # 64-bit target
)

if ($Debug) {
    $LDFLAGS += "/DEBUG"
}

# Function to check if command exists
function Test-Command($cmdname) {
    return [bool](Get-Command $cmdname -ErrorAction SilentlyContinue)
}

# Function to create directories
function New-BuildDirectories {
    Write-Host "Creating build directories..." -ForegroundColor Green
    New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
    New-Item -ItemType Directory -Force -Path $ObjDir | Out-Null
    New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
    New-Item -ItemType Directory -Force -Path $LibDir | Out-Null
}

# Function to clean build artifacts
function Remove-BuildArtifacts {
    Write-Host "Cleaning build artifacts..." -ForegroundColor Yellow
    if (Test-Path $BuildDir) {
        Remove-Item -Recurse -Force $BuildDir
    }
}

# Function to check dependencies
function Test-Dependencies {
    Write-Host "Checking dependencies..." -ForegroundColor Green
    
    $missing = @()
    
    if (-not (Test-Command "nasm")) {
        $missing += "NASM (Netwide Assembler)"
    }
    
    if (-not (Test-Command "cl")) {
        $missing += "Microsoft Visual C++ Compiler (cl.exe)"
    }
    
    if (-not (Test-Command "link")) {
        $missing += "Microsoft Linker (link.exe)"
    }
    
    if ($missing.Count -gt 0) {
        Write-Host "Missing dependencies:" -ForegroundColor Red
        foreach ($dep in $missing) {
            Write-Host "  - $dep" -ForegroundColor Red
        }
        Write-Host ""
        Write-Host "Please install the missing dependencies:" -ForegroundColor Yellow
        Write-Host "1. NASM: Download from https://www.nasm.us/" -ForegroundColor Yellow
        Write-Host "2. Visual Studio Build Tools: Install from Microsoft" -ForegroundColor Yellow
        Write-Host "3. Add them to your PATH environment variable" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "All dependencies found!" -ForegroundColor Green
}

# Function to assemble NASM files
function Invoke-Assemble {
    param([string]$SourceFile, [string]$OutputFile)
    
    $sourcePath = $SourceFile
    $outputPath = $OutputFile
    
    Write-Host "Assembling $SourceFile..." -ForegroundColor Cyan
    
    $args = @($ASFLAGS) + @("-o", $outputPath, $sourcePath)
    
    if ($Verbose) {
        Write-Host "Running: nasm $($args -join ' ')" -ForegroundColor Gray
    }
    
    $result = & nasm $args 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Assembly failed for $($SourceFile):" -ForegroundColor Red
        Write-Host $result -ForegroundColor Red
        exit 1
    }
    
    if ($Verbose) {
        Write-Host "Successfully assembled $SourceFile" -ForegroundColor Green
    }
}

# Function to compile C files
function Invoke-Compile {
    param([string]$SourceFile, [string]$OutputFile)
    
    Write-Host "Compiling $SourceFile..." -ForegroundColor Cyan
    
    $args = @($CFLAGS) + @("/c", "/Fo$OutputFile", $SourceFile)
    
    if ($Verbose) {
        Write-Host "Running: cl $($args -join ' ')" -ForegroundColor Gray
    }
    
    $result = & cl $args 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Compilation failed for $($SourceFile):" -ForegroundColor Red
        Write-Host $result -ForegroundColor Red
        exit 1
    }
    
    if ($Verbose) {
        Write-Host "Successfully compiled $SourceFile" -ForegroundColor Green
    }
}

# Function to link objects
function Invoke-Link {
    param([string]$OutputFile, [string[]]$ObjectFiles, [string[]]$Libraries = @())
    
    Write-Host "Linking $OutputFile..." -ForegroundColor Cyan
    
    $args = @($LDFLAGS) + @("/OUT:$OutputFile") + $ObjectFiles + $Libraries
    
    if ($Verbose) {
        Write-Host "Running: link $($args -join ' ')" -ForegroundColor Gray
    }
    
    $result = & link $args 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Linking failed:" -ForegroundColor Red
        Write-Host $result -ForegroundColor Red
        exit 1
    }
    
    if ($Verbose) {
        Write-Host "Successfully linked $OutputFile" -ForegroundColor Green
    }
}

# Main build process
function Start-Build {
    Write-Host "🚀 Building NanoCore VM for Windows" -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Green
    
    # Check dependencies
    Test-Dependencies
    
    # Create directories
    New-BuildDirectories
    
    # Core VM objects
    $vmObjects = @()
    
    # Assemble core VM files
    $coreFiles = @(
        "vm.asm",
        "memory.asm", 
        "alu.asm",
        "pipeline.asm",
        "cache.asm",
        "interrupts.asm",
        "instructions.asm",
        "devices.asm"
    )
    
    foreach ($file in $coreFiles) {
        $sourceFile = "$AsmCoreDir\$file"
        $outputFile = "$ObjDir\$($file -replace '\.asm$', '.obj')"
        
        if (Test-Path $sourceFile) {
            Invoke-Assemble $sourceFile $outputFile
            $vmObjects += $outputFile
        } else {
            Write-Host "Warning: $sourceFile not found, skipping..." -ForegroundColor Yellow
        }
    }
    
    # Assemble device files
    $deviceFiles = @("console.asm")
    foreach ($file in $deviceFiles) {
        $sourceFile = "$AsmDevicesDir\$file"
        $outputFile = "$ObjDir\$($file -replace '\.asm$', '.obj')"
        
        if (Test-Path $sourceFile) {
            Invoke-Assemble $sourceFile $outputFile
            $vmObjects += $outputFile
        }
    }
    
    # Build shared library
    if ($vmObjects.Count -gt 0) {
        Write-Host "Building shared library..." -ForegroundColor Green
        Invoke-Link "$LibDir\nanocore.dll" $vmObjects @("/DLL")
        
        # Also build static library
        Write-Host "Building static library..." -ForegroundColor Green
        & lib "/OUT:$LibDir\nanocore.lib" $vmObjects
    }
    
    # Build CLI tool
    if (Test-Path "$CliDir\main.c") {
        Write-Host "Building CLI tool..." -ForegroundColor Green
        $cliObj = "$ObjDir\main.obj"
        Invoke-Compile "$CliDir\main.c" $cliObj
        Invoke-Link "$BinDir\nanocore-cli.exe" @($cliObj) @("$LibDir\nanocore.lib")
    }
    
    Write-Host ""
    Write-Host "✅ Build completed successfully!" -ForegroundColor Green
    Write-Host "Binaries available in: $BinDir" -ForegroundColor Cyan
    Write-Host "Libraries available in: $LibDir" -ForegroundColor Cyan
}

# Main execution
if ($Clean) {
    Remove-BuildArtifacts
}

Start-Build 