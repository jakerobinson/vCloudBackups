﻿##############################################################
# Title: vCloud Backups Module
# Author: Jake Robinson
# Version: 1.0
# More Info: https://github.com/jakerobinson/vCloudBackups
#
# "Better than a snapshot..."
#
##############################################################

function Backup-CIVApp
{   

<#
    .SYNOPSIS
        Creates a hot-clone/backup of a vApp to the same VDC.
    .DESCRIPTION
        Creates a hot-clone/backup of a vApp to the same VDC.
    .EXAMPLE
        Get-CIVapp "MyVApp" | Backup-CIVApp
    .PARAMETER vapp
        A vApp returned from PowerCLI command: Get-CIVapp
    .PARAMETER retain
        Number of vApp backups to retain. This will remove the oldest backups outside of the number to retain.
#>
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="High")]
    param
    (
        [parameter(Position=0,ValueFromPipeline=$true)]
        $vapp,

        # max to keep
        [parameter(Position=1,mandatory=$true,HelpMessage="How many copies to retain?")]
        $retain
    )
    PROCESS
    {
        if ($PSCmdlet.ShouldProcess($vapp.name))
        {
            $sourceVapp = Get-CIView -id $vapp.id
            $vappSearch = Search-Cloud -QueryType VApp -Name $vapp.name -Property vdc,id
                        
            $previousBackups = Get-CIVApp -name "Backup-$($vapp.name)*"
            if ($previousBackups.count -ge $retain)
            {
                # delete the oldest one
                # Metadata or name?
                # Will have to change the code for 5.1 if we go with metadata...

                $backupTable = @()
                $numberToRemove = $previousBackups.count - $retain
                foreach ($previousBackup in $previousBackups)
                {
                    $previousBackupDate = get-date $previousBackup.name.split("-")[-1]
                    $row = New-Object PSObject
                    Add-Member -MemberType NoteProperty -Name name -Value $previousBackup.name -InputObject $row
                    Add-Member -MemberType NoteProperty -Name date -Value $previousBackupDate -InputObject $row
                    Add-Member -MemberType NoteProperty -Name id -Value $previousbackup.id -InputObject $row
                    $backupTable += $row   
                }

                $toBeRemoved = $backupTable | Sort-Object date | select -First $numberToRemove
                Write-Verbose "Removing old backups..."
                $toBeRemoved | %{Get-Task -id ((Get-CIView -Id $_.id).Delete_Task()).id | Wait-Task}
            
            }

            # -viewlevel user (workaround for bug in PowerCLI beta build)
            $vdc = Get-CIView -Id $vappSearch.Vdc -ViewLevel User

            $cloneParams = new-object VMware.VimAutomation.Cloud.Views.CloneVAppParams
            $instParams = new-object VMware.VimAutomation.Cloud.Views.InstantiationParams

            # Remove NetworkSection
            # Need to remove NATs out of this as well due to PowerCLI bug
            # So Ugly...Total Hack. :(
            # This might be fixed in 5.1 R2. Need to test.
            $instParams.section = $sourceVapp.Section | where {$_ -isnot [VMware.VimAutomation.Cloud.Views.OvfNetworkSection]}
            $instparams.section[2].networkconfig | %{$_.configuration.features = $_.configuration.features | where {$_ -isnot [VMware.VimAutomation.Cloud.Views.NatService]}}

            $cloneParams.InstantiationParams = $instParams
            $cloneParams.Source = $sourceVapp.Href
            $cloneParams.Name = "Backup-" + $vapp.name + "-" + (get-date).DateTime

            # Testing Get-Task with CloneVApp()
            Get-task -id ($vdc.CloneVApp($cloneParams)).Tasks.Task[0].id | Wait-Task
        }
    }
}

function Backup-CIVM
{

<#
    .SYNOPSIS
        Creates a hot-clone/backup of a VM to a vApp in the same VDC.
    .DESCRIPTION
        Creates a hot-clone/backup of a VM to a vApp in the same VDC.
    .EXAMPLE
        Get-CIVApp "MyVApp" | Get-CIVM "MyVM" | Backup-CIVM
    .PARAMETER vm
        A vCloud VM returned from PowerCLI command: Get-CIVM
    .PARAMETER retain
        Number of VM backups to retain. This will remove the oldest backups outside of the number to retain.
#>
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="High")]
    param
    (
        [parameter(Position=0,mandatory=$true,ValueFromPipeline=$true)]
        $vm,
        
        # max to keep
        [parameter(Position=1,mandatory=$true,HelpMessage="How many copies to retain?")]
        $retain

        
    )
    BEGIN
    {
        # Check for Backups vApp
        $backupVAppName = "Backups"
        $backups = Search-cloud -QueryType VApp -Name $backupVAppName
    }
    PROCESS
    {
        $vdc = $vm.OrgVdc
        $vapp = $vm.vapp

        # Don't backup backups... Is there a better way to handle?
        # I am worried about wildcards like Get-CIVM Foo* | Backup-CIVM
        # I suppose the only applies if the vApp also starts with foo,
        # since we are using the vApp name in the backup as well...
        if($vapp.name -eq $backupVAppName){return}
        if($vapp.name -match "Backup-"){return}
        
        $source = New-Object VMware.VimAutomation.Cloud.Views.SourcedCompositionItemParam
        $source.Source = $vm.href
        $source.Source.Name = $vapp.name + "-" + $vm.Name + "-" + (get-date).DateTime

        $source.InstantiationParams = New-Object VMware.VimAutomation.Cloud.Views.InstantiationParams
        $source.InstantiationParams.Section = $vm.ExtensionData.Section | where {$_ -isnot [VMware.VimAutomation.Cloud.Views.NetworkConnectionSection]}
        $source.InstantiationParams.Section = $source.InstantiationParams.Section | where {$_ -isnot [VMware.VimAutomation.Cloud.Views.OvfProductSection]}
        $source.InstantiationParams.Section = $source.InstantiationParams.Section | where {$_ -isnot [VMware.VimAutomation.Cloud.Views.RuntimeInfoSection]}
        # Remove Guest Customization section due to PowerCLI bug
        $source.InstantiationParams.Section = $source.InstantiationParams.Section | where {$_ -isnot [VMware.VimAutomation.Cloud.Views.GuestCustomizationSection]}
        $source.InstantiationParams.Section[0].item = $source.InstantiationParams.Section[0].item | where {$_.resourcetype.value -ne "10"}

        $instParams = New-Object VMware.VimAutomation.Cloud.Views.InstantiationParams
        $instParams.Section = $Vapp.extensiondata.Section | where {$_ -isnot [VMware.VimAutomation.Cloud.Views.OvfNetworkSection]}
        $instParams.Section = $instParams.Section | where {$_ -isnot [VMware.VimAutomation.Cloud.Views.OvfStartupSection]}
        $instParams.Section = $instParams.Section | where {$_ -isnot [VMware.VimAutomation.Cloud.Views.NetworkConfigSection]}
        #$instParams.section[1].networkconfig | %{$_.configuration.features = $_.configuration.features | where {$_ -isnot [VMware.VimAutomation.Cloud.Views.NatService]}}

        if ($PSCmdlet.ShouldProcess($vm.name))
        {
            if($backups)
            {

                $backupVApp = $backups | Get-CIView
                $previousBackups = $backupVApp.children.vm | where {$_.name -match "$($vapp.name)-$($vm.name)*"}
                if ($previousBackups.count -ge $retain)
                {
                    # delete the oldest one
                    # Metadata or name?
                    # Will have to change the code for 5.1 if we go with metadata...

                    $backupTable = @()
                    $numberToRemove = $previousBackups.count - $retain
                    foreach ($previousBackup in $previousBackups)
                    {
                        $previousBackupDate = get-date $previousBackup.name.split("-")[-1]
                        $row = New-Object PSObject
                        Add-Member -MemberType NoteProperty -Name name -Value $previousBackup.name -InputObject $row
                        Add-Member -MemberType NoteProperty -Name date -Value $previousBackupDate -InputObject $row
                        Add-Member -MemberType NoteProperty -Name id -Value $previousbackup.id -InputObject $row
                        $backupTable += $row   
                    }

                    $toBeRemoved = $backupTable | Sort-Object date | select -First $numberToRemove
                    Write-Verbose "Removing old backups..."
                    $toBeRemoved | %{Get-Task -id ((Get-CIView -Id $_.id).Delete_Task()).id | Wait-Task}
            
                }

                $recompose = New-Object VMware.VimAutomation.Cloud.Views.RecomposeVAppParams
                $recompose.SourcedItem = $source
                $recompose.InstantiationParams = $instParams

                Write-Verbose "Backing up VM..."
                Get-Task -id ($backupVApp.RecomposeVApp_Task($recompose)).id | Wait-Task

                }
            else
            {

                $compose = New-Object VMware.VimAutomation.Cloud.Views.ComposeVAppParams
                $compose.name = $backupVAppName
                $compose.SourcedItem = $source
                $compose.InstantiationParams = $instParams
                Write-Verbose "Creating $backupVAppName vApp and Backing up VM..."
                Get-Task -id ($vdc.ExtensionData.ComposeVApp($compose)).tasks.task[0].id | Wait-task
            }
        }
    }
}

function Save-VCloudBackupConfig
{
    param
    (
        $credential = (Get-Credential),
        $vcloudHost = (Read-Host -Prompt "Enter the vCloud Hostname"),
        $vcloudOrg = (Read-host -Prompt "Enter your vCloud Org")
    )

    $configObject = New-Object PSObject
    Add-Member -Name username -value $credential.UserName -InputObject $configObject -MemberType NoteProperty
    Add-Member -Name password -Value ($credential.Password | ConvertFrom-SecureString) -InputObject $configObject -MemberType NoteProperty
    Add-Member -Name vcloud -Value $vcloudHost -InputObject $configObject -MemberType NoteProperty
    Add-Member -Name org -Value $vcloudOrg -InputObject $configObject -MemberType NoteProperty

    $configObject | Export-Csv vCloudBackupConfig.csv
}

function Import-VCloudBackupConfig
{
    param
    (
        $configPath = $null
    )

    If (Test-Path ($configPath + "\vcloudBackupConfig.csv"))
    {
        $configObject = Import-Csv ($configPath + "\vCloudBackupConfig.csv")
        return $configObject
    }
    else
    {
        Write-Error ("Cannot find file: " + $configPath + "\vCloudBackupConfig.csv")
    }
}