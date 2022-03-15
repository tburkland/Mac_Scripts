#!/bin/bash
#   Install Slack
#   This script should be used to install the latest
#   version of Slack.app for macOS.
#
#   This was designed to be deployed via JSS.  
#
#

####################################################
# Variables
####################################################
appDir="/Applications"
currentUser=$(stat -f%Su /dev/console)
# This variable must be entered on the Policy page under the Script Parameters
slackUrl="${4}"
#slackUrl="https://downloads.slack-edge.com/mac_releases/Slack-2.9.0-macOS.zip"
counterFile="/Library/Scripts/Workday/slackCount.txt"

####################################################
# Functions
####################################################
CheckExistence() {
    # $1 = file or directory
    # $2 = name of directory
    # $3 = name of file
    if [ "$1" "$2" ]; then
        echo "CheckExistence: The file or directory $2 exists.  Moving on..."
        return 0
    else
        echo "CheckExistence: The file or directory $2 does not exist."
        return 1
    fi
}

ChangePermissions () {
    chmod -R 755 "$2"
    chown -R "$1":"WORKDAYINTERNAL\Domain Users" "$2"
    if [ "$?" != "0" ]; then
        echo "ChangePermissions: Failed to change permissions for $2"
        return 1
    else    
        echo "ChangePermissions: Successfully changed permissions for $2"
        return 0
    fi
}

CheckVersion() {
    # $1 = downloaded version of slack
    # $2 = installed version of slack, if it exists
    slackVersionDownload=$(cat "$1/Slack.app/Contents/Info.plist" | grep -A1 CFBundleShortVersionString | grep string | awk -F'>|<' '/<string>/{print $3}')
    
    slackVersionDownload_cleaned=$(echo "$slackVersionDownload" | sed 's/\.//g')
    slackVersionInstalled=$(cat "$2/Slack.app/Contents/Info.plist" | grep -A1 CFBundleShortVersionString | grep string | awk -F'>|<' '/<string>/{print $3}')
    
    slackVersionInstalled_cleaned=$(echo "$slackVersionInstalled" | sed 's/\.//g')
    echo "CheckVersion: Downloaded Slack Version: $slackVersionDownload - $slackVersionDownload_cleaned"
    echo "CheckVersion: Installed Slack Version: $slackVersionInstalled - $slackVersionInstalled_cleaned"
    if [[ "$slackVersionDownload_cleaned" -gt "$slackVersionInstalled_cleaned" ]]; then
        return 0
    else
        return 1
    fi
}

InstallSlack() {
    # Change all permissions for Slack.app
    ChangePermissions "$currentUser" "/tmp/Slack.app"
    if [ "$?" = "1" ]; then
        echo "InstallSlack: Failing to change permissions to $currentUser may cause issues in the future for upgrading."
        echo "InstallSlack: The system may not be bound to AD or the user may not be an AD user."
    fi
    sleep 1
    mv /tmp/Slack.app "$appDir"
}

SlackRunning() {
    slackPID=$(ps aux | grep "$currentUser" | grep "/Applications/Slack.app/Contents/MacOS/Slack" | awk '{print $2}')
    if [ "$slackPID" != "" ]; then
        echo "SlackRunning: Slack is running with PID: $slackPID"
        return 0
    else
        echo "SlackRunning: Slack is not running"
        return 1
    fi
}

CounterFile() {
    if [ ! -f "$counterFile" ]; then
        touch "$counterFile"
    fi

    promptCount=$(tail "$counterFile")
    if [ "$promptCount" = "" ]; then
        echo "1" > "$counterFile"
        return 1
    elif [ "$promptCount" = "3" ]; then
        return 0
    else
        a=$(($promptCount + 1))
        echo "$a" > "$counterFile"
        return 1
    fi 

}

PromptToClose() {
    if [ -f "$counterFile" ]; then
        CounterFile
        if [ "$?" = 0 ]; then
            osascript -e 'tell application "Slack"' -e 'display dialog "There have been 3 attempts to upgrade Slack.  Slack will upgrade now." buttons {"Upgrade..."} default button 1 giving up after 300 with title "Slack App Upgrade" with icon file "Library:Application Support:JAMF:bin:workday_w.png"' -e 'end tell'
            return 0
        fi
    fi

    prompt=$(osascript -e 'tell application "Slack"' -e 'set userPrompt to button returned of (display dialog "The version of Slack you have installed has been determined to be out of date.\nPlease click Upgrade in order to upgrade now.\n\nClicking Upgrade will quit Slack and it will reopen once upgraded.  You can skip this update up to 3 times." buttons {"Not Now", "Upgrade..."} default button 2 giving up after 300 with title "Slack App Upgrade" with icon file "Library:Application Support:JAMF:bin:workday_w.png")' -e 'end tell')
    if [ "$prompt" = "Not Now" ]; then
        CounterFile 
        if [ "$?" = 0 ]; then
            return 0
        else
            # Don't perform the upgrade at this time.
            return 1
        fi
    else
        return 0
    fi
    
}

CleanUp() {
    rm -rf /tmp/Slack.zip
    rm -rf /tmp/Slack.app
}

ExitScript() {
    # $1 is the string to echo
    # $2 is the exit code
    #CleanUp
    echo "$1"
    exit "$2"
}
####################################################
# Running Logic
####################################################
if [ -z "$slackUrl" ]; then
    ExitScript "The Slack Download URL was not added to the parameter page on the JSS Policy." "1"
fi
# Pull the slack app from Slack's download page
echo "Downloading Slack app from Slack's website..."
curl -so /tmp/Slack.zip "$slackUrl"

CheckExistence "-f" "/tmp/Slack.zip"
if [ "$?" = "1" ]; then
    ExitScript "Curl download of Slack app did not work. Attempted to pull from $slackUrl" "1"
fi

unzip -qo /tmp/Slack.zip -d /tmp/
CheckExistence "-d" "/tmp/Slack.app"
if [ "$?" != "0" ]; then
    echo "Unzip command did not work, trying ditto command"
    ditto -x -k /tmp/Slack.zip /tmp/
    CheckExistence "-d" "/tmp/Slack.app"
    if [ "$?" != "0" ]; then
        ExitScript "could not locate slack app after unzipping" "1"
    else
        echo "Ditto command worked"
    fi
fi

CheckExistence "-d" "$appDir/Slack.app"
if [ "$?" = "1" ]; then
    echo "Slack does not exist on this system.  Moving forward with install."
    InstallSlack
    CheckExistence "-d" "$appDir/Slack.app"
    if [ "$?" = "1" ]; then
        ExitScript "Something failed during the move of slack." "1"
    else
        CheckVersion "$appDir"
        ExitScript "Slack version $slackVersion successfully installed" "0"
    fi
else
    # If the Slack exists in the applications folder and is older
    # then what is downlaoded, perform an upgrade.
    # This includes a killing the Slack process, deleting the current app,
    # and moving the new version to the applications folder.
    CheckVersion "/tmp" "$appDir"
    if [ "$?" = 1 ]; then
        ExitScript "Slack Version installed is newer or the same as the download. No need to upgrade." "0"
    else
        echo "Installed version is older then the one downloaded."
    fi
    SlackRunning
    if [ "$?" = "0" ]; then
        #Slack is running, Prompt user to close
        echo "Slack is running, prompting user to close."
        PromptToClose
        if [ "$?" = 0 ]; then
            echo "User wants to close slack and continue install/upgrade"
            killall Slack
            SlackRunning
            if [ "$?" = "0" ]; then
                #Slack is running, Prompt user to close
                ExitScript "Slack is still running.  Exiting as something failed." "1"
            else
                echo "Slack quit successfully."
            fi
        else
            ExitScript "Skipping upgrade for now as user did not want to quit the Slack app." "1"
        fi
    fi
    rm -rf "$appDir"/Slack.app
    InstallSlack
    CheckExistence "-d" "$appDir/Slack.app"
    if [ "$?" = "1" ]; then
        ExitScript "Something failed during the move of slack." "1"
    fi
    CheckVersion "/tmp" "$appDir"
    if [ "$?" = 0 ]; then
        # Versions didn't change
        ExitScript "Slack Version installed is newer or the same as the download. Upgrade failed." "0"
    fi
    echo "Slack version $slackVersion successfully installed"
    echo "Launching Slack now"
    open -a "$appDir"/Slack.app
    SlackRunning
    if [ "$?" = "0" ]; then
        echo "Successfully launched Slack.app"
    else
        echo "Could not launch Slack.app"
    fi
    rm -rf "$counterFile"
    ExitScript "" "0"
fi

