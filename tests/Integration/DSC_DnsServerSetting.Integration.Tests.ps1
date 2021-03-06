$script:dscModuleName   = 'DnsServerDsc'
$script:dscResourceFriendlyName = 'DnsServerSetting'
$script:dscResourceName = "DSC_$($script:dscResourceFriendlyName)"

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
    -TestType 'Integration'

try
{
    #region Integration Tests
    $configFile = Join-Path -Path $PSScriptRoot -ChildPath "$($script:dscResourceName).config.ps1"
    . $configFile

    Describe "$($script:dscResourceName)_Integration" {
        BeforeAll {
            $resourceId = "[$($script:dscResourceFriendlyName)]Integration_Test"
        }

        $configurationName = "$($script:dscResourceName)_SetSettings_Config"

        Context ('When using configuration {0}' -f $configurationName) {
            It 'Should compile and apply the MOF without throwing' {
                {
                    $configurationParameters = @{
                        OutputPath        = $TestDrive
                        ConfigurationData = $ConfigurationData
                    }

                    & $configurationName @configurationParameters

                    $startDscConfigurationParameters = @{
                        Path         = $TestDrive
                        ComputerName = 'localhost'
                        Wait         = $true
                        Verbose      = $true
                        Force        = $true
                        ErrorAction  = 'Stop'
                    }

                    Start-DscConfiguration @startDscConfigurationParameters
                } | Should -Not -Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                {
                    $script:currentConfiguration = Get-DscConfiguration -Verbose -ErrorAction Stop
                } | Should -Not -Throw
            }

            It 'Should have set the resource and all the parameters should match' {
                $resourceCurrentState = $script:currentConfiguration | Where-Object -FilterScript {
                    $_.ConfigurationName -eq $configurationName `
                    -and $_.ResourceId -eq $resourceId
                }

                $resourceCurrentState.DnsServer                  | Should -Be $ConfigurationData.AllNodes.DnsServer
                $resourceCurrentState.AddressAnswerLimit         | Should -Be $ConfigurationData.AllNodes.AddressAnswerLimit
                $resourceCurrentState.AllowUpdate                | Should -Be $ConfigurationData.AllNodes.AllowUpdate
                $resourceCurrentState.AutoCacheUpdate            | Should -Be $ConfigurationData.AllNodes.AutoCacheUpdate
                $resourceCurrentState.AutoConfigFileZones        | Should -Be $ConfigurationData.AllNodes.AutoConfigFileZones
                $resourceCurrentState.BindSecondaries            | Should -Be $ConfigurationData.AllNodes.BindSecondaries
                $resourceCurrentState.BootMethod                 | Should -Be $ConfigurationData.AllNodes.BootMethod
                $resourceCurrentState.DisableAutoReverseZones    | Should -Be $ConfigurationData.AllNodes.DisableAutoReverseZones
                $resourceCurrentState.DisjointNets               | Should -Be $ConfigurationData.AllNodes.DisjointNets
                $resourceCurrentState.DsPollingInterval          | Should -Be $ConfigurationData.AllNodes.DsPollingInterval
                $resourceCurrentState.DsTombstoneInterval        | Should -Be $ConfigurationData.AllNodes.DsTombstoneInterval
                $resourceCurrentState.EnableDirectoryPartitions  | Should -Be $ConfigurationData.AllNodes.EnableDirectoryPartitions
                $resourceCurrentState.EnableDnsSec               | Should -Be $ConfigurationData.AllNodes.EnableDnsSec
                $resourceCurrentState.ForwardDelegations         | Should -Be $ConfigurationData.AllNodes.ForwardDelegations
                $resourceCurrentState.IsSlave                    | Should -Be $ConfigurationData.AllNodes.IsSlave
                $resourceCurrentState.ListenAddresses            | Should -Be $ConfigurationData.AllNodes.ListenAddresses
                $resourceCurrentState.LocalNetPriority           | Should -Be $ConfigurationData.AllNodes.LocalNetPriority
                $resourceCurrentState.LogLevel                   | Should -Be $ConfigurationData.AllNodes.LogLevel
                $resourceCurrentState.LooseWildcarding           | Should -Be $ConfigurationData.AllNodes.LooseWildcarding
                $resourceCurrentState.MaxCacheTTL                | Should -Be $ConfigurationData.AllNodes.MaxCacheTTL
                $resourceCurrentState.MaxNegativeCacheTTL        | Should -Be $ConfigurationData.AllNodes.MaxNegativeCacheTTL
                $resourceCurrentState.NameCheckFlag              | Should -Be $ConfigurationData.AllNodes.NameCheckFlag
                $resourceCurrentState.RoundRobin                 | Should -Be $ConfigurationData.AllNodes.RoundRobin
                $resourceCurrentState.RpcProtocol                | Should -Be $ConfigurationData.AllNodes.RpcProtocol
                $resourceCurrentState.SecureResponses            | Should -Be $ConfigurationData.AllNodes.SecureResponses
                $resourceCurrentState.SendPort                   | Should -Be $ConfigurationData.AllNodes.SendPort
                $resourceCurrentState.StrictFileParsing          | Should -Be $ConfigurationData.AllNodes.StrictFileParsing
                $resourceCurrentState.UpdateOptions              | Should -Be $ConfigurationData.AllNodes.UpdateOptions
                $resourceCurrentState.WriteAuthorityNS           | Should -Be $ConfigurationData.AllNodes.WriteAuthorityNS
                $resourceCurrentState.XfrConnectTimeout          | Should -Be $ConfigurationData.AllNodes.XfrConnectTimeout
            }

            It 'Should return ''True'' when Test-DscConfiguration is run' {
                Test-DscConfiguration -Verbose | Should -Be 'True'
            }
        }

        Wait-ForIdleLcm -Clear
    }
}
finally
{
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment
}
