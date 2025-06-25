#!/bin/bash
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Base URLs and version info
BASE_API_URL="https://downloads.cursor.com/production"
ICON_URL="https://us1.discourse-cdn.com/flex020/uploads/cursor1/original/2X/a/a4f78589d63edd61a2843306f8e11bad9590f0ca.png"

# Function to detect OS and architecture
detect_platform() {
    local os_type
    local arch_type
    
    # Detect OS
    case "$(uname -s)" in
        Linux*)     os_type="linux" ;;
        Darwin*)    os_type="darwin" ;;
        CYGWIN*|MINGW*|MSYS*) os_type="windows" ;;
        *)          echo -e "${RED}❌ Unsupported operating system: $(uname -s)${NC}" && exit 1 ;;
    esac
    
    # Detect architecture
    case "$(uname -m)" in
        x86_64|amd64)   arch_type="x64" ;;
        arm64|aarch64)  arch_type="arm64" ;;
        *)              echo -e "${RED}❌ Unsupported architecture: $(uname -m)${NC}" && exit 1 ;;
    esac
    
    echo "$os_type:$arch_type"
}

# Function to get latest version and construct download URL
get_download_url() {
    local platform="$1"
    local os_type="${platform%:*}"
    local arch_type="${platform#*:}"
    
    echo -e "${BLUE}🔍 Getting latest download URL from Cursor API...${NC}" >&2
    
    # Map our platform names to Cursor's API format
    local api_platform
    case "$os_type" in
        "linux")
            api_platform="linux-${arch_type}"
            ;;
        "darwin")
            if [ "$arch_type" = "arm64" ]; then
                api_platform="mac-arm64"
            else
                api_platform="mac-x64"
            fi
            ;;
        "windows")
            api_platform="windows-${arch_type}"
            ;;
    esac
    
    # Use Cursor's official API to get the download URL
    local api_url="https://www.cursor.com/api/download?platform=${api_platform}&releaseTrack=stable"
    local download_url
    
    echo -e "${BLUE}📡 Fetching from: ${api_url}${NC}" >&2
    
    # Get download URL from Cursor's API
    download_url=$(curl -s "$api_url" | grep -o '"downloadUrl":"[^"]*"' | sed 's/"downloadUrl":"\([^"]*\)"/\1/' 2>/dev/null)
    
    # Fallback method if API fails
    if [ -z "$download_url" ]; then
        echo -e "${YELLOW}⚠️  API failed, trying fallback method...${NC}" >&2
        
        # Alternative API endpoint found in research
        case "$os_type" in
            "linux")
                download_url="https://downloader.cursor.sh/linux/appImage/${arch_type}"
                ;;
            "darwin")
                if [ "$arch_type" = "arm64" ]; then
                    download_url="https://downloader.cursor.sh/mac/dmg/arm64"
                else
                    download_url="https://downloader.cursor.sh/mac/dmg/x64"
                fi
                ;;
            "windows")
                download_url="https://downloader.cursor.sh/windows/nsis/${arch_type}"
                ;;
        esac
    fi
    
    # Final fallback - use the official download page redirect
    if [ -z "$download_url" ]; then
        echo -e "${YELLOW}⚠️  All APIs failed, using download page redirect...${NC}" >&2
        case "$os_type" in
            "linux")
                download_url="https://www.cursor.com/api/download?platform=linux-${arch_type}"
                ;;
            "darwin")
                download_url="https://www.cursor.com/api/download?platform=mac-${arch_type}"
                ;;
            "windows")
                download_url="https://www.cursor.com/api/download?platform=windows-${arch_type}"
                ;;
        esac
    fi
    
    echo "$download_url"
}

# Linux installation function
install_linux() {
    local download_url="$1"
    local appimg="$HOME/.local/bin/cursor.appimage"
    local icon="$HOME/.local/share/icons/cursor.png"
    local desktop="$HOME/.local/share/applications/cursor.desktop"
    local bin_link="/usr/local/bin/cursor"
    
    # Ensure directories
    mkdir -p "$(dirname "$appimg")" "$(dirname "$icon")" "$(dirname "$desktop")"
    
    # Check if Cursor is currently running and stop it
    if [ -f "$appimg" ]; then
        echo -e "${YELLOW}📋 Existing Cursor installation found...${NC}"
        
        # Check if cursor is running
        if pgrep -f "cursor\.appimage\|Cursor.*AppImage" >/dev/null 2>&1; then
            echo -e "${YELLOW}⚠️  Cursor is currently running. Attempting to close it...${NC}"
            
            # Try graceful shutdown first
            pkill -TERM -f "cursor\.appimage" 2>/dev/null || true
            pkill -TERM -f "Cursor.*AppImage" 2>/dev/null || true
            sleep 3
            
            # Force kill all cursor processes
            echo -e "${YELLOW}⚠️  Force closing all Cursor processes...${NC}"
            pkill -9 -f "cursor\.appimage" 2>/dev/null || true
            pkill -9 -f "Cursor.*AppImage" 2>/dev/null || true
            pkill -9 -f "\.mount_cursor" 2>/dev/null || true
            sleep 2
            
            # Wait for processes to fully terminate
            local wait_count=0
            while pgrep -f "cursor\.appimage\|Cursor.*AppImage" >/dev/null 2>&1 && [ $wait_count -lt 5 ]; do
                echo -e "${BLUE}⏳ Waiting for processes to terminate... ($((wait_count + 1))/5)${NC}"
                sleep 1
                wait_count=$((wait_count + 1))
            done
            
            # Final check with more specific pattern
            if pgrep -f "cursor\.appimage\|Cursor.*AppImage" >/dev/null 2>&1; then
                echo -e "${RED}❌ Unable to close Cursor completely. Please close it manually and try again.${NC}"
                echo -e "${YELLOW}💡 Try: pkill -9 -f cursor${NC}"
                exit 1
            fi
        fi
        
        echo -e "${GREEN}✅ All Cursor processes terminated successfully${NC}"
        
        # Create backup of existing file
        local backup_file="${appimg}.backup.$(date +%s)"
        echo -e "${BLUE}💾 Creating backup: $(basename "$backup_file")${NC}"
        cp "$appimg" "$backup_file" 2>/dev/null || true
        
        # Remove existing file
        rm -f "$appimg" 2>/dev/null || {
            echo -e "${RED}❌ Cannot remove existing file. Please close Cursor manually and try again.${NC}"
            exit 1
        }
    fi
    
    echo -e "${BLUE}⬇️  Downloading Cursor for Linux...${NC}"
    if ! curl -L -A "Mozilla/5.0" "$download_url" -o "$appimg"; then
        echo -e "${RED}❌ Download failed. Restoring backup if available...${NC}"
        local latest_backup=$(ls -t "${appimg}.backup."* 2>/dev/null | head -n1)
        if [ -n "$latest_backup" ]; then
            echo -e "${BLUE}🔄 Restoring from backup: $(basename "$latest_backup")${NC}"
            cp "$latest_backup" "$appimg" 2>/dev/null || true
        fi
        exit 1
    fi
    
    chmod +x "$appimg"
    
    # Install FUSE if needed
    if ! fusermount --version >/dev/null 2>&1; then
        echo -e "${YELLOW}📦 FUSE is required—installing...${NC}"
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y fuse libfuse2
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y fuse fuse-libs
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -S fuse2
        else
            echo -e "${YELLOW}⚠️  Please install FUSE manually for your distribution${NC}"
        fi
    fi
    
    # Create CLI launcher
    echo -e "${BLUE}🔗 Creating CLI launcher...${NC}"
    sudo ln -sf "$appimg" "$bin_link"
    
    # Download icon
    echo -e "${BLUE}🖼️  Downloading icon...${NC}"
    curl -L "$ICON_URL" -o "$icon"
    
    # Create desktop entry
    cat > "$desktop" <<EOF
[Desktop Entry]
Name=Cursor AI IDE
Exec=$appimg --no-sandbox
Icon=$icon
Type=Application
Categories=Development;IDE;
Terminal=false
EOF
    chmod +x "$desktop"
    update-desktop-database ~/.local/share/applications 2>/dev/null || true
    
    echo -e "${GREEN}✅ Linux installation complete! Run with 'cursor' from terminal or launch from your app menu.${NC}"
}

# macOS installation function
install_macos() {
    local download_url="$1"
    local dmg_file="/tmp/cursor.dmg"
    local mount_point="/tmp/cursor_mount"
    
    echo -e "${BLUE}⬇️  Downloading Cursor for macOS...${NC}"
    curl -L -A "Mozilla/5.0" "$download_url" -o "$dmg_file"
    
    echo -e "${BLUE}📦 Installing Cursor...${NC}"
    # Create mount point
    mkdir -p "$mount_point"
    
    # Mount DMG
    hdiutil attach "$dmg_file" -mountpoint "$mount_point" -quiet
    
    # Copy application to Applications folder
    cp -R "$mount_point"/*.app /Applications/
    
    # Unmount DMG
    hdiutil detach "$mount_point" -quiet
    
    # Cleanup
    rm -f "$dmg_file"
    rmdir "$mount_point"
    
    # Create CLI launcher
    echo -e "${BLUE}🔗 Creating CLI launcher...${NC}"
    sudo ln -sf "/Applications/Cursor.app/Contents/MacOS/Cursor" "/usr/local/bin/cursor" 2>/dev/null || true
    
    echo -e "${GREEN}✅ macOS installation complete! Launch from Applications or run 'cursor' from terminal.${NC}"
}

# Windows installation function
install_windows() {
    local download_url="$1"
    local msi_file="/tmp/cursor.msi"
    
    echo -e "${BLUE}⬇️  Downloading Cursor for Windows...${NC}"
    curl -L -A "Mozilla/5.0" "$download_url" -o "$msi_file"
    
    echo -e "${BLUE}📦 Installing Cursor...${NC}"
    echo -e "${YELLOW}ℹ️  Please run the downloaded MSI file manually: $msi_file${NC}"
    echo -e "${YELLOW}ℹ️  The installer will guide you through the installation process.${NC}"
    
    # Try to launch the installer
    if command -v msiexec >/dev/null 2>&1; then
        msiexec //i "$msi_file" //quiet
        echo -e "${GREEN}✅ Windows installation initiated! Check your Start menu for Cursor.${NC}"
    else
        echo -e "${YELLOW}⚠️  Please manually run: $msi_file${NC}"
    fi
}

# Main installation function
main() {
    echo -e "${BLUE}🚀 Cursor Ninja${NC}"
    echo -e "${BLUE}=======================================${NC}"
    
    # Detect platform
    local platform
    platform=$(detect_platform)
    local os_type="${platform%:*}"
    local arch_type="${platform#*:}"
    
    echo -e "${GREEN}✅ Detected platform: $os_type ($arch_type)${NC}"
    
    # Get download URL
    local download_url
    download_url=$(get_download_url "$platform")
    
    echo -e "${BLUE}📥 Download URL: $download_url${NC}"
    
    # Check if URL is accessible
    if ! curl -s --head "$download_url" | head -n 1 | grep -q "200 OK"; then
        echo -e "${YELLOW}⚠️  Warning: Could not verify download URL. Proceeding anyway...${NC}"
    fi
    
    # Install based on platform
    case "$os_type" in
        "linux")
            install_linux "$download_url"
            ;;
        "darwin")
            install_macos "$download_url"
            ;;
        "windows")
            install_windows "$download_url"
            ;;
        *)
            echo -e "${RED}❌ Unsupported platform: $os_type${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}🎉 Installation completed successfully!${NC}"
}

# Run main function
main "$@" 