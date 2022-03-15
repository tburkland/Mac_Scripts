#!/bin/bash
#   Update Chrome
#   This script should be used to install the latest
#   version of Google Chrome.app for macOS.
#
#   This was designed to be deployed via JSS.  
#
# set -x
#######################################################################
# Variables
#######################################################################
appDir="/Applications"
appName="Google Chrome.app"
app="$appDir/$appName"
currentUser=$(stat -f%Su /dev/console)
tempDmg="/tmp/Chrome.dmg"
#chromeUrl="${4}"
newVersion="${5}"
chromeUrl="https://dl.google.com/chrome/mac/stable/GGRO/googlechrome.dmg"
newVersion_int=$(echo "$newVersion" | tr -d '.')
######################################################################
# Functions
######################################################################
CheckVersion() {
    currentVersion=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$1"/Contents/Info.plist)
    echo "CheckVersion: Version is $currentVersion"
    # Convert currentVersion string to integar
    currentVersion_int=$(echo "$currentVersion" | tr -d '.')
    if [ "$currentVersion_int" != "$newVersion_int" ]; then
        return 1
    else
        return 0
    fi
}

DownloadDmg() {
    curl -so "$tempDmg" "$chromeUrl" 
    if [ ! -f "$tempDmg" ]; then
        return 1
    else
        return 0
    fi
}

InstallApp() {
    # Mount the DMG 
    hdiutil attach "$tempDmg"
    if [ "$?" != 0 ]; then
        echo "Mounting DMG Failed."
        return 1
    fi

    # Copy the .app from the DMG to the Applications folder
    cp -Rf /Volumes/"Google Chrome"/"$appName" "$appDir"
    if [ ! -d "$app" ]; then
        echo "Failed to copy $appName to $appDir"
        return 1
    fi
    echo "Successfully copied $appName to $appDir"
    return 0
}

CleanUp() {
    diskutil unmount "$(echo "$appName" | cut -d "." -f1)"
    rm -rf "$tempDmg"
}

UserPrompt() {
    userResponse=$(osascript -e 'tell application "System Events"' -e 'activate' -e 'with timeout of 600 seconds' -e 'set userResponse to button returned of (display dialog "There have been 3 attempts to upgrade Slack.  Slack will upgrade now." buttons {"Restart Chrome..."} default button 1 giving up after 300 with title "Slack App Upgrade" with icon file)' -e 'end tell')
    echo "$userResponse"
}

ExitScript() {
    # $1 is the string to echo
    # $2 is the exit code
    CleanUp
    echo "$1"
    exit "$2"
}

######################################################################
# Running Logic
######################################################################
# Check if Google Chrome.app is installed in the Applications Directory
if [ ! -d "$app" ]; then
    echo "Google Chrome not installed."
fi

# Check the version of the installed app
CheckVersion "$app"
if [ "$?" = 0 ]; then
    ExitScript "Current version installed is the latest version." "0"
fi    

echo "The currently installed version is old and needs to be upgraded."
DownloadDmg
if [ "$?" = 1 ]; then
    ExitScript "DownloadDmg: Failed to download the DMG" "1"
fi

InstallApp
if [ "$?" = 1 ]; then
    ExitScript "Failed to Install $appName" "1"
fi

CheckVersion "$app"
if [ "$?" = 0 ]; then
    ExitScript "Current version installed is the latest version." "0"
else
    ExitScript "Failed to upgrade $appName." "1"
fi