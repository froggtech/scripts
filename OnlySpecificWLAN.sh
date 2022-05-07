#!/bin/sh

##########################################
#####
###		Created By: David Minnema
##		Version: 1.0
###
##########################################
# Setting the Environmental Variables

# Get the ethernet hardware port (ehwport)
ehwport=`/usr/sbin/networksetup -listallhardwareports | awk '/.Ethernet/,/Ethernet Address/' | awk 'NR==2' | cut -d " " -f 2`
#echo $ehwport

# Get the wireless network service (wservice)
wservice=`/usr/sbin/networksetup -listallnetworkservices | grep -Ei '(Wi-Fi|AirPort)'`
#echo $wservice

# Get the wireless hardware port (whwport)
whwport=`/usr/sbin/networksetup -listallhardwareports | awk "/$wservice/,/Ethernet Address/" | awk 'NR==2' | cut -d " " -f 2`
#echo $whwport

# Find the ALL network hardware ports (hwports)
hwports=`/usr/sbin/networksetup -listallhardwareports | awk '/Hardware Port: Wi-Fi/,/Ethernet/' | awk 'NR==2' | cut -d " " -f 2`
#echo $hwports

# Get the wireless network (wirelessnw)
wirelessnw=`/usr/sbin/networksetup -getairportnetwork $hwports | cut -d " " -f 4`
#echo $wirelessnw

# Get the SSID
SSID=`/System/Library/PrivateFrameworks/Apple80211.framework/Versions/A/Resources/airport -I\
| grep ' SSID:' | cut -d ':' -f 2 | tr -d ' '`
#echo $SSID

# School SSID
# Change "PreferredSSID_NAME to the SSID you'd like to require."
SchoolSSID="PreferredSSID_NAME"

# Sets up the machine to scan for Wireless Networks
SCAN="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport /usr/bin/airport"


#########################################################################################
# Start of Script

echo `date`
if [ "$SSID" == "$SchoolSSID" ]; then
	echo "Connected to $SchoolSSID!"
	exit 0
else
	# Scans for GRCS_A
	PREF=`$SCAN -s | grep $SchoolSSID | awk '{print $1}'| awk 'NR==2' | cut -d " " -f 1`;
	echo $PREF
fi
	
if [ "$PREF" == "$SchoolSSID" ]; then
	echo $PREF "Found!"
	/usr/sbin/networksetup -addpreferredwirelessnetworkatindex $whwport $SchoolSSID 0 WPA2
	# The following will remove any networks from the preferred networks list that you don't want students or employees to have, must rename the section in quotes to the SSID we want to remove.
	/usr/sbin/networksetup -removepreferredwirelessnetwork $whwport "Guest"
	/usr/sbin/networksetup -removepreferredwirelessnetwork $whwport "Provisioning"
	/usr/sbin/networksetup -removepreferredwirelessnetwork $whwport "WINDOWS"
	killall -HUP mDNSResponder;
	echo "DNS Cache Flushed"
	/usr/sbin/networksetup -setairportpower $whwport off
	/usr/sbin/networksetup -setairportpower $whwport on
else
	echo "$SchoolSSID not found. Continue doing what you were doing"

fi

exit 0
