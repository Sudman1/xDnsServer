$script:dscModuleName = 'DnsServerDsc'
$script:dscResourceName = 'DSC_DnsServerADZone'

function Invoke-TestSetup
{
    try
    {
        Import-Module -Name DscResource.Test -Force -ErrorAction 'Stop'
    }
    catch [System.IO.FileNotFoundException]
    {
        throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -Tasks build" first.'
    }

    $script:testEnvironment = Initialize-TestEnvironment `
        -DSCModuleName $script:dscModuleName `
        -DSCResourceName $script:dscResourceName `
        -ResourceType 'Mof' `
        -TestType 'Unit'

    Import-Module (Join-Path -Path $PSScriptRoot -ChildPath 'Stubs\DnsServer.psm1') -Force
}

function Invoke-TestCleanup
{
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment
}

Invoke-TestSetup

try
{
    InModuleScope $script:dscResourceName {
        #region Pester Test Initialization
        $testZoneName = 'example.com'
        $testDynamicUpdate = 'Secure'
        $testReplicationScope = 'Domain'
        $testComputerName = 'dnsserver.local'
        $testCredential = New-Object System.Management.Automation.PSCredential 'DummyUser', (ConvertTo-SecureString 'DummyPassword' -AsPlainText -Force)
        $testDirectoryPartitionName = "DomainDnsZones.$testZoneName"
        $testParams = @{
            Name    = $testZoneName
            Verbose = $true
        }

        $fakeDnsADZone = [PSCustomObject] @{
            DistinguishedName      = $null
            ZoneName               = $testZoneName
            ZoneType               = 'Primary'
            DynamicUpdate          = $testDynamicUpdate
            ReplicationScope       = $testReplicationScope
            DirectoryPartitionName = $testDirectoryPartitionName
            ZoneFile               = $null
        }

        $fakePresentTargetResource = @{
            Name                   = $testZoneName
            DynamicUpdate          = $testDynamicUpdate
            ReplicationScope       = $testReplicationScope
            DirectoryPartitionName = $testDirectoryPartitionName
            Ensure                 = 'Present'
        }

        $fakeAbsentTargetResource = @{ Ensure = 'Absent' }
        #endregion

        #region Function Get-TargetResource
        Describe 'DSC_DnsServerADZone\Get-TargetResource' {
            Mock -CommandName 'Assert-Module'

            It 'Returns a "System.Collections.Hashtable" object type with schema properties' {
                Mock -CommandName Get-DnsServerZone -MockWith { return $fakeDnsADZone }
                $targetResource = Get-TargetResource @testParams -ReplicationScope $testReplicationScope
                $targetResource -is [System.Collections.Hashtable] | Should Be $true

                $schemaFields = @('Name', 'DynamicUpdate', 'ReplicationScope', 'DirectoryPartitionName', 'Ensure')
                ($Null -eq ($targetResource.Keys.GetEnumerator() | Where-Object -FilterScript { $schemaFields -notcontains $_ })) | Should Be $true
            }

            It 'Returns "Present" when DNS zone exists and "Ensure" = "Present"' {
                Mock -CommandName Get-DnsServerZone -MockWith { return $fakeDnsADZone }
                $targetResource = Get-TargetResource @testParams -ReplicationScope $testReplicationScope
                $targetResource.Ensure | Should Be 'Present'
            }

            It 'Returns "Absent" when DNS zone does not exists and "Ensure" = "Present"' {
                Mock -CommandName Get-DnsServerZone
                $targetResource = Get-TargetResource @testParams -ReplicationScope $testReplicationScope
                $targetResource.Ensure | Should Be 'Absent'
            }

            It 'Returns "Present" when DNS zone exists and "Ensure" = "Absent"' {
                Mock -CommandName Get-DnsServerZone -MockWith { return $fakeDnsADZone }
                $targetResource = Get-TargetResource @testParams -ReplicationScope $testReplicationScope -Ensure Absent
                $targetResource.Ensure | Should Be 'Present'
            }

            It 'Returns "Absent" when DNS zone does not exist and "Ensure" = "Absent"' {
                Mock -CommandName Get-DnsServerZone
                $targetResource = Get-TargetResource @testParams -ReplicationScope $testReplicationScope -Ensure Absent
                $targetResource.Ensure | Should Be 'Absent'
            }

            Context 'When a computer name is not passed' {
                BeforeAll {
                    Mock -CommandName New-CimSession
                    Mock -CommandName Remove-CimSession
                }

                It 'Should not call New-CimSession' {
                    Get-TargetResource @testParams -ReplicationScope $testReplicationScope
                    Assert-MockCalled -CommandName New-CimSession -Scope It -Times 0 -Exactly
                }

                It 'Should not call Remove-CimSession' {
                    Get-TargetResource @testParams -ReplicationScope $testReplicationScope
                    Assert-MockCalled -CommandName Remove-CimSession -Scope It -Times 0 -Exactly
                }

                Context 'When credential is passed' {
                    It 'Should throw an exception indicating a computername must also be passed' {
                        $withCredentialsParameter = $testParams + @{
                            Credential = $testCredential
                        }
                        { Get-TargetResource @withCredentialsParameter -ReplicationScope $testReplicationScope } | Should -Throw $LocalizedData.CredentialRequiresComputerNameMessage
                    }
                }
            }

            Context 'When a computer name is passed' {
                BeforeAll {
                    Mock -CommandName New-CimSession -MockWith { New-MockObject -Type Microsoft.Management.Infrastructure.CimSession }
                    Mock -CommandName Remove-CimSession
                }

                It 'Should call New-CimSession' {
                    $withComputerNameParameter = $testParams + @{
                        ComputerName = $testComputerName
                    }
                    Get-TargetResource @withComputerNameParameter -ReplicationScope $testReplicationScope
                    Assert-MockCalled -CommandName New-CimSession -ParameterFilter { $computername -eq $withComputerNameParameter.ComputerName } -Scope It -Times 1 -Exactly
                }
                It 'Should call Remove-CimSession' {
                    $withComputerNameParameter = $testParams + @{
                        ComputerName = $testComputerName
                    }
                    Get-TargetResource @withComputerNameParameter -ReplicationScope $testReplicationScope
                    Assert-MockCalled -CommandName Remove-CimSession -Scope It -Times 1 -Exactly
                }
                Context 'When credentials are passed' {
                    BeforeAll {
                        Mock -CommandName Get-DnsServerZone
                        Mock -CommandName New-CimSession -MockWith { New-MockObject -Type Microsoft.Management.Infrastructure.CimSession }
                        Mock -CommandName Remove-CimSession
                    }

                    It 'Should call New-CimSession' {
                        $withCredentialsAndComputerParameter = $testParams + @{
                            ComputerName = $testComputerName
                            Credential   = $testCredential
                        }

                        { Get-TargetResource @withCredentialsAndComputerParameter -ReplicationScope $testReplicationScope } | Should -Not -Throw

                        Assert-MockCalled -CommandName New-CimSession -ParameterFilter {
                            $ComputerName -eq $withCredentialsAndComputerParameter.ComputerName `
                            -and $credential -eq $withCredentialsAndComputerParameter.Credential
                        } -Scope It -Times 1 -Exactly

                        # Regression test for issue https://github.com/PowerShell/DnsServerDsc/issues/79.
                        Assert-MockCalled -CommandName Get-DnsServerZone -ParameterFilter {
                            $Name -eq $withCredentialsAndComputerParameter.Name
                        }
                    }

                    It 'Should call Remove-CimSession' {
                        $withCredentialsAndComputerParameter = $testParams + @{
                            ComputerName = $testComputerName
                            Credential   = $testCredential
                        }

                        Get-TargetResource @withCredentialsAndComputerParameter -ReplicationScope $testReplicationScope

                        Assert-MockCalled -CommandName Remove-CimSession -Scope It -Times 1 -Exactly
                    }
                }
            }
        }
        #endregion


        #region Function Test-TargetResource
        Describe 'DSC_DnsServerADZone\Test-TargetResource' {
            It 'Returns a "System.Boolean" object type' {
                Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource }
                $targetResource = Test-TargetResource @testParams -ReplicationScope $testReplicationScope
                $targetResource -is [System.Boolean] | Should Be $true
            }

            It 'Passes when DNS zone exists and "Ensure" = "Present"' {
                Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource }
                Test-TargetResource @testParams -Ensure Present -ReplicationScope $testReplicationScope | Should Be $true
            }

            It 'Passes when DNS zone does not exist and "Ensure" = "Absent"' {
                Mock -CommandName Get-TargetResource
                Test-TargetResource @testParams -Ensure Absent -ReplicationScope $testReplicationScope | Should Be $true
            }

            It 'Passes when DNS zone "DynamicUpdate" is correct' {
                Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource }
                Test-TargetResource @testParams -Ensure Present -ReplicationScope $testReplicationScope -DynamicUpdate $testDynamicUpdate | Should Be $true
            }

            It 'Passes when DNS zone "ReplicationScope" is correct' {
                Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource }
                Test-TargetResource @testParams -Ensure Present -ReplicationScope $testReplicationScope | Should Be $true
            }

            It 'Passes when DNS zone "DirectoryPartitionName" is correct' {
                Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource }
                Test-TargetResource @testParams -Ensure Present -ReplicationScope $testReplicationScope -DirectoryPartitionName $testDirectoryPartitionName | Should Be $true
            }

            It 'Fails when DNS zone exists and "Ensure" = "Absent"' {
                Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource }
                Test-TargetResource @testParams -Ensure Absent -ReplicationScope $testReplicationScope | Should Be $false
            }

            It 'Fails when DNS zone does not exist and "Ensure" = "Present"' {
                Mock -CommandName Get-TargetResource
                Test-TargetResource @testParams -Ensure Present -ReplicationScope $testReplicationScope | Should Be $false
            }

            It 'Fails when DNS zone "DynamicUpdate" is incorrect' {
                Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource }
                Test-TargetResource @testParams -Ensure Present -ReplicationScope $testReplicationScope -DynamicUpdate 'NonSecureAndSecure' | Should Be $false
            }

            It 'Fails when DNS zone "ReplicationScope" is incorrect' {
                Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource }
                Test-TargetResource @testParams -Ensure Present -ReplicationScope 'Forest' | Should Be $false
            }

            It 'Fails when DNS zone "DirectoryPartitionName" is incorrect' {
                Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource }
                Test-TargetResource @testParams -Ensure Present -ReplicationScope $testReplicationScope -DirectoryPartitionName 'IncorrectDirectoryPartitionName' | Should Be $false
            }
        }
        #endregion


        #region Function Set-TargetResource
        Describe 'DSC_DnsServerADZone\Set-TargetResource' {
            Mock -CommandName Assert-Module

            It 'Calls "Add-DnsServerPrimaryZone" when DNS zone does not exist and "Ensure" = "Present"' {
                Mock -CommandName Get-TargetResource -MockWith { return $fakeAbsentTargetResource }
                Mock -CommandName Add-DnsServerPrimaryZone -ParameterFilter { $Name -eq $testZoneName }
                Set-TargetResource @testParams -Ensure Present -ReplicationScope $testReplicationScope -DynamicUpdate $testDynamicUpdate
                Assert-MockCalled -CommandName Add-DnsServerPrimaryZone -ParameterFilter { $Name -eq $testZoneName } -Scope It
            }

            It 'Calls "Remove-DnsServerZone" when DNS zone does exist and "Ensure" = "Absent"' {
                Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource }
                Mock -CommandName Remove-DnsServerZone
                Set-TargetResource @testParams -Ensure Absent -ReplicationScope $testReplicationScope -DynamicUpdate $testDynamicUpdate
                Assert-MockCalled -CommandName Remove-DnsServerZone -Scope It
            }

            It 'Calls "Set-DnsServerPrimaryZone" when DNS zone "DynamicUpdate" is incorrect' {
                Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource }
                Mock -CommandName Set-DnsServerPrimaryZone -ParameterFilter { $DynamicUpdate -eq 'NonSecureAndSecure' }
                Set-TargetResource @testParams -Ensure Present -ReplicationScope $testReplicationScope -DynamicUpdate 'NonSecureAndSecure'
                Assert-MockCalled -CommandName Set-DnsServerPrimaryZone -ParameterFilter { $DynamicUpdate -eq 'NonSecureAndSecure' } -Scope It
            }

            It 'Calls "Set-DnsServerPrimaryZone" when DNS zone "ReplicationScope" is incorrect' {
                Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource }
                Mock -CommandName Set-DnsServerPrimaryZone -ParameterFilter { $ReplicationScope -eq 'Forest' }
                Set-TargetResource @testParams -Ensure Present -ReplicationScope 'Forest'
                Assert-MockCalled -CommandName Set-DnsServerPrimaryZone -ParameterFilter { $ReplicationScope -eq 'Forest' } -Scope It
            }

            It 'Calls "Set-DnsServerPrimaryZone" when DNS zone "DirectoryPartitionName" is incorrect' {
                Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource }
                Mock -CommandName Set-DnsServerPrimaryZone -ParameterFilter { $DirectoryPartitionName -eq 'IncorrectDirectoryPartitionName' }
                Set-TargetResource @testParams -Ensure Present -ReplicationScope 'Custom' -DirectoryPartitionName 'IncorrectDirectoryPartitionName'
                Assert-MockCalled -CommandName Set-DnsServerPrimaryZone -ParameterFilter { $DirectoryPartitionName -eq 'IncorrectDirectoryPartitionName' } -Scope It
            }

            Context 'When DirectoryPartitionName is specified and ReplicationScope is not "Custom"' {
                It 'Should throw the correct exception' {
                    Mock -CommandName Get-TargetResource -MockWith { return $fakeAbsentTargetResource }
                    Mock -CommandName Add-DnsServerPrimaryZone -ParameterFilter { $Name -eq $testZoneName }
                    { Set-TargetResource @testParams -Ensure Present -ReplicationScope 'Domain' `
                            -DirectoryPartitionName 'DirectoryPartitionName' } | Should -Throw $LocalizedData.DirectoryPartitionReplicationScopeError
                }
            }

            Context 'When DirectoryPartitionName is changed and ReplicationScope is not "Custom"' {
                It 'Should throw the correct exception' {
                    Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource }
                    Mock -CommandName Set-DnsServerPrimaryZone
                    { Set-TargetResource @testParams -Ensure Present -ReplicationScope 'Domain' `
                            -DirectoryPartitionName 'IncorrectDirectoryPartitionName' } | Should -Throw $LocalizedData.DirectoryPartitionReplicationScopeError
                }
            }

            Context 'When DirectoryPartitionName is changed and ReplicationScope is "Custom"' {
                $fakePresentTargetResourceCustom = $fakePresentTargetResource.Clone()
                $fakePresentTargetResourceCustom.ReplicationScope = 'Custom'

                Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResourceCustom }
                Mock -CommandName Set-DnsServerPrimaryZone

                It 'Should not throw' {
                    { Set-TargetResource @testParams -Ensure Present -ReplicationScope 'Custom' -DirectoryPartitionName 'IncorrectDirectoryPartitionName' } | `
                            Should -Not -Throw
                }

                It 'Shpould call the expected mocks' {
                    Assert-MockCalled -CommandName Set-DnsServerPrimaryZone -ParameterFilter { $DirectoryPartitionName -eq 'IncorrectDirectoryPartitionName' }
                }
            }

            Context 'when "Ensure" = "Present" and DNS zone does not exist and DirectoryPartitionName is set and ReplicationScope is not "Custom"' {
                It 'Should throw the correct exception' {
                    Mock -CommandName Get-TargetResource -MockWith { return $fakeAbsentTargetResource }
                    Mock -CommandName Set-DnsServerPrimaryZone
                    { Set-TargetResource @testParams -Ensure Present -ReplicationScope 'Domain' `
                            -DirectoryPartitionName 'IncorrectDirectoryPartitionName' } | Should -Throw $LocalizedData.DirectoryPartitionReplicationScopeError
                }
            }

            Context 'When a computer name is not passed' {
                BeforeAll {
                    Mock -CommandName New-CimSession
                    Mock -CommandName Remove-CimSession
                    Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource }
                    Mock -CommandName Set-DnsServerPrimaryZone
                }
                It 'Should not call New-CimSession' {
                    Set-TargetResource @testParams -ReplicationScope $testReplicationScope
                    Assert-MockCalled -CommandName New-CimSession -Scope It -Times 0 -Exactly
                }

                It 'Should not call Remove-CimSession' {
                    Set-TargetResource @testParams -ReplicationScope $testReplicationScope
                    Assert-MockCalled -CommandName Remove-CimSession -Scope It -Times 0 -Exactly
                }
            }

            Context 'When a computer name is passed' {
                BeforeAll {
                    Mock -CommandName New-CimSession -MockWith { New-MockObject -Type Microsoft.Management.Infrastructure.CimSession }
                    Mock -CommandName Remove-CimSession
                    Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource }
                    Mock -CommandName Set-DnsServerPrimaryZone
                }

                It 'Should call New-CimSession' {
                    $withComputerNameParameter = $testParams + @{
                        ComputerName = $testComputerName
                    }
                    Set-TargetResource @withComputerNameParameter -ReplicationScope $testReplicationScope
                    Assert-MockCalled -CommandName New-CimSession -ParameterFilter { $computername -eq $withComputerNameParameter.ComputerName } -Scope It -Times 1 -Exactly
                }
                It 'Should call Remove-CimSession' {
                    $withComputerNameParameter = $testParams + @{
                        ComputerName = $testComputerName
                    }
                    Set-TargetResource @withComputerNameParameter -ReplicationScope $testReplicationScope
                    Assert-MockCalled -CommandName Remove-CimSession -Scope It -Times 1 -Exactly
                }

                Context 'When credentials are passed' {
                    BeforeAll {
                        Mock -CommandName New-CimSession -MockWith { New-MockObject -Type Microsoft.Management.Infrastructure.CimSession }
                        Mock -CommandName Remove-CimSession
                        Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource }
                        Mock -CommandName Set-DnsServerPrimaryZone
                    }

                    It 'Should call New-CimSession' {
                        $withCredentialsAndComputerParameter = $testParams + @{
                            ComputerName = $testComputerName
                            Credential   = $testCredential
                        }
                        Set-TargetResource @withCredentialsAndComputerParameter -ReplicationScope $testReplicationScope
                        Assert-MockCalled -CommandName New-CimSession -ParameterFilter { $computername -eq $withCredentialsAndComputerParameter.ComputerName -and $credential -eq $withCredentialsAndComputerParameter.Credential } -Scope It -Times 1 -Exactly
                    }
                    It 'Should call Remove-CimSession' {
                        $withCredentialsAndComputerParameter = $testParams + @{
                            ComputerName = $testComputerName
                            Credential   = $testCredential
                        }
                        Set-TargetResource @withCredentialsAndComputerParameter -ReplicationScope $testReplicationScope
                        Assert-MockCalled -CommandName Remove-CimSession -Scope It -Times 1 -Exactly
                    }
                }
            }
        }
        #endregion
    } #end InModuleScope
}
finally
{
    Invoke-TestCleanup
}
