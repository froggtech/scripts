#!/bin/bash

jamfbinary=$(/usr/bin/which jamf)
doneFile="/Users/Shared/.SpashBuddyDone"

echo "Installing NoMADLoginAD"
${jamfbinary} policy -event "$11"

sleep 15

while true
do
loggedinuser=$(/bin/ls -l /dev/console | /usr/bin/awk '{ print $3 }')

echo $loggedinuser

    if [ "${loggedinuser}" == "root" ] || [ "${loggedinuser}" == "_mbsetupuser" ]; then
    echo "is root or mbsetupuser"
    sleep 10
    else
    echo "is local user"
    break
    fi
done

echo "Installing SplashBuddy"
${jamfbinary} policy -event "$4"

echo "Drinking some Monster so the Mac doesn't fall asleep"
caffeinate -d -i -m -u &
caffeinatepid=$!

echo "Setting GRCS Name and Default Settings"
${jamfbinary} policy -event "$5"

echo "Installing Securly Certificate"
${jamfbinary} policy -event "$6"

echo "Installing Printer Drivers"
${jamfbinary} policy -event "$7"

echo "Installing Google Chrome"
${jamfbinary} policy -event "$8"

echo "Installing NoMAD"
${jamfbinary} policy -event "$9"

echo "Installing Google Backup and Sync"
${jamfbinary} policy -event "$10"

echo "Creating done file"
touch "$doneFile"

echo "Updating Inventory"
${jamfbinary} policy -event "updateInventory"

echo "Catching some ZZZ's"
sleep 120

echo "Quitting SplashBuddy"
osascript -e 'quit app "SplashBuddy"'

echo "Unloading and removing SplashBuddy LaunchDaemon"
launchtl unload /Library/LaunchDaemons/io.fti.splashbuddy.launch.plist
rm -f /Library/LaunchDaemons/io.fti.splashbuddy.launch.plist

echo "Deleting SplashBuddy"
rm -rf "/Library/Application Support/SplashBuddy"

echo "Drank waaaaaayyyyyy too much Monster"
kill "$caffeinatepid"

echo "Restarting for good measure"
reboot
