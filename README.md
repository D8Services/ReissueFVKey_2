# ReissueFVKey_2

Our version of Jamf's Reissuekey.sh script [Jamf/FileVault2_Scripts](https://github.com/jamf/FileVault2_Scripts/blob/master/reissueKey.sh)  

The idea is to create a new FileVault2 (FV2) recovery key, however as we now have automatic device enrollment we can not guranatee that our IT user on the Mac has a secure token, leaving our end user as the FileVault2 manager, even if they have a standard account.  

Rather than touch each computer we can challenge the end user to enter their FileVault2 password and re-issue a key on their behalf, however, we can also leverage this password to ensure our IT Managed user has a secure token. This simplifies our reliance on the end user.  

As part of the D8 Services [RandomAccountPassword](https://github.com/D8Services/RandomAccountPassword) process we have created a branch that will NOT delete the end user, instead we have branched this to a non destructive script which can be used for the ongoing randomisation of the accounts password [See Here](https://github.com/D8Services/RandomAccountPassword/tree/DoNotEraseUser).  

## Parameters  

Parameter 4 = Set organization name in pop up window  
Parameter 5 = Failed Attempts until Stop  
Parameter 6 = Custom text for contact information.  
Parameter 7 = Custom Branding - Defaults to Self Service Icon  
Parameter 8 = optional if 10 , 11 are empty. Salt Keys Required for encyption of userCredentials  
Parameter 9 = optional if 10 , 11 are empty. Phrase Keys Required for encyption of userCredentials  
Parameter 10 = optional Local IT Support loginName  
Parameter 11 = optional Local IT fullName  

## Salted Keys
The keys used in this script can be unique to your site, please understand that these keys must match the keys used during encryption in order to decrypt the password.  

saltKey  
```openssl rand -hex 8```  
phraseKey  
```openssl rand -hex 12```

## Jamf Policy Setup  
### Name        
- ReIssue FV2 Key  
### Frequency   
- Once every week  
### Trigger     
- Reoccuring check-in  
### Scope       
- All Computers  
### Payload     
- ReIssueKeyFV2.sh  
  - Parameter 4 = Set organization name in pop up window e.g. D8 Services  
  - Parameter 5 = Failed Attempts until Stop e.g. 5  
  - Parameter 6 = Custom text for contact information.  
  - Parameter 7 = Custom Branding - Defaults to Self Service Icon  
  - Parameter 8 = optional if 10 , 11 are empty. Salt Keys Required for encyption of userCredentials  
  - Parameter 9 = optional if 10 , 11 are empty. Phrase Keys Required for encyption of userCredentials  
  - Parameter 10 = optional Local IT Support loginName e.g. itadmin  
  - Parameter 11 = optional Local IT fullName e.g. IT Administrator    
- Update Inventory  

## Further Automated Randomisation
We referred above to our Random Password workflow, for more information, [See RandomPasswordv3.sh](https://github.com/D8Services/RandomAccountPassword/tree/DoNotEraseUser)  

Collecting Password and store it in in ClearText within Jamf (CAUTION this could violate your corporate password policy) [See RandomPassEA_v3.sh](https://github.com/D8Services/RandomAccountPassword/tree/DoNotEraseUser)
