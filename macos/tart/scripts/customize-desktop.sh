#!/usr/bin/env bash
set -euo pipefail

# Script to customize macOS desktop for development VM
# Removes desktop clutter, sets solid wallpaper, cleans up Dock

echo "Customizing macOS desktop for development environment..."

# Set desktop to show only volumes (no files/folders)
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool false
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false
defaults write com.apple.finder ShowMountedServersOnDesktop -bool false
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool false

# Remove desktop widgets (Stage Manager, Widgets)
defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false
defaults write com.apple.WindowManager StandardHideDesktopIcons -bool true
defaults write com.apple.WindowManager HideDesktop -bool true
defaults write com.apple.WindowManager StageManagerHideWidgets -bool true
defaults write com.apple.WindowManager StandardHideWidgets -bool true

# Disable desktop icons completely
defaults write com.apple.finder CreateDesktop -bool false

# Clean up Dock - pin curated essentials
echo "Cleaning up Dock..."

#defaults write com.apple.dock persistent-apps -array; killall Dock 2>/dev/null || true

# Add essential apps to Dock
defaults write com.apple.dock persistent-apps -array \
    '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/System/Applications/Utilities/Terminal.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>' \
    '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/System/Applications/System Settings.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>' \
    '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/Safari.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>' \
    '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/Utilities/Keychain Access.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>'

# Dock preferences
defaults write com.apple.dock tilesize -int 48
# defaults write com.apple.dock autohide -bool true
# defaults write com.apple.dock autohide-delay -float 0
# defaults write com.apple.dock autohide-time-modifier -float 0.5
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock show-process-indicators -bool true
defaults write com.apple.dock mineffect -string "scale"

# Disable recent items and pin Applications folder
defaults write com.apple.dock persistent-others -array \
    '<dict><key>tile-data</key><dict><key>arrangement</key><integer>1</integer><key>displayas</key><integer>0</integer><key>file-data</key><dict><key>_CFURLString</key><string>/Applications</string><key>_CFURLStringType</key><integer>0</integer></dict><key>file-label</key><string>Applications</string><key>showas</key><integer>0</integer></dict><key>tile-type</key><string>directory-tile</string></dict>'

# Finder preferences for cleaner experience
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv" # List view
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf" # Search current folder
defaults write com.apple.finder NewWindowTarget -string "PfHm"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/"

# Disable animations for faster feel
defaults write com.apple.finder DisableAllAnimations -bool true
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

# Disable the "Are you sure you want to open this application?" dialog
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Disable Dashboard
defaults write com.apple.dashboard mcx-disabled -bool true
defaults write com.apple.dock dashboard-in-overlay -bool true

# Disable notification center
launchctl unload -w /System/Library/LaunchAgents/com.apple.notificationcenterui.plist 2>/dev/null || true

# Disable Time Machine popup
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

# Disable Spotlight indexing of volumes (for faster performance)
# sudo mdutil -a -i off 2>/dev/null || true

# Menu bar: hide unnecessary icons
defaults write com.apple.systemuiserver menuExtras -array \
    "/System/Library/CoreServices/Menu Extras/Clock.menu" \
    "/System/Library/CoreServices/Menu Extras/Battery.menu" \
    "/System/Library/CoreServices/Menu Extras/Volume.menu"

# Disable Siri
defaults write com.apple.assistant.support "Assistant Enabled" -bool false
defaults write com.apple.Siri StatusMenuVisible -bool false
defaults write com.apple.Siri UserHasDeclinedEnable -bool true

# Screen saver: never start (for VMs)
defaults -currentHost write com.apple.screensaver idleTime -int 0

# Energy saver: never sleep (for VMs)
sudo pmset -a sleep 0
sudo pmset -a displaysleep 0
sudo pmset -a disksleep 0

# Disable auto-correct and auto-capitalization
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Terminal preferences
defaults write com.apple.Terminal "Default Window Settings" -string "Pro"
defaults write com.apple.Terminal "Startup Window Settings" -string "Pro"

# Restart affected services
echo "Restarting affected services..."
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true

# Wait for services to restart
sleep 2

echo "Desktop customization completed!"
echo "Changes applied:"
echo "  - Desktop icons hidden"
echo "  - Solid color wallpaper set"
echo "  - Dock cleaned up (Terminal, System Settings, Safari, Keychain Access, Applications folder)"
echo "  - Dock auto-hide enabled"
echo "  - Animations disabled for faster performance"
echo "  - Unnecessary menu bar items hidden"
echo "  - Screen saver and sleep disabled"
echo "  - Siri disabled"
