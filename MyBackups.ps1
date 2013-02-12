# Import Backup module, configs and connect to vCloud!
# This assumes the module is in the same folder
Import-Module .\vCloudBackups.psm1

$myVCloudConfig = Import-VCloudBackupConfig $configPath
$credential = New-Object System.Management.Automation.PSCredential($myVCloudConfig.username,($MyVCloudCOnfig.password | ConvertTo-SecureString))

Connect-CIServer $MyVCloudConfig.vcloud -org $MyVCloudCOnfig.org -Credential $credential

# Do backups here!
# See https://github.com/jakerobinson/vCloudBackups for command examples
# or run:
# Get-Help Backup-CIVM -full
# Get-Help Backup-CIVApp -full
# in Powershell

# Backup VApp Example
# Retain 1 copy, and don't prompt for confirmation
Get-CIVApp ts | Backup-CIVApp -retain 1 -Confirm:$false

# Backup VM Example
# Retain 3 copies, and don't prompt for confirmation
Get-CIVM WebServer | Backup-CIVM -retain 3 -Confirm:$false


# Disconnect
Disconnect-CIServer * -Confirm:$false