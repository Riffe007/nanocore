# NanoCore VM Windows Installer
# Installs NanoCore VM system-wide for easy command-line access

param(
    [string]$InstallDir = "$env:ProgramFiles\NanoCore",
    [switch]$UserInstall,
    [switch]$Force,
    [switch]$Verbose
)

# Script configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Version = "1.0.0"
$ProductName = "NanoCore VM"

# Colors for output
$Colors = @{
    Info = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
}

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Colors[$Color]
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-NanoCore {
    Write-ColorOutput "🚀 Installing $ProductName v$Version" "Info"
    Write-ColorOutput "=====================================" "Info"
    
    # Check if running as administrator (unless user install)
    if (-not $UserInstall -and -not (Test-Administrator)) {
        Write-ColorOutput "Error: This installer requires administrator privileges for system-wide installation." "Error"
        Write-ColorOutput "Use -UserInstall for user-specific installation, or run as administrator." "Error"
        exit 1
    }
    
    # Set installation directory
    if ($UserInstall) {
        $InstallDir = "$env:USERPROFILE\AppData\Local\NanoCore"
    }
    
    Write-ColorOutput "Installation directory: $InstallDir" "Info"
    
    # Create installation directory
    if (-not (Test-Path $InstallDir)) {
        Write-ColorOutput "Creating installation directory..." "Info"
        New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    }
    
    # Build NanoCore VM
    Write-ColorOutput "Building NanoCore VM..." "Info"
    $buildScript = Join-Path $ScriptDir "build.ps1"
    
    if (Test-Path $buildScript) {
        $buildArgs = @("-Release")
        if ($Verbose) { $buildArgs += "-Verbose" }
        
        & powershell -ExecutionPolicy Bypass -File $buildScript @buildArgs
        
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "Build failed. Please check the build output." "Error"
            exit 1
        }
    } else {
        Write-ColorOutput "Build script not found. Please run this from the NanoCore source directory." "Error"
        exit 1
    }
    
    # Copy files to installation directory
    Write-ColorOutput "Installing files..." "Info"
    
    $buildDir = Join-Path $ScriptDir "build"
    $binDir = Join-Path $buildDir "bin"
    $libDir = Join-Path $buildDir "lib"
    
    # Create subdirectories
    $installBinDir = Join-Path $InstallDir "bin"
    $installLibDir = Join-Path $InstallDir "lib"
    $installIncludeDir = Join-Path $InstallDir "include"
    $installExamplesDir = Join-Path $InstallDir "examples"
    
    New-Item -ItemType Directory -Force -Path $installBinDir | Out-Null
    New-Item -ItemType Directory -Force -Path $installLibDir | Out-Null
    New-Item -ItemType Directory -Force -Path $installIncludeDir | Out-Null
    New-Item -ItemType Directory -Force -Path $installExamplesDir | Out-Null
    
    # Copy binaries
    if (Test-Path $binDir) {
        Copy-Item -Path "$binDir\*" -Destination $installBinDir -Force -Recurse
    }
    
    # Copy libraries
    if (Test-Path $libDir) {
        Copy-Item -Path "$libDir\*" -Destination $installLibDir -Force -Recurse
    }
    
    # Copy header files
    $includeFiles = @(
        "cli\main.c",
        "asm\core\*.asm"
    )
    
    foreach ($file in $includeFiles) {
        $sourcePath = Join-Path $ScriptDir $file
        if (Test-Path $sourcePath) {
            Copy-Item -Path $sourcePath -Destination $installIncludeDir -Force -Recurse
        }
    }
    
    # Copy examples
    $exampleDirs = @("asm\labs", "glue\python\examples")
    foreach ($dir in $exampleDirs) {
        $sourcePath = Join-Path $ScriptDir $dir
        if (Test-Path $sourcePath) {
            $destPath = Join-Path $installExamplesDir (Split-Path $dir -Leaf)
            Copy-Item -Path $sourcePath -Destination $destPath -Force -Recurse
        }
    }
    
    # Create nanocore command-line wrapper
    $nanocoreCmd = @"
@echo off
REM NanoCore VM Command Line Interface
REM Version $Version

set NANOCORE_DIR=$InstallDir
set PATH=%NANOCORE_DIR%\bin;%PATH%

if "%1"=="" (
    echo NanoCore VM v$Version
    echo Usage: nanocore [options] [program.bin]
    echo.
    echo Options:
    echo   -h, --help     Show this help message
    echo   -v, --version  Show version information
    echo   -d, --debug    Enable debug mode
    echo   -p, --profile  Enable profiling
    echo.
    echo Examples:
    echo   nanocore program.bin
    echo   nanocore -d program.bin
    echo   nanocore --help
    exit /b 0
)

if "%1"=="-h" goto help
if "%1"=="--help" goto help
if "%1"=="-v" goto version
if "%1"=="--version" goto version

REM Run the actual VM
"%NANOCORE_DIR%\bin\nanocore-cli.exe" %*

goto end

:help
echo NanoCore VM v$Version
echo.
echo Usage: nanocore [options] [program.bin]
echo.
echo Options:
echo   -h, --help     Show this help message
echo   -v, --version  Show version information
echo   -d, --debug    Enable debug mode
echo   -p, --profile  Enable profiling
echo.
echo Examples:
echo   nanocore program.bin
echo   nanocore -d program.bin
echo   nanocore --help
goto end

:version
echo NanoCore VM v$Version
echo Ultra-high-performance virtual machine
echo Built with expert-level assembly optimization
goto end

:end
"@
    
    $nanocoreCmdPath = Join-Path $installBinDir "nanocore.cmd"
    $nanocoreCmd | Out-File -FilePath $nanocoreCmdPath -Encoding ASCII
    
    # Create PowerShell wrapper
    $nanocorePSCmd = @"
# NanoCore VM PowerShell Interface
# Version $Version

param(
    [Parameter(Position=0)]
    [string]`$ProgramFile,
    
    [switch]`$Debug,
    [switch]`$Profile,
    [switch]`$Help,
    [switch]`$Version
)

`$NANOCORE_DIR = "$InstallDir"
`$env:PATH = "`$NANOCORE_DIR\bin;`$env:PATH"

if (`$Help) {
    Write-Host "NanoCore VM v$Version" -ForegroundColor Green
    Write-Host ""
    Write-Host "Usage: nanocore [options] [program.bin]" -ForegroundColor White
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  -h, --help     Show this help message" -ForegroundColor White
    Write-Host "  -v, --version  Show version information" -ForegroundColor White
    Write-Host "  -d, --debug    Enable debug mode" -ForegroundColor White
    Write-Host "  -p, --profile  Enable profiling" -ForegroundColor White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  nanocore program.bin" -ForegroundColor White
    Write-Host "  nanocore -d program.bin" -ForegroundColor White
    Write-Host "  nanocore --help" -ForegroundColor White
    return
}

if (`$Version) {
    Write-Host "NanoCore VM v$Version" -ForegroundColor Green
    Write-Host "Ultra-high-performance virtual machine" -ForegroundColor Cyan
    Write-Host "Built with expert-level assembly optimization" -ForegroundColor Cyan
    return
}

if (-not `$ProgramFile) {
    Write-Host "NanoCore VM v$Version" -ForegroundColor Green
    Write-Host "Usage: nanocore [options] [program.bin]" -ForegroundColor White
    Write-Host "Use -h for help" -ForegroundColor Yellow
    return
}

# Build arguments for the CLI
`$args = @()
if (`$Debug) { `$args += "-d" }
if (`$Profile) { `$args += "-p" }
`$args += `$ProgramFile

# Run the actual VM
& "`$NANOCORE_DIR\bin\nanocore-cli.exe" @args
"@
    
    $nanocorePSPath = Join-Path $installBinDir "nanocore.ps1"
    $nanocorePSCmd | Out-File -FilePath $nanocorePSPath -Encoding UTF8
    
    # Create uninstaller
    $uninstaller = @"
# NanoCore VM Uninstaller
# Version $Version

param([switch]`$Force)

`$InstallDir = "$InstallDir"

if (-not (Test-Path `$InstallDir)) {
    Write-Host "NanoCore VM is not installed at: `$InstallDir" -ForegroundColor Yellow
    exit 0
}

Write-Host "Uninstalling NanoCore VM..." -ForegroundColor Yellow

if (`$Force -or (Read-Host "Are you sure you want to uninstall NanoCore VM? (y/N)") -eq "y") {
    Remove-Item -Path `$InstallDir -Recurse -Force
    Write-Host "NanoCore VM has been uninstalled." -ForegroundColor Green
} else {
    Write-Host "Uninstallation cancelled." -ForegroundColor Yellow
}
"@
    
    $uninstallerPath = Join-Path $InstallDir "uninstall.ps1"
    $uninstaller | Out-File -FilePath $uninstallerPath -Encoding UTF8
    
    # Add to PATH (system-wide or user-specific)
    if (-not $UserInstall) {
        Write-ColorOutput "Adding to system PATH..." "Info"
        $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
        if ($currentPath -notlike "*$installBinDir*") {
            $newPath = "$currentPath;$installBinDir"
            [Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")
        }
    } else {
        Write-ColorOutput "Adding to user PATH..." "Info"
        $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
        if ($currentPath -notlike "*$installBinDir*") {
            $newPath = "$currentPath;$installBinDir"
            [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
        }
    }
    
    # Create version file
    $versionInfo = @{
        Version = $Version
        InstallDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        InstallDir = $InstallDir
        UserInstall = $UserInstall
    }
    
    $versionPath = Join-Path $InstallDir "version.json"
    $versionInfo | ConvertTo-Json | Out-File -FilePath $versionPath -Encoding UTF8
    
    Write-ColorOutput ""
    Write-ColorOutput "✅ NanoCore VM v$Version installed successfully!" "Success"
    Write-ColorOutput ""
    Write-ColorOutput "Installation directory: $InstallDir" "Info"
    Write-ColorOutput "Binaries: $installBinDir" "Info"
    Write-ColorOutput "Libraries: $installLibDir" "Info"
    Write-ColorOutput "Examples: $installExamplesDir" "Info"
    Write-ColorOutput ""
    Write-ColorOutput "Usage:" "Info"
    Write-ColorOutput "  nanocore program.bin" "White"
    Write-ColorOutput "  nanocore -h" "White"
    Write-ColorOutput ""
    Write-ColorOutput "To uninstall, run: $uninstallerPath" "Warning"
}

# Main execution
Install-NanoCore 