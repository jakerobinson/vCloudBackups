# vCloud vApp and VM Backups

## Introduction

vCloudBackups provides a way to hot clone VMs and vApps running in a Virtual Datacenter for the purpose of local backups. 

This release should work with any vCloud Provider running 1.5 or 5.1.

## Description

vCloud Backups takes a running vApp or Virtual Machine and makes a hot clone of the source.

* VApp backups are cloned to another VApp named *Backup-\<VApp Name\>-\<Backup Date and Time\>*
* VM backups are cloned to a VApp called *Backups* and are named *\<Source VApp Name\>-\<VM Name\>-\<Backup Date and Time\>*

Restoring VMs and vApps must currently be done through the UI (or through the API if one was so inclined to automate restores)

## Requirements

* Powershell 2 or higher
* VMware PowerCLI (for admins or tenants) 5.1 or higher downloadable for free [here.](http://vmware.com/go/powercli)

## Usage

To use vCloudBackups, open Powershell (or PowerCLI) and import the module:

```Powershell
Import-Module vCloudBackups.psm1
```

The following (cmdlets) are now available:

* Backup-CIVM
* Backup-CIVApp
* Save-VCloudBackupConfig
* Import-VCloudBackupConfig

To backup a VM:

1. Connect to your vCloud Organization. This will prompt for credentials.
   ```Powershell
   Connect-CIServer vcloud.example.com -org MyOrganization
   ```

2. Get the VM, and pipe the object to Backup-CIVM and specify a number of backups to retain.

```Powershell
Get-CIVM "MyVM" | Backup-CIVM -retain 3
```
**Note:** VM Backups are currently done in serial.

If you have multiple VMs of the same name in your Virtual Datacenter, you can specify which VM by first selecting the vApp

```Powershell
Get-CIVApp "MyVApp" | Get-CIVM "MyVM" | Backup-CIVM -retain 3
```

## Windows Scheduled Task

Scheduling backups can be done using task scheduler on any Windows machine that meets the Powershell requirements and has Internet Access.

### Files Required:

* MyBackups.ps1 (included in this Repo)
* vCloudBackupConfig.csv (generated by Save-VCloudBackupConfig)
* vCloudBackups.psm1 (The module itself)

### Setup:

1. It is recommended you save all files in a single folder in this version.

2. Login as the user who the scheduled task will be running as.

3. Open Powershell and change your folder to where the vCloudBackup files are located.

4. Run the following:

   ```Powershell
   Import-Module .\vCloudBackups.psm1
    Save-VCloudBackupConfig
   ```
5. Enter your username and password in the dialog box.

6. Enter the vCloud hostname and your Org in the Powershell console.

7. The configuration will be saved in a CSV file in the folder as vCloudBackupConfig.csv.

8. Open Windows Task Scheduler.

9. Create a new task ...

10. ...TBD



## Help

For help, find me on Twitter: [@jakerobinson](http://twitter.com/jakerobinson)

Please report any issues using the Github issues for this project.



