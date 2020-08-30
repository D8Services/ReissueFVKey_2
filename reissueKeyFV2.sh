#!/bin/bash

####################################################################################################
#
# Copyright (c) 2017, JAMF Software, LLC.  All rights reserved.
#
#       Redistribution and use in source and binary forms, with or without
#       modification, are permitted provided that the following conditions are met:
#               * Redistributions of source code must retain the above copyright
#                 notice, this list of conditions and the following disclaimer.
#               * Redistributions in binary form must reproduce the above copyright
#                 notice, this list of conditions and the following disclaimer in the
#                 documentation and/or other materials provided with the distribution.
#               * Neither the name of the JAMF Software, LLC nor the
#                 names of its contributors may be used to endorse or promote products
#                 derived from this software without specific prior written permission.
#
#       THIS SOFTWARE IS PROVIDED BY JAMF SOFTWARE, LLC "AS IS" AND ANY
#       EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#       WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#       DISCLAIMED. IN NO EVENT SHALL JAMF SOFTWARE, LLC BE LIABLE FOR ANY
#       DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#       (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#       LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#       ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#       (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#       SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
####################################################################################################
#
# Description
#
# The purpose of this script is to allow a new individual recovery key to be issued
# if the current key is invalid and the management account is not enabled for FV2,
# or if the machine was encrypted outside of the JSS.
#
# First put a configuration profile for FV2 recovery key redirection in place.
# Ensure keys are being redirected to your JSS.
#
# This script will prompt the user for their password so a new FV2 individual
# recovery key can be issued and redirected to the JSS.
# https://github.com/D8Services/ReissueFVKey_2
#
####################################################################################################
####################################################################################################
#
# D8 Disclaimer
#
# This script has been modified heavily from the original available on Jamf's Github Page
#
# By using this script you are accepting all responsibility and in no way will hold anyone else responsible
# neither the author, Jamf nor D8 Services.
#
# We provide this script as is and offer no support, unless prior agreement has been made.
# 
# https://github.com/D8Services/ReissueFVKey_2
#
#
####################################################################################################
#
# HISTORY
#
# -Created by Sam Fortuna on Sept. 5, 2014
# -Updated by Sam Fortuna on Nov. 18, 2014
# -Added support for 10.10
#   -Updated by Sam Fortuna on June 23, 2015
#       -Properly escapes special characters in user passwords
# -Updated by Bram Cohen on May 27, 2016
# -Pipe FV key and password to /dev/null
# -Updated by Jordan Wisniewski on Dec 5, 2016
# -Removed quotes for 'send {${userPass}}     ' so
# passwords with spaces work.
# -Updated by Shane Brown/Kylie Bareis on Aug 29, 2017
# - Fixed an issue with usernames that contain
# sub-string matches of each other.
# -Updated by Bram Cohen on Jan 3, 2018
# - 10.13 adds a new prompt for username before password in changerecovery
# -Updated by Matt Boyle on July 6, 2018
# - Error handeling, custom Window Lables, Messages and FV2 Icon
# -Updated by David Raabe on July 26, 2018
# - Added Custom Branding to pop up windows
# -Updated by Tomos Tyler on 19 August 2020
# - Added LaunchD process for display Dialog
# - Updated to take user password, encrypt it, create a new account if missing
# - with FV Access (Secure Token) for future use
# - Altered to see if the local Password and details are OK, if so, avoid talking to end user.
####################################################################################################
#
# Parameter 4 = Set organization name in pop up window
# Parameter 5 = Failed Attempts until Stop
# Parameter 6 = Custom text for contact information.
# Parameter 7 = Custom Branding - Defaults to Self Service Icon
# Parameter 8 = optional if 10 , 11 are empty. Salt Keys Required for encyption of userCredentials
# Parameter 9 = optional if 10 , 11 are empty. Phrase Keys Required for encyption of userCredentials
# Parameter 10 = optional Local IT Support loginName
# Parameter 11 = optional Local IT fullName
#
# The keys used in this script can be unique to your site, please understand that these 
# keys must match the keys used during encryption in order to decrypt the password.
# To Create your Salted Key 'openssl rand -hex 8'
# To Create your Phrase Key 'openssl rand -hex 12'
# 

# Icon Settings
selfServiceBrandIcon="/Users/$3/Library/Application Support/com.jamfsoftware.selfservice.mac/Documents/Images/brandingimage.png"
jamfBrandIcon="/Library/Application Support/JAMF/Jamf.app/Contents/Resources/AppIcon.icns"
fileVaultIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FileVaultIcon.icns"

# For Passing FVPrefs to another user
prefFile="/var/db/.encryptedD8.plist"
log_location="/var/log/d8ReissueKey.log"
Version="2.1"
FullScriptName=$(basename "${0}")

#saltKey="063f7f8eb687cde2"
#phraseKey="7d7353d9547a8af1bf81d1be"

ScriptLogging(){
DATE=`date +%Y-%m-%d\ %H:%M:%S`
touch "$log_location"
LOG="$log_location"
echo "$DATE" " $1" >> $LOG
}

# Display version information
echo "********* Running ${FullScriptName} Version ${Version} *********"
ScriptLogging "********* Running ${FullScriptName} Version ${Version} *********"

ScriptLogging "Checking Parameters passed during execution."
if [ ! -z "$4" ]
then
orgName="$4 -"
fi

if [ ! -z "$6" ]
then
haltMsg="$6"
else
haltMsg="Please Contact IT for Further assistance."
ScriptLogging "Missing Halt Message. Please Contact IT for Further assistance."
fi

if [[ ! -z "$7" ]]; then
brandIcon="$7"
elif [[ -f $selfServiceBrandIcon ]]; then
    brandIcon=$selfServiceBrandIcon
elif [[ -f $jamfBrandIcon ]]; then
    brandIcon=$jamfBrandIcon
else
brandIcon=$fileVaultIcon
ScriptLogging "Brand Icon set to ${brandIcon}"
fi

if [[ ! -z "${10}" || ! -z "${11}" ]];then
    localName="${10}"
    localFullName="${11}"
    home="/var/${localName}"
    skipAccountCheck="No"
    ScriptLogging "Account details found for IT User \"$localName\". Account will be checked."
else
    echo "Skipping account check"
    skipAccountCheck="Yes"
    ScriptLogging "No details detected for IT Admin user, skipping account check."
fi

if [[ $skipAccountCheck = "No" ]];then
    if [[ ! -z "${8}" ]];then
        saltKey="${8}"
    else
        haltMsg="Salt Keys Missing, Please Contact IT for Further assistance."
        ScriptLogging "Salt Keys Missing, Please Contact IT for Further assistance."
    fi
    
    if [[ ! -z "${9}" ]];then
        phraseKey="${9}"
    else
        haltMsg="Phrase Keys Missing, Please Contact IT for Further assistance."
        ScriptLogging "Phrase Keys Missing, Please Contact IT for Further assistance."
    fi
fi

## Get the logged in user's name
userName=$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')

## Grab the UUID of the User
userNameUUID=$(dscl . -read /Users/$userName/ GeneratedUID | awk '{print $2}')
currentUID=$(dscl . read /Users/$userName UniqueID | awk '{print $2}')

## Get the OS version
OS=`/usr/bin/sw_vers -productVersion | awk -F. {'print $2'}`

## Counter for Attempts
try=0
if [ ! -z "$5" ];then
    maxTry=$5
else
    maxTry=2
fi

## Check to see if the encryption process is complete
encryptCheck=`fdesetup status`
statusCheck=$(echo "${encryptCheck}" | grep "FileVault is On.")
expectedStatus="FileVault is On."
if [ "${statusCheck}" != "${expectedStatus}" ]; then
    echo "The encryption process has not completed."
    ScriptLogging "The encryption process has not completed."
    echo "${encryptCheck}"
    ScriptLogging "${encryptCheck}"
    exit 4
fi

die() {
launchctl "asuser" "$currentUID" /usr/bin/osascript -e "
display dialog \"${1}\" buttons {\"Ok\"} default button 1 with icon POSIX file \"$brandIcon\"
"
echo "Error: ${1}"
ScriptLogging "Error: ${1}"
exit 1
}

## Function Decrypt Strings
DecryptString() {
    # Usage: ~$ DecryptString "Encrypted String" "Salt" "Passphrase"
echo "${1}" | /usr/bin/openssl enc -aes256 -d -a -A -S "${saltKey}" -k "${phraseKey}"
}

GenerateEncryptedString() {
# Usage ~$ GenerateEncryptedString "String"
echo "${1}" | openssl enc -aes256 -a -A -S "${saltKey}" -k "${phraseKey}"
}

userSummary() {
theResult=$(launchctl "asuser" "$currentUID" /usr/bin/osascript -e "
display dialog \"${1}\" buttons {\"No\",\"OK\"} default button 2 with icon POSIX file \"$brandIcon\"
return button returned of result
")
echo "INFO: User Clicked $theResult in response to ${1}"
ScriptLogging "INFO: User Clicked $theResult in response to ${1}"
}


checkITUser() {
    ScriptLogging "Checking IT defined user \"$localName\" for secure token and password file."
    if id "$localName" >/dev/null 2>&1; then
        echo "Notice: IT Admin user exists, continuing"
        ScriptLogging "Notice: IT Admin user exists, continuing"
        if [[ ! -f ${prefFile} ]];then
            echo "missing prefFile."
            ScriptLogging "Missing LocalUser Pref File. Creating, and populating with encrypted password."
            newPass=`cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
            encryptedString=$(GenerateEncryptedString "${newPass}")
            defaults write "${prefFile}" pkey "${encryptedString}"
            ScriptLogging "Resetting Password for \"${localName}\""
            sysadminctl -resetPasswordFor "${localName}" -password "${newPass}" -adminUser "${userName}" -adminPassword "${userPass}"
        else
            ScriptLogging "Preference File Found for $localName. Decrypting."
            encryptedPass=$(defaults read "${prefFile}" pkey)
            newPass=$(DecryptString "${encryptedPass}")
        fi
        tokenStatus=$(sysadminctl -secureTokenStatus ${localName} 2>&1 | awk '{print$7}')
        if [[ $tokenStatus != "ENABLED" ]];then
            ScriptLogging "Account \"localName\" is missing its secure token, remediating."
            sysadminctl -secureTokenOn "${localName}" -password "${newPass}" -adminUser "${userName}" -adminPassword "${userPass}"
        fi
    else
        # Account Missing Creating
        ScriptLogging "Account Missing, Creating"
        newPass=`cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
        sysadminctl -addUser ${localName} -fullName "${localFullName}" -UID 500 -password ${newPass} -home ${home} -admin -adminUser "${userName}" -adminPassword "${userPass}"
        sysadminctl -secureTokenOn ${localName} -password "${newPass}" -adminUser "${userName}" -adminPassword "${userPass}"
        createhomedir -c 2>&1
        encryptedString=$(GenerateEncryptedString "${newPass}")
        defaults write "${prefFile}" pkey "${encryptedString}"
    fi
    ScriptLogging "Checking Account Token."
    tokenStatus=$(sysadminctl -secureTokenStatus ${localName} 2>&1 | awk '{print$7}')
    if [[ $tokenStatus != "ENABLED" ]];then
        echo "Token assignment failed"
        ScriptLogging "Token assignment failed"
    else
        ScriptLogging "The Account \"${localName}\" has a secure token."
    fi
    ScriptLogging "Checking Account Credentials."
    encryptedPass=$(defaults read "${prefFile}" pkey)
    newPass=$(DecryptString "${encryptedPass}")
    passLocalCheck=$(dscl . -authonly ${localName} ${newPass}; echo $?)
    if [ "$passLocalCheck" -eq 0 ]; then
        echo "Password OK for user \"${localName}\""
        ScriptLogging "Password validation sucessful for user \"${localName}\""
    else
        ScriptLogging "Password failed to authenticate for user \"${localName}\""
        ScriptLogging "Suggest we Erase this user and start again."
        newPass=`cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
        sysadminctl -deleteUser ${localName}
        sysadminctl -addUser ${localName} -fullName "${localFullName}" -UID 500 -password ${newPass} -home ${home} -admin -adminUser "${userName}" -adminPassword "${userPass}"
        sysadminctl -secureTokenOn ${localName} -password "${newPass}" -adminUser "${userName}" -adminPassword "${userPass}"
        createhomedir -c 2>&1
        encryptedString=$(GenerateEncryptedString "${newPass}")
        defaults write "${prefFile}" pkey "${encryptedString}"
    fi
}

passwordRequest() {
ScriptLogging "Requesting \"${userName}\" password."
userPass=$(launchctl "asuser" "$currentUID" /usr/bin/osascript -e "
display dialog \"${1}\" default answer \"\" with hidden answer buttons {\"OK\"} default button 1 with icon POSIX file \"$brandIcon\"
return text returned of result
")
}

passwordPrompt () {
ScriptLogging "Get the logged in user's password via a prompt."
## Get the logged in user's password via a prompt
passDSCLCheck="1"
while [[ "$passDSCLCheck" -ne 0 ]];do
passwordRequest "We will need you to type your current password for ${userName}." "Yes"
passDSCLCheck=$(dscl . -authonly ${userName} ${userPass}; echo $?)
if [ "$passDSCLCheck" -eq 0 ]; then
    echo "Password OK for user \"${userName}\""
    ScriptLogging "Password OK for user \"${userName}\""
else
    userSummary "Password Validation Failed for '${userName}' \nDo you Want to try again?"
    if [[ ${theResult} == "No" ]];then
        die "Password FAILED for user \"${userName}\""
    else
        passDSCLCheck="1"
    fi
fi
done
}

RequestNewKey() {
try=$((try+1))
if [[ $OS -ge 9 ]] &&  [[ $OS -lt 13 ]]; then
## This "expect" block will populate answers for the fdesetup prompts that normally occur while hiding them from output
result=$(expect -c "
log_user 0
spawn fdesetup changerecovery -personal
expect \"Enter a password for '/', or the recovery key:\"
send {${userPass}}   
send \r
log_user 1
expect eof
" >> /dev/null)
elif [[ $OS -ge 13 ]]; then
result=$(expect -c "
log_user 0
spawn fdesetup changerecovery -personal
expect \"Enter the user name:\"
send {${userName}}   
send \r
expect \"Enter a password for '/', or the recovery key:\"
send {${userPass}}   
send \r
log_user 1
expect eof
")
else
echo "OS version not 10.9+ or OS version unrecognized"
ScriptLogging "OS version not 10.9+ or OS version unrecognized"
echo "$(/usr/bin/sw_vers -productVersion)"
ScriptLogging "OS Version is not compatible $(/usr/bin/sw_vers -productVersion)"
die "OS Version is not compatible $(/usr/bin/sw_vers -productVersion)"
fi
}

successAlert () {
launchctl "asuser" "$currentUID" /usr/bin/osascript -e "
on run
display dialog \"\" & return & \"Your FileVault Key was successfully Changed\" with title \"$orgName FileVault Key Reset\" buttons {\"Close\"} default button 1 with icon POSIX file \"$brandIcon\"
end run"
}

errorAlert () {
launchctl "asuser" "$currentUID" /usr/bin/osascript -e "
on run
display dialog \"FileVault Key not Changed\" & return & \"$result\" buttons {\"Cancel\", \"Try Again\"} default button 2 with title \"$orgName FileVault Key Reset\" with icon POSIX file \"$brandIcon\"
end run"
if [ "$?" == "1" ];then
echo "User Canceled"
ScriptLogging "User Canceled after restting FileVault key failed."
exit 0
else
try=$(($try+1))
fi
}

haltAlert () {
launchctl "asuser" "$currentUID" /usr/bin/osascript -e "
on run
display dialog \"FileVault Key not changed\" & return & \"$haltMsg\" buttons {\"Close\"} default button 1 with title \"$orgName FileVault Key Reset\" with icon POSIX file \"$brandIcon\"
end run
"
}

ScriptLogging "********* Starting Main Process *********"
----------------------
if [[ -f "${prefFile}" ]];then
    ScriptLogging "Checking Account Credentials."
    encryptedPass=$(defaults read "${prefFile}" pkey)
    newPass=$(DecryptString "${encryptedPass}")
    passLocalCheck=$(dscl . -authonly ${localName} ${newPass}; echo $?)
    skipUser="100"
    if [ "$passLocalCheck" -eq 0 ]; then
        echo "Password OK for user \"${localName}\""
        ScriptLogging "Password validation successful for user \"${localName}\""
        skipUser="10"
    else
        ScriptLogging "Password failed to authenticate for user \"${localName}\""
        ScriptLogging "Need to Reset the Password for \"${localName}\""
        rm -f "${prefFile}"
        skipUser="0"
    fi
    ScriptLogging "Checking Account Token."
    tokenStatus=$(sysadminctl -secureTokenStatus ${localName} 2>&1 | awk '{print$7}')
    if [[ $tokenStatus != "ENABLED" ]];then
        echo "Token assignment failed"
        ScriptLogging "Token assignment check failed"
    else
        ScriptLogging "The Account \"${localName}\" has a secure token."
        if [[ "${skipUser}" -eq "0" ]];then
            skipUser="0"
            ScriptLogging "Identified error in Password Validation."
        else
            skipUser="10"
        fi
    fi
else
    ## This first user check sees if the logged in account is already authorized with FileVault 2
    ScriptLogging "Preference File is missing, reverting to checking the end user."
userCheck=`fdesetup list | awk -v usrN="$userNameUUID" -F, 'match($0, usrN) {print $1}'`
    skipUser="0"
    if [ "${userCheck}" != "${userName}" ]; then
        echo "This user is not a FileVault 2 enabled user."
        ScriptLogging "This user is not a FileVault 2 enabled user."
        exit 3
    fi
fi
---------------------
while true
do
    if [[ "${skipUser}" -ge "1" ]];then
        ScriptLogging "Sucessfully tested local Admin. Ignoring end user."
        userName=${localName}
        userPass=${newPass}
    else
        ScriptLogging "Password or account values error, challenging end user."
        passwordPrompt
        if [[ ${skipAccountCheck} == "No" ]];then
            checkITUser
        fi
    fi
    RequestNewKey
    if [[ $result = *"Error"* ]];then
        ScriptLogging "Error Changing Key"
        echo "Error Changing Key"
        if [ $try -ge $maxTry ];then
            haltAlert
            echo "Quitting.. Too Many failures"
            ScriptLogging "Quitting.. Too Many failures"
            echo "********* Finished ${FullScriptName} Version ${Version} *********"
            ScriptLogging "********* Finished ${FullScriptName} Version ${Version} *********"
            exit 0
        else
            echo $result
            ScriptLogging $result
            errorAlert
        fi
    else
        echo "Successfully Changed FV2 Key"
        ScriptLogging "Successfully Changed FV2 Key"
        successAlert
        echo "********* Finished ${FullScriptName} Version ${Version} *********"
        ScriptLogging "********* Finished ${FullScriptName} Version ${Version} *********"
        ScriptLogging ""
        exit 0
    fi
done


