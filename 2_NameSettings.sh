#!/bin/bash

###################################
#
#	General Description:
#	Sets name of computer and runs through other firstboot script pieces
#
#
#
#	Specific Description:
#	Gathers serial number of device
#	Connects to server share and finds proper CSV
#	Parses CSV for serial number
#	Uses serial number to find proper name
#	Sets device to proper name
#	Runs a recon
#	Binds to AD
#
#
#	Author: David Minnema
#	Created: 02/22/18
#	Modified: 02/22/18
#	Version: 1.0
#
##################################

##################################
#
#	1 - Set Computer Name
#
##################################

# Set Server Location
server=10.48.5.11

# Set Share Location
share=/caspershare/ImagingNames

# Input File Name
input=data.csv

# Mount Share
jamf mount -server $server -share $share -type smb -username grcsinstall2 -password Install2

# Strip any \r values from the CSV after loop
sed -i '' $'s/\r$//' /Volumes/caspershare/data.csv

# Start rename process
echo "Starting Computer Rename..."
echo ""

# Get serial from ioreg
serial="$(ioreg -l | grep IOPlatformSerialNumber | sed -e 's/.*\"\(.*\)\"/\1/')"
echo $serial

# Initialize compName to null
compName=''

# Loop through CSV looking for a match
while IFS=',' read ser loc; do
  if [ "$serial" == "$ser" ]; then
    compName=$loc
    echo "Serial number matched with computer name: $compName"
  fi
done < /Volumes/caspershare/data.csv

# If compName is not null, use scutil to rename. Otherwise user must manually rename
if [[ -z $compName ]]; then
  echo "No computer name matches the serial number of your system. Either manually rename the system or update names.csv and re-run the script."

  else
  echo "Setting Host Name to $compName"
  scutil --set HostName "$compName"

  echo "Setting Computer Name to $compName"
  scutil --set ComputerName $compName

  echo "Setting Local Host Name to $compName"
  scutil --set LocalHostName "$compName"

  echo "Computer Renamed Successfully!"
fi

# Unmount ImagingNames
umount /Volumes/caspershare/

##################################
#
#	Begin Old FirstBoot Script
#
##################################

##################################
#
####	Variables	
#
##################################

# Wireless Settings
GRCS_WIFI_SSID="GRCS_A"
# options for security mode are NONE, WEP, WPA, WPA2, WPAE, WPA2E
GRCS_WIFI_SecurityMode="WPA2"
GRCS_WIFI_Password="GRCSW1r3l355A"
TimeZone="America/Detroit"
GRCS_TimeServer1="util.grcs.org"
GRCS_TimeServer2="time.apple.com"

# Log location for troubleshooting
# Could be an EA to verify post-image was successful
LOG_FOLDER="/var/log"
	if [ ! -e $LOG_FOLDER ]; then
		mkdir $LOG_FOLDER
	fi
LOG_LOCATION="$LOG_FOLDER/PostImage.log"
touch $LOG_LOCATION

##################################
#
####	Functions
#
##################################

# Function to provide logging of the script's actions to
# the log file defined by the log_location variable
ScriptLogging(){
 
    DATE=`date +%Y-%m-%d\ %H:%M:%S`
    LOG="$LOG_LOCATION"
    echo "$DATE" " $1" >> $LOG
}
##################################
#
####	Step 1: Initialize
#
##################################

ScriptLogging "Post-Image process initiated"

# Unload login window
#launchctl unload /System/Library/LaunchDaemons/com.apple.loginwindow.plist
#ScriptLogging "Login Window unloaded"

##################################
#
####	Step 2: Wireless
#
##################################

# Clear presets and refresh all adapter lists
#killall cfprefsd
#killall cupsd
#launchctl unload /System/Library/LaunchDaemons/org.cups.cupsd.plist
#launchctl load /System/Library/LaunchDaemons/org.cups.cupsd.plist
#update_dyld_shared_cache -root

# Refresh Network Adapters
#/usr/sbin/networksetup -detectnewhardware

# Identify WiFi device name
#wifiDevice=$(/usr/sbin/networksetup -listallhardwareports | awk '/^Hardware Port: Wi-Fi/,/^Ethernet Address/' | head -2 | tail -1 | cut -c 9-)

# Apply WiFi settings
#/usr/sbin/networksetup -addpreferredwirelessnetworkatindex $wifiDevice $GRCS_WIFI_SSID 0 $GRCS_WIFI_SecurityMode $GRCS_WIFI_Password

#ScriptLogging "Wireless settings applied"

##################################
#
####	Step 3: Set Timeserver and Restart Time Service
#
##################################

# Enable NTP and set the servers
/usr/sbin/systemsetup -setusingnetworktime off
/usr/sbin/systemsetup -setnetworktimeserver $GRCS_TimeServer1
echo "server $GRCS_TimeServer2" >> /etc/ntp.conf
/usr/sbin/systemsetup -setusingnetworktime on

# Ensure time zone is correct
/usr/sbin/systemsetup -settimezone $TimeZone

ScriptLogging "Time server set to $GRCS_TimeServer1"
ScriptLogging "Note that this may cause a discrepancy in log entries"

##################################
#
####	Step 4: Set Default System-Wide Preferences
#
##################################

# GATHER INFORMATION

	# Get the system's UUID to set ByHost prefs
	if [[ $(ioreg -rd1 -c IOPlatformExpertDevice | grep -i "UUID" | cut -c27-50) == "00000000-0000-1000-8000-" ]]; then
		MAC_UUID=$(ioreg -rd1 -c IOPlatformExpertDevice | grep -i "UUID" | cut -c51-62 | awk {'print tolower()'})
	elif [[ $(ioreg -rd1 -c IOPlatformExpertDevice | grep -i "UUID" | cut -c27-50) != "00000000-0000-1000-8000-" ]]; then
		MAC_UUID=$(ioreg -rd1 -c IOPlatformExpertDevice | grep -i "UUID" | cut -c27-62)
	fi

# GENERAL PREFERENCES
ScriptLogging "Setting General Preferences"
	
	# Disable Hibernation Services
	pmset -a hibernatemode 0
	ScriptLogging "  -Hibernation services disabled"

	# Configure Finder to use Column View
	/usr/bin/defaults write /System/Library/User\ Template/English.lproj/Library/Preferences/com.apple.finder "AlwaysOpenWindowsInColumnView" -bool true
	ScriptLogging "  -Finder default set to column view"

	# Allow viewing of basic system information at login window
	/usr/bin/defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName
	ScriptLogging "  -Allow viewing of system info at login window"

	# Set the "Show scroll bars" setting (in System Preferences: General)
	# to "Always" in your Mac's default user template and for all existing users.

	for USER_TEMPLATE in "/System/Library/User Template"/*
	  do
		 if [ ! -d "${USER_TEMPLATE}"/Library/Preferences ]
		  then
			mkdir -p "${USER_TEMPLATE}"/Library/Preferences
		 fi
		 if [ ! -d "${USER_TEMPLATE}"/Library/Preferences/ByHost ]
		  then
			mkdir -p "${USER_TEMPLATE}"/Library/Preferences/ByHost
		 fi
		 if [ -d "${USER_TEMPLATE}"/Library/Preferences/ByHost ]
		  then
			defaults write "${USER_TEMPLATE}"/Library/Preferences/.GlobalPreferences AppleShowScrollBars -string Always
		 fi
	  done
	ScriptLogging "  -Finder set to display Scroll bars"

	# Turn off Gatekeeper
	spctl --master-disable 
	# Disable Gatekeeper's auto-rearm.
	/usr/bin/defaults write /Library/Preferences/com.apple.security GKAutoRearm -bool false
	ScriptLogging "  -Gatekeeper disabled"

	#disable auto restore preview and quicktime
	/usr/bin/defaults write com.apple.Preview NSQuitAlwaysKeepsWindows -bool false
	/usr/bin/defaults write com.apple.QuickTimePlayerX NSQuitAlwaysKeepsWindows -bool false
	ScriptLogging "  -Auto-restore disabled for preview and quicktime"

	#Decline to send diagnostic data to Apple
	SUBMIT_DIAGNOSTIC_DATA_TO_APPLE=FALSE
	SUBMIT_DIAGNOSTIC_DATA_TO_APP_DEVELOPERS=FALSE
	CRASHREPORTER_SUPPORT="/Library/Application Support/CrashReporter"
 
	if [ ! -d "${CRASHREPORTER_SUPPORT}" ]; then
		mkdir "${CRASHREPORTER_SUPPORT}"
		chmod 775 "${CRASHREPORTER_SUPPORT}"
		chown root:admin "${CRASHREPORTER_SUPPORT}"
	fi

	/usr/bin/defaults write "$CRASHREPORTER_SUPPORT"/DiagnosticMessagesHistory AutoSubmit -boolean ${SUBMIT_DIAGNOSTIC_DATA_TO_APPLE}
	/usr/bin/defaults write "$CRASHREPORTER_SUPPORT"/DiagnosticMessagesHistory AutoSubmitVersion -int 4
	/usr/bin/defaults write "$CRASHREPORTER_SUPPORT"/DiagnosticMessagesHistory ThirdPartyDataSubmit -boolean ${SUBMIT_DIAGNOSTIC_DATA_TO_APP_DEVELOPERS}
	/usr/bin/defaults write "$CRASHREPORTER_SUPPORT"/DiagnosticMessagesHistory ThirdPartyDataSubmitVersion -int 4
	/bin/chmod a+r "$CRASHREPORTER_SUPPORT"/DiagnosticMessagesHistory.plist
	/usr/sbin/chown root:admin "$CRASHREPORTER_SUPPORT"/DiagnosticMessagesHistory.plist
	ScriptLogging "Decline to send diagnostic data to Apple and 3rd party developers"

	# Bypass updating Managed Settings Message
	/usr/bin/defaults write /Library/Preferences/com.apple.mdmclient BypassPreLoginCheck -bool YES
	ScriptLogging "  -Disable 'Updating Managed Settings' message at login"

# UI PREFERENCES
ScriptLogging "Setting UI preferences:"

	# Disable the save window state at logout
	/usr/bin/defaults write com.apple.loginwindow 'TALLogoutSavesState' -bool false
	ScriptLogging "  -Disable 'Reopen Windows at Login'"

	# Set Shutdown and Logoff timers to 1 second (No Delay)
	/usr/bin/defaults write /System/Library/LaunchDaemons/com.apple.coreservices.appleevents ExitTimeOut -int 1
	/usr/bin/defaults write /System/Library/LaunchDaemons/com.apple.securityd ExitTimeOut -int 1
	/usr/bin/defaults write /System/Library/LaunchDaemons/com.apple.mDNSResponder ExitTimeOut -int 1
	/usr/bin/defaults write /System/Library/LaunchDaemons/com.apple.diskarbitrationd ExitTimeOut -int 1
	ScriptLogging "  -Setting shutdown and logoff timers to no delay" 

	# Expand save panel by default
	/usr/bin/defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
	/usr/bin/defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
	ScriptLogging "  -Expand Save Panel by default"

	# Expand print panel by default
	/usr/bin/defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
	/usr/bin/defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
	ScriptLogging "  -Expand Print Panel by default"
	
	# Disable the crash reporter
	/usr/bin/defaults write com.apple.CrashReporter DialogType -string "none"
	ScriptLogging "  -Disable Crash Reporter"

	# Disable disk image verification
	/usr/bin/defaults write com.apple.frameworks.diskimages skip-verify -bool true
	/usr/bin/defaults write com.apple.frameworks.diskimages skip-verify-locked -bool true
	/usr/bin/defaults write com.apple.frameworks.diskimages skip-verify-remote -bool true
	ScriptLogging "  -Disable .dmg verification"

	# Automatically illuminate built-in MacBook keyboard in low light and turn off in idle after 5 minutes
	defaults write com.apple.BezelServices kDim -bool true
	defaults write com.apple.BezelServices kDimTime -int 300
	ScriptLogging "  -Keyboard illumination enabled"

	# Set System Volume level to 50% 
	osascript -e 'set volume output volume 50'
	ScriptLogging "  -Volume set to 50%"

	# Make shortcut links to Network Utility, Directory Utility, Screen Sharing, Raid Utility, and Archive Utility under "Utilities" Folder
	ln -s /System/Library/CoreServices/Applications/Network\ Utility.app /Applications/Utilities/Network\ Utility.app
	ln -s /System/Library/CoreServices/Applications/Directory\ Utility.app /Applications/Utilities/Directory\ Utility.app
	ln -s /System/Library/CoreServices/Applications/Screen\ Sharing.app /Applications/Utilities/Screen\ Sharing.app
	ln -s /System/Library/CoreServices/Applications/RAID\ Utility.app /Applications/Utilities/RAID\ Utility.app
	ln -s /System/Library/CoreServices/Applications/Archive\ Utility.app /Applications/Utilities/Archive\ Utility.app
	ScriptLogging "  -Added shortcuts to additional utilities"

# NETWORK PREFERENCES
ScriptLogging "Setting Network Preferences:"

	# Turn off DS_Store file creation on network volumes
	/usr/bin/defaults write /System/Library/User\ Template/English.lproj/Library/Preferences/com.apple.desktopservices DSDontWriteNetworkStores true
	ScriptLogging "  -Disable .ds_store file creation on network volumes"

	# Turn off SMB2 & SMB3 network protocol and force OS X 10.10 to use SMB1 for legacy Netapp servers
	echo "[default]" >> \~/Library/Preferences/nsmb.conf; echo "smb_neg=smb1_only" >> \~/Library/Preferences/nsmb.conf
	ScriptLogging "  -Force SMB1 network protocol"

# SECURITY PREFERENCES
ScriptLogging "Setting Security Preferences:"

	# Set default  screensaver settings
	mkdir /System/Library/User\ Template/English.lproj/Library/Preferences/ByHost

	# Set Default Screen Saver (Display Computer Name)
	/usr/bin/defaults write /System/Library/User\ Template/English.lproj/Library/Preferences/ByHost/com.apple.screensaver.$MAC_UUID "moduleName" -string "Message"
	#/usr/bin/defaults write /System/Library/User\ Template/English.lproj/Library/Preferences/ByHost/com.apple.screensaver.$MAC_UUID "modulePath" -string "/System/Library/Screen Savers/FloatingMessage.saver"
	/usr/bin/defaults write /System/Library/User\ Template/English.lproj/Library/Preferences/ByHost/com.apple.screensaver.$MAC_UUID MESSAGE "Property of Grand Rapids Christian Schools"
	/usr/bin/defaults write /System/Library/User\ Template/English.lproj/Library/Preferences/ByHost/com.apple.screensaver.$MAC_UUID "idleTime" -int 600
	ScriptLogging "  -Enable screensaver"

	# Enable Screensaver Password
	/usr/bin/defaults write /System/Library/User\ Template/English.lproj/Library/Preferences/ByHost/com.apple.screensaver.$MAC_UUID "askForPassword" -int 1
	/usr/bin/defaults write /System/Library/User\ Template/English.lproj/Library/Preferences/com.apple.screensaver askForPassword -int 1
	/usr/bin/defaults write /System/Library/User\ Template/English.lproj/Library/Preferences/com.apple.screensaver askForPasswordDelay -int 24
	ScriptLogging "  -Enable Screensaver password"

	# Set the login window to name and password
	/usr/bin/defaults write /Library/Preferences/com.apple.loginwindow SHOWFULLNAME -bool true
	ScriptLogging "  -Force login window to Name/Password"

	# Disable external accounts (i.e. accounts stored on drives other than the boot drive.)
	/usr/bin/defaults write /Library/Preferences/com.apple.loginwindow EnableExternalAccounts -bool false
	ScriptLogging "  -Disable external accounts"

	# Block Apple Setup Assistant from running
	for USER_TEMPLATE in "/System/Library/User Template"/*
		do
			/usr/bin/defaults write "${USER_TEMPLATE}"/Library/Preferences/com.apple.SetupAssistant DidSeeCloudSetup -bool TRUE
			/usr/bin/defaults write "${USER_TEMPLATE}"/Library/Preferences/com.apple.SetupAssistant GestureMovieSeen none
			/usr/bin/defaults write "${USER_TEMPLATE}"/Library/Preferences/com.apple.SetupAssistant LastSeenCloudProductVersion "${sw_vers}"
			/usr/bin/defaults write "${USER_TEMPLATE}"/Library/Preferences/com.apple.SetupAssistant LastSeenBuddyBuildVersion "${sw_build}"      
		done
	mv /System/Library/CoreServices/Setup\ Assistant.app/Contents/SharedSupport/MiniLauncher /System/Library/CoreServices/Setup\ Assistant.app/Contents/SharedSupport/MiniLauncher.backup
	/usr/bin/defaults write "/System/Library/User Template/English.lproj/Library/Preferences/com.apple.finder.plist" ProhibitGoToiDisk -bool YES
	ScriptLogging "  -Block Apple Setup Assistant from running"

	# Set login window anti-theft message
	/usr/bin/defaults write /Library/Preferences/com.apple.loginwindow.plist LoginwindowText -string "Property of:
    Grand Rapids Christian Schools
    (616) 574-6000"
    ScriptLogging "  -Set login window ownership message"

	# Set the RSA maximum key size to 32768 bits (32 kilobits)
	/usr/bin/defaults write /Library/Preferences/com.apple.security RSAMaxKeySize -int 32768
	ScriptLogging "  -Set RSA max key size to 32kb"

	# turn on location service
	launchctl unload /System/Library/LaunchDaemons/com.apple.locationd.plist
	uuid=`/usr/sbin/system_profiler SPHardwareDataType | grep "Hardware UUID" | cut -c22-57`
	/usr/bin/defaults write /var/db/locationd/Library/Preferences/ByHost/com.apple.locationd.$uuid LocationServicesEnabled -int 1
	chown -R _locationd:_locationd /var/db/locationd
	launchctl load /System/Library/LaunchDaemons/com.apple.locationd.plist
	ScriptLogging "  -Enable Location Services"

	# Disable default file sharing for guest
	/usr/bin/defaults write /Library/Preferences/com.apple.AppleFileServer guestAccess -bool false
	ScriptLogging "  -Disable file sharing for guest account"

	# Disable OS X OS Prerelease downloads for all users 
	/usr/bin/defaults write /Library/Preferences/com.apple.SoftwareUpdate AllowPreReleaseInstallation -bool false
	ScriptLogging "  -Disable OS X pre-release downloads"

	# Turn off Automatic updates
	softwareupdate --schedule off
	ScriptLogging "  -Disable Automatic updates"

	# Give all end-users permissions full access to Print & Scan Preference Pane
\	security authorizationdb write system.preferences.printing allow
	/usr/bin/security authorizationdb write system.print.operator allow
	/usr/sbin/dseditgroup -o edit -n /Local/Default -a everyone -t group lpadmin
	/usr/sbin/dseditgroup -o edit -n /Local/Default -a everyone -t group _lpadmin
	/usr/sbin/dseditgroup -o edit -n /Local/Default -a 'Domain Users' -t group lpadmin
	ScriptLogging "  -Allow access to Print & Scan preference pane and printer settings for all users"

	# Terminal command-line access warning
	/usr/bin/touch /etc/motd
	/bin/chmod 644 /etc/motd
	/bin/echo "" >> /etc/motd
	/bin/echo "This Apple Workstation, including all related equipment, is the property of Grand Rapids Christian Schools. Use is governed by the GRCS Responsible Use Policy.  A copy of this policy can be located at www.grcs.org" >> /etc/motd
	/bin/echo "" >> /etc/motd
	ScriptLogging "  -Set terminal command line ownership and usage notification"

#################################
#
####	Step 5: Set Default User Preferences
#
##################################

ScriptLogging "Setting Default User-Level Preferences:"

# Remove info files on all rm -R /System/Library/User\ Template/Non_localized/Downloads/About\ Downloads.lpdf
rm -R /System/Library/User\ Template/Non_localized/Documents/About\ Stacks.lpdf
ScriptLogging "  -Clean downloads folder"

# Show the \~/Library folder
sudo chflags nohidden /System/Library/User\ Template/English.lproj/Library/
/usr/bin/chflags nohidden $HOME/Library
sudo chflags nohidden /Users/xxxxxxxxx/Library
ScriptLogging "  -Show ~/Library folder"

# Expand “General”, “Open with”, and “Sharing & Permissions” in File Information
defaults write /System/Library/User\ Template/English.lproj/Library/Preferences/com.apple.finder FXInfoPanesExpanded -dict \ General -bool true \ OpenWith -bool true \ Privileges -bool true
ScriptLogging "  -Expand certain sections of Get Info panel"

# Disable “Application Downloaded from the internet” message
sudo defaults write /System/Library/User\ Template/English.lproj/Library/Preferences/com.apple.LaunchServices LSQuarantine -bool NO
defaults write com.apple.LaunchServices LSQuarantine -bool NO
ScriptLogging "  -Disable “Application Downloaded from the internet” message"

# Disable the “Are you sure you want to open this application?” dialog
defaults write /System/Library/User\ Template/English.lproj/Library/Preferences/com.apple.LaunchServices LSQuarantine -bool false
ScriptLogging "  -# Disable the “Are you sure you want to open this application?” dialog"

# Show "Mounted Server Shares, External and Internal Hard Disks" on the main Finder Desktop
defaults write /System/Library/User\ Template/English.lproj/Library/Preferences/com.apple.finder ShowMountedServersOnDesktop -bool true
defaults write /System/Library/User\ Template/English.lproj/Library/Preferences/com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write /System/Library/User\ Template/English.lproj/Library/Preferences/com.apple.finder ShowHardDrivesOnDesktop -bool true
defaults write /System/Library/User\ Template/English.lproj/Library/Preferences/com.apple.finder ShowRemovableMediaOnDesktop -bool true
ScriptLogging "  -Show "Mounted Server Shares, External and Internal Hard Disks" on the main Finder Desktop"

# Expand the print dialog window
defaults write /Library/Preferences/.GlobalPreferences PMPrintingExpandedStateForPrint2 -bool TRUE
ScriptLogging "  -Expand the print dialog window"

# Configure Finder settings (List View, Show Status Bar, Show Path Bar)
defaults write /System/Library/User\ Template/English.lproj/Library/Preferences/com.apple.finder "AlwaysOpenWindowsInListView" -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
defaults write /System/Library/User\ Template/English.lproj/Library/Preferences/com.apple.finder ShowStatusBar -bool true
defaults write /System/Library/User\ Template/English.lproj/Library/Preferences/com.apple.finder ShowPathbar -bool true
ScriptLogging "  -Configure finder settings"

# Trackpad & Mouse: Map bottom right corner to right-click and secondary button for Mouse
defaults write /System/Library/User\ Template/English.lproj/Library/Preferences/com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -int 2
defaults write /System/Library/User\ Template/English.lproj/Library/Preferences/com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
defaults -currentHost write NSGlobalDomain com.apple.trackpad.trackpadCornerClickBehavior -int 1
defaults -currentHost write NSGlobalDomain com.apple.trackpad.enableSecondaryClick -bool true
defaults write "/System/Library/User Template/English.lproj/Library/Preferences/com.apple.driver.AppleBluetoothMultitouch.mouse" MouseButtonMode -string TwoButton
defaults write "/System/Library/User Template/English.lproj/Library/Preferences/com.apple.driver.AppleHIDMouse" Button1 -integer 1
defaults write "/System/Library/User Template/English.lproj/Library/Preferences/com.apple.driver.AppleHIDMouse" Button2 -integer 2
ScriptLogging "  -Set reasonable defaults for trackpad and external mice"

##################################
#
####	Step 6: Grant Localadmin SSH Access
#
##################################

# Grant LocalAdmin user access to SSH
dscl . append /Groups/com.apple.access_ssh user
dscl . -append /Groups/com.apple.access_ssh GroupMembership localadmin
ScriptLogging "Grant above localadmin SSH access"

# Turn SSH on
systemsetup -setremotelogin on
/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate -configure -access -on -users localadmin -privs -all -restart -agent -menu
/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -activate -restart -console
ScriptLogging "Enable SSH"

##################################
#
####	Step 7: Bind to GRCS.ORG w/ Settings
#
##################################

# Add the mac to the domain
#dsconfigad -force -a $compName -u grcsinstall2 -p Install2 -domain grcs.org

# Pause to allow binding
#sleep 15
#ScriptLogging "Bound to grcs.org as $compName"

# Allow logins from any domain in the forest
#dsconfigad -alldomains enable

# Enable mobile accounts
#dsconfigad -mobile enable
#dsconfigad -mobileconfirm disable

# Disable UNC paths
#dsconfigad -localhome enable
#dsconfigad -useuncpath disable

# Set the shell to something sensible
#dsconfigad -shell "/bin/bash"

# Enable packet signing
#dsconfigad -packetsign require
#ScriptLogging "Applied AD settings"

##################################
#
####	Step 8: Release
#
##################################

# Turn on SSH
/usr/sbin/jamf startSSH

# Remove setup LaunchDaemon item
srm /Library/LaunchDaemons/com.grcs.initialsetup.plist
ScriptLogging "Removed LD"

# reload login window
launchctl load /System/Library/LaunchDaemons/com.apple.loginwindow.plist
ScriptLogging "Login Window reloaded"
ScriptLogging "Post-Image process completed"

# Create receipt for Jamf to remove machine from smart group
touch /private/var/1enroll

# Run C @ Login Policy
jamf policy -trigger windramloginC

# Run Recon
#jamf recon
#sleep 120


# Restart
#reboot

# Run Policy
#jamf policy
