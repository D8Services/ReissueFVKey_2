# ReissueFVKey_2

Our version of Jamf's Reissuekey.sh script https://github.com/jamf/FileVault2_Scripts/blob/master/reissueKey.sh

The idea is to create a new FileVault2 (FV2) recovery key, however as we now have automatic device enrollment we can not guranatee that our IT user on the Mac has a secure token, leaving our end user as the FileVault2 manager, even if they have a standard account.  

Rather than touch each computer we can challenge the end user to enter their FileVault2 password and re-issue a key on their behalf, however, we can also leverage this password to ensure our IT Managed user has a secure token. This simplifies our reliance on the end user.  

As part of the D8 Services [RandomAccountPassword](https://github.com/D8Services/RandomAccountPassword) process we have created a branch that will NOT delete the end user, instead we have branched this to a non destructive script which can be used for the ongoing randomisation of the accounts password [See Here](https://github.com/D8Services/RandomAccountPassword/tree/DoNotEraseUser).  


