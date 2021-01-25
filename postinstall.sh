#!/bin/sh

# Install main munki pkg
/usr/sbin/installer -pkg /tmp/munkitools-CURRENT_VERSION.pkg -target /

# Copy middleware_s3.py to proper location
cp -R /tmp/middleware_s3.py /usr/local/munki/middleware_s3.py

# Change the repo location and give user rights
defaults write /Library/Preferences/ManagedInstalls AccessKey 'AKIASO2EQBAJCCXFCFUV-EXAMPLE'
defaults write /Library/Preferences/ManagedInstalls SecretKey 'DpQB1rjn1LLm2oWghz28I9KnrN7s8ni1Ts1lHUnV-EXAMPLE'
defaults write /Library/Preferences/ManagedInstalls Region 'us-east-1'
defaults write /Library/Preferences/ManagedInstalls SoftwareRepoURL  "https://S3-BUCKET.s3.amazonaws.com"

#Clean up
rm -rf /tmp/munkitools-CURRENT_VERSION.pkg
rm -rf /tmp/middleware_s3.py