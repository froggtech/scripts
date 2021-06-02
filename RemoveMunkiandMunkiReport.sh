#!/bin/bash

#  Install Munki Client, point it at your munki repo, and run updates
#  Coded by Jack-Daniyel Strong, J-D Strong Consulting, Inc. & Strong Solutions
#  Written 2015.07.28, Last Modified 2015.10.19 by Jack-Daniyel Strong

# Audible Notifications
NOTIFY=0   # set to 0 to not have audible notification
webhook_URL=REPLACE_ME_WITH_A_WEBHOOKURL

### TOUCH NOTHING BELOW THIS LINE ###
##### Begin Declare Variables Used by Script #####
 
DEFAULTS="/usr/bin/defaults"
INSTALLER="/usr/sbin/installer"
REMOVE="/bin/rm"
LAUNCHCTL="/bin/launchctl"
CURL="/usr/bin/curl"
OPEN="/usr/bin/open"
PKGUTIL="/usr/sbin/pkgutil"
MUNKIREPORT="/usr/local/munkireport"
MYHOST=$(networksetup -getcomputername)

# Declare directory variables.
PREFS_DIR="/Library/Preferences"
MANAGEDINSTALLS="${PREFS_DIR}/ManagedInstalls"

##### End Declare Variables Used by Script #####

if [ $(whoami) != 'root' ]; then
       echo "Must be root to run $0"
        exit 1;
fi

##### Let us set some Preferences #####

 launchctl unload /Library/LaunchDaemons/com.googlecode.munki.*

$REMOVE -rf "/Applications/Utilities/Managed Software Update.app"
#Munki 2 only:
$REMOVE -rf "/Applications/Managed Software Center.app"

$REMOVE -f /Library/LaunchDaemons/com.googlecode.munki.*
$REMOVE -f /Library/LaunchAgents/com.googlecode.munki.*
$REMOVE -rf "/Library/Managed Installs"
$REMOVE -f $MANAGEDINSTALLS
$REMOVE -rf /usr/local/munki
$REMOVE /etc/paths.d/munki
defaults write $MANAGEDINSTALLS SoftwareRepoURL ""

$PKGUTIL --forget com.googlecode.munki.admin
$PKGUTIL --forget com.googlecode.munki.app
$PKGUTIL --forget com.googlecode.munki.core
$PKGUTIL --forget com.googlecode.munki.launchd

#Tells munkireport
$MUNKIREPORT/munkireport-runner

#Removes munkireport
# remove the MunkiReport directories
sudo rm -rf /usr/local/munkireport/
sudo rm -rf /Library/Munkireport/

# remove the munki scripts
sudo rm /usr/local/munki/postflight
sudo rm /usr/local/munki/report_broken_client

# remove prefs
sudo rm /Library/Preferences/MunkiReport.plist

# remove pkgreceipt
sudo pkgutil --forget com.github.munkireport

#unload LaunchDaemon
sudo launchctl unload /Library/LaunchDaemons/com.github.munkireport.runner.plist

#remove LaunchDaemon
sudo rm /Library/LaunchDaemons/com.github.munkireport.runner.plist

#Tell Slack I'm done!
curl -X POST -H 'Content-type: application/json' --data '{"text":"'$MYHOST': Munki and Munkireport are removed!"}' $webhook_URL

#Self Destruct
rm -f /tmp/postinstall.sh

exit 0;