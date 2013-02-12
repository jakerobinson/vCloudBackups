# vCloud vApp and VM Backups

## Introduction

vCloudBackups provides a way to hot clone VMs and vApps running in a Virtual Datacenter for the purpose of local backups. 

This release should work with any vCloud Provider running 1.5 or 5.1.

## Description

vCloud Backups takes a running vApp or Virtual Machine and makes a hot clone of the source.

* VApp backups are cloned to another VApp named *Backup-<VApp Name>-<Backup Date and Time>*
* VM backups are cloned to a VApp called *Backups* and are named *<Source VApp Name>-<VM Name>-<Backup Date and Time>

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

To backup a VM:

1. Connect to your vCloud Organization.

```Powershell
Connect-CIServer vcloud.example.com -org MyOrganization
```

2. Get the VM, and pipe the object to Backup-CIVM and specify a number of backups to retain.

```Powershell

Get-CIVM "MyVM" | Backup-CIVM -retain 3

```
*Note:*VM Backups are currently done in serial. No parallel VM backup at this time.


If you have multiple VMs of the same name in your Virtual Datacenter, you can specify which VM by first selecting the vApp

```Powershell

Get-CIVApp "MyVApp" | Get-CIVM "MyVM" | Backup-CIVM -retain 3

```

## Help

For help, find me on Twitter: [@jakerobinson](http://twitter.com/jakerobinson)

Please report any issues using the Github issues for this project.



