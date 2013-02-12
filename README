# vCloud vApp and VM Backups

## Introduction

vCloudBackups provides a way to hot clone VMs and vApps running in a Virtual Datacenter for the purpose of local backups. 

This release should work with any vCloud Provider running 1.5 or 5.1.

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

To backup a VM, get the VM, and pipe the object to Backup-CIVM and specify a number of backups to retain

```Powershell

Get-CIVM "MyVM" | Backup-CIVM -retain 3

```

If you have multiple VMs of the same name in your Virtual Datacenter, you can specify which VM by first selecting the vApp

```Powershell

Get-CIVApp "MyVApp" | Get-CIVM "MyVM" | Backup-CIVM -retain 3

```

## Help

For help, find me on Twitter: [@jakerobinson](http://twitter.com/jakerobinson)

Please report any issues using the Github issues for this project.



