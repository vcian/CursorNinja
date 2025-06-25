# 🚀 Cursor Ninja

A cross-platform installation and update script for **Cursor AI IDE** that automatically detects your operating system and downloads the latest version.

## 📋 Installation Steps

### Quick Installation

1. **Download the script:**
   ```bash
   curl -O https://raw.githubusercontent.com/vcian/CursorNinja/main/cursor_ninja.sh
   ```

2. **Make it executable:**
   ```bash
   chmod +x cursor_ninja.sh
   ```

3. **Run the installer:**
   ```bash
   ./cursor_ninja.sh
   ```

### Platform-Specific Notes

**🐧 Linux:** 
- Installs as AppImage in `~/.local/bin/cursor.appimage`
- Creates CLI launcher at `/usr/local/bin/cursor`
- Sets up desktop integration

**🍎 macOS:** 
- Downloads and installs DMG to `/Applications/`
- Creates optional CLI launcher

**🪟 Windows:** 
- Downloads MSI installer
- Runs installation wizard

### Usage

After installation, launch Cursor by:
- Running `cursor` in terminal
- Using your application menu
- From Applications folder (macOS) or Start Menu (Windows) 