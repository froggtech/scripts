#!/bin/bash
##############
# This script will give a user 30 minutes of Admin level access, from Jamf's self 
# service.
# At the end of the 30 minutes it will then call a jamf policy with a manual 
# trigger. 
# Remove the users admin rights and disable the plist file this creates and 
# activites.
# The removal script is adminDisable.sh
##############

USERNAME=$(who |grep console| awk '{print $1}')
CD="/private/var/CocoaDialog.app/Contents/MacOS/CocoaDialog"
adminTime=180
# Place launchd plist to call JSS policy to remove admin rights.
#####
echo "<?xml version="1.0" encoding="UTF-8"?> 
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"> 
<plist version="1.0"> 
<dict>
	<key>Disabled</key>
	<true/>
	<key>Label</key> 
	<string>com.grcs.adminDisable</string> 
	<key>ProgramArguments</key> 
	<array> 
		<string>/usr/local/jamf/bin/jamf</string>
		<string>policy</string>
		<string>-trigger</string>
		<string>adminDisable</string>
	</array>
	<key>StartInterval</key>
	<integer>$adminTime</integer> 
</dict> 
</plist>" > /Library/LaunchDaemons/com.yourcompany.adminDisable.plist
#####

#set the permission on the file just made.
chown root:wheel /Library/LaunchDaemons/com.yourcompany.adminDisable.plist
chmod 644 /Library/LaunchDaemons/com.yourcompany.adminDisable.plist
defaults write /Library/LaunchDaemons/com.yourcompany.adminDisable.plist disabled -bool false

# load the removal plist. 
launchctl load -w /Library/LaunchDaemons/com.yourcompany.adminDisable.plist

# build log files in var/uits
mkdir /var/uits
TIME=`date "+Date:%m-%d-%Y TIME:%H:%M:%S"`
echo $TIME " by " $USERNAME >> /var/uits/30minAdmin.txt

echo $USERNAME >> /var/uits/userToRemove

# give current logged user admin rights
nohup $CD bubble --debug --title "Administrator Privilege Granted" --text \
    "Modifications will be logged for future troubleshooting!"  --background-top\
    "66FF00" --background-bottom "99CC00" icon "info" --timeout 60 &
nohup fs_usage -e Installer -t $adminTime | grep mkdir >/var/uits/$TIME &
/usr/sbin/dseditgroup -o edit -a $USERNAME -t user admin

exit 0
