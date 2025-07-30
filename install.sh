#!/bin/bash

# NanoCore VM Linux/macOS Installer
# Installs NanoCore VM system-wide for easy command-line access

set -e

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="1.0.0"
PRODUCT_NAME="NanoCore VM"

# Default installation directory
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    DEFAULT_INSTALL_DIR="/usr/local/nanocore"
    BASH_COMPLETION_DIR="/usr/local/etc/bash_completion.d"
else
    # Linux
    DEFAULT_INSTALL_DIR="/opt/nanocore"
    BASH_COMPLETION_DIR="/etc/bash_completion.d"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Parse command line arguments
INSTALL_DIR="$DEFAULT_INSTALL_DIR"
USER_INSTALL=false
FORCE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --user)
            USER_INSTALL=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            echo "NanoCore VM Installer v$VERSION"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --install-dir DIR    Installation directory (default: $DEFAULT_INSTALL_DIR)"
            echo "  --user               User-specific installation"
            echo "  --force              Force installation without confirmation"
            echo "  --verbose            Verbose output"
            echo "  -h, --help           Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                    # System-wide installation"
            echo "  $0 --user             # User-specific installation"
            echo "  $0 --install-dir ~/nanocore"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h for help"
            exit 1
            ;;
    esac
done

# Function to print colored output
print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check dependencies
check_dependencies() {
    print_info "Checking dependencies..."
    
    local missing_deps=()
    
    # Check for NASM
    if ! command -v nasm &> /dev/null; then
        missing_deps+=("NASM (Netwide Assembler)")
    fi
    
    # Check for GCC/Clang
    if ! command -v gcc &> /dev/null && ! command -v clang &> /dev/null; then
        missing_deps+=("GCC or Clang compiler")
    fi
    
    # Check for Make
    if ! command -v make &> /dev/null; then
        missing_deps+=("Make")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        echo ""
        print_warning "Please install the missing dependencies:"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "  brew install nasm gcc make"
        else
            echo "  sudo apt-get install nasm gcc make  # Ubuntu/Debian"
            echo "  sudo yum install nasm gcc make      # CentOS/RHEL"
        fi
        exit 1
    fi
    
    print_success "All dependencies found!"
}

# Function to install NanoCore
install_nanocore() {
    print_info "🚀 Installing $PRODUCT_NAME v$VERSION"
    echo "====================================="
    
    # Set installation directory for user install
    if [[ "$USER_INSTALL" == true ]]; then
        INSTALL_DIR="$HOME/.local/nanocore"
        BASH_COMPLETION_DIR="$HOME/.local/share/bash-completion/completions"
    fi
    
    print_info "Installation directory: $INSTALL_DIR"
    
    # Check if already installed
    if [[ -d "$INSTALL_DIR" && "$FORCE" != true ]]; then
        print_warning "NanoCore VM is already installed at: $INSTALL_DIR"
        read -p "Do you want to overwrite it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Installation cancelled."
            exit 0
        fi
    fi
    
    # Check root permissions for system-wide install
    if [[ "$USER_INSTALL" != true && ! $(check_root) ]]; then
        print_error "System-wide installation requires root privileges."
        print_info "Use --user for user-specific installation, or run with sudo."
        exit 1
    fi
    
    # Create installation directory
    print_info "Creating installation directory..."
    mkdir -p "$INSTALL_DIR"
    
    # Build NanoCore VM
    print_info "Building NanoCore VM..."
    cd "$SCRIPT_DIR"
    
    if [[ -f "Makefile" ]]; then
        if [[ "$VERBOSE" == true ]]; then
            make clean && make all
        else
            make clean > /dev/null 2>&1 && make all > /dev/null 2>&1
        fi
    else
        print_error "Makefile not found. Please run this from the NanoCore source directory."
        exit 1
    fi
    
    # Create subdirectories
    local install_bin_dir="$INSTALL_DIR/bin"
    local install_lib_dir="$INSTALL_DIR/lib"
    local install_include_dir="$INSTALL_DIR/include"
    local install_examples_dir="$INSTALL_DIR/examples"
    
    mkdir -p "$install_bin_dir" "$install_lib_dir" "$install_include_dir" "$install_examples_dir"
    
    # Copy binaries
    if [[ -d "build/bin" ]]; then
        cp -r build/bin/* "$install_bin_dir/"
    fi
    
    # Copy libraries
    if [[ -d "build/lib" ]]; then
        cp -r build/lib/* "$install_lib_dir/"
    fi
    
    # Copy header files
    if [[ -f "cli/main.c" ]]; then
        cp cli/main.c "$install_include_dir/"
    fi
    
    if [[ -d "asm/core" ]]; then
        cp asm/core/*.asm "$install_include_dir/"
    fi
    
    # Copy examples
    if [[ -d "asm/labs" ]]; then
        cp -r asm/labs "$install_examples_dir/"
    fi
    
    if [[ -d "glue/python/examples" ]]; then
        cp -r glue/python/examples "$install_examples_dir/"
    fi
    
    # Create nanocore command-line wrapper
    cat > "$install_bin_dir/nanocore" << 'EOF'
#!/bin/bash

# NanoCore VM Command Line Interface
# Version 1.0.0

NANOCORE_DIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
export PATH="$NANOCORE_DIR/bin:$PATH"

# Function to show help
show_help() {
    echo "NanoCore VM v1.0.0"
    echo ""
    echo "Usage: nanocore [options] [program.bin]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --version  Show version information"
    echo "  -d, --debug    Enable debug mode"
    echo "  -p, --profile  Enable profiling"
    echo ""
    echo "Examples:"
    echo "  nanocore program.bin"
    echo "  nanocore -d program.bin"
    echo "  nanocore --help"
}

# Function to show version
show_version() {
    echo "NanoCore VM v1.0.0"
    echo "Ultra-high-performance virtual machine"
    echo "Built with expert-level assembly optimization"
}

# Parse arguments
case "$1" in
    -h|--help)
        show_help
        exit 0
        ;;
    -v|--version)
        show_version
        exit 0
        ;;
    "")
        show_help
        exit 0
        ;;
    *)
        # Run the actual VM
        exec "$NANOCORE_DIR/bin/nanocore-cli" "$@"
        ;;
esac
EOF
    
    # Make nanocore executable
    chmod +x "$install_bin_dir/nanocore"
    
    # Create bash completion
    mkdir -p "$BASH_COMPLETION_DIR"
    cat > "$BASH_COMPLETION_DIR/nanocore" << 'EOF'
# NanoCore VM bash completion

_nanocore() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    opts="-h --help -v --version -d --debug -p --profile"
    
    if [[ ${cur} == * ]] ; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
    fi
}

complete -F _nanocore nanocore
EOF
    
    # Create uninstaller
    cat > "$INSTALL_DIR/uninstall.sh" << EOF
#!/bin/bash

# NanoCore VM Uninstaller
# Version $VERSION

INSTALL_DIR="$INSTALL_DIR"
BASH_COMPLETION_DIR="$BASH_COMPLETION_DIR"

if [[ ! -d "\$INSTALL_DIR" ]]; then
    echo "NanoCore VM is not installed at: \$INSTALL_DIR"
    exit 0
fi

echo "Uninstalling NanoCore VM..."

if [[ "\$1" == "--force" ]] || read -p "Are you sure you want to uninstall NanoCore VM? (y/N): " -n 1 -r && [[ \$REPLY =~ ^[Yy]$ ]]; then
    rm -rf "\$INSTALL_DIR"
    
    # Remove bash completion
    if [[ -f "\$BASH_COMPLETION_DIR/nanocore" ]]; then
        rm -f "\$BASH_COMPLETION_DIR/nanocore"
    fi
    
    echo "NanoCore VM has been uninstalled."
else
    echo "Uninstallation cancelled."
fi
EOF
    
    chmod +x "$INSTALL_DIR/uninstall.sh"
    
    # Add to PATH
    if [[ "$USER_INSTALL" == true ]]; then
        # User-specific PATH
        local shell_rc=""
        if [[ -f "$HOME/.bashrc" ]]; then
            shell_rc="$HOME/.bashrc"
        elif [[ -f "$HOME/.zshrc" ]]; then
            shell_rc="$HOME/.zshrc"
        fi
        
        if [[ -n "$shell_rc" ]]; then
            if ! grep -q "$install_bin_dir" "$shell_rc"; then
                echo "" >> "$shell_rc"
                echo "# NanoCore VM" >> "$shell_rc"
                echo "export PATH=\"$install_bin_dir:\$PATH\"" >> "$shell_rc"
                print_info "Added to PATH in $shell_rc"
            fi
        fi
    else
        # System-wide PATH
        if [[ -d "/etc/profile.d" ]]; then
            cat > "/etc/profile.d/nanocore.sh" << EOF
# NanoCore VM PATH
export PATH="$install_bin_dir:\$PATH"
EOF
            chmod +x "/etc/profile.d/nanocore.sh"
        fi
    fi
    
    # Create version file
    cat > "$INSTALL_DIR/version.json" << EOF
{
    "version": "$VERSION",
    "install_date": "$(date -u +"%Y-%m-%d %H:%M:%S")",
    "install_dir": "$INSTALL_DIR",
    "user_install": $USER_INSTALL
}
EOF
    
    print_success ""
    print_success "✅ NanoCore VM v$VERSION installed successfully!"
    print_success ""
    print_info "Installation directory: $INSTALL_DIR"
    print_info "Binaries: $install_bin_dir"
    print_info "Libraries: $install_lib_dir"
    print_info "Examples: $install_examples_dir"
    print_success ""
    print_info "Usage:"
    echo "  nanocore program.bin"
    echo "  nanocore -h"
    print_success ""
    
    if [[ "$USER_INSTALL" == true ]]; then
        print_warning "Please restart your terminal or run: source ~/.bashrc"
    fi
    
    print_warning "To uninstall, run: $INSTALL_DIR/uninstall.sh"
}

# Main execution
check_dependencies
install_nanocore 