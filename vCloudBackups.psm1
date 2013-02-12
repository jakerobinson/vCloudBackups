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
        $sourceVapp = Get-CIView -id $vapp.id
        $vappSearch = Search-Cloud -QueryType VApp -Name $vapp.name -Property vdc,id
        
        # -viewlevel user (workaround for bug in PowerCLI beta build)
        $vdc = Get-CIView -Id $vappSearch.Vdc -ViewLevel User

        $cloneParams = new-object VMware.VimAutomation.Cloud.Views.CloneVAppParams
        $instParams = new-object VMware.VimAutomation.Cloud.Views.InstantiationParams

        # Remove NetworkSection
        # Need to remove NATs out of this as well due to PowerCLI bug
        # So Ugly...Total Hack. :(
        $instParams.section = $sourceVapp.Section | where {$_ -isnot [VMware.VimAutomation.Cloud.Views.OvfNetworkSection]}
        $instparams.section[2].networkconfig | %{$_.configuration.features = $_.configuration.features | where {$_ -isnot [VMware.VimAutomation.Cloud.Views.NatService]}}

        $cloneParams.InstantiationParams = $instParams
        $cloneParams.Source = $sourceVapp.Href
        $cloneParams.Name = "Backup-" + $vapp.name + "-" + (get-date).DateTime

        $vdc.CloneVApp($cloneParams)
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


        
        $source = New-Object VMware.VimAutomation.Cloud.Views.SourcedCompositionItemParam
        $source.Source = $vm.href
        $source.Source.Name = $vapp.name + "-" + $vm.Name + "-" + (get-date).DateTime

        $source.InstantiationParams = New-Object VMware.VimAutomation.Cloud.Views.InstantiationParams
        $source.InstantiationParams.Section = $vm.ExtensionData.Section | where {$_ -isnot [VMware.VimAutomation.Cloud.Views.NetworkConnectionSection]}
        $source.InstantiationParams.Section = $source.InstantiationParams.Section | where {$_ -isnot [VMware.VimAutomation.Cloud.Views.OvfProductSection]}
        $source.InstantiationParams.Section = $source.InstantiationParams.Section | where {$_ -isnot [VMware.VimAutomation.Cloud.Views.RuntimeInfoSection]}
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

                $vdc.ExtensionData.ComposeVApp($compose)

            }
        }
    }
}
