<#
.SYNOPSIS
  Run Pester test health checks across the vRA infrastructure.
.DESCRIPTION
  Test all the individual components that make up and support the vRA 
  infrastructure. From simple pings, to checking event logs and services.
.PARAMETER CredMgmt
  The Management domain credentials to use to connect to vCenter, vRA, IaaS
.PARAMETER JSONPayload
  Data to be used in these tests, rather than creating dozens of parameters.
  The tests are tightly related to the json structure but by keeping them 
  separate they can be edited independently from the tests themselves. Reducing
  fat fingering of scripts.
.NOTES
  We are not using PowervRO or PowervRA modules as they are not supported by
  VMware.  Pester is also not supported by VMware, but is being used as the testing 
  framework.
  
#>
#requires -Modules Pester, VMware.VIM
[CmdletBinding()]
Param
(
   
    [Parameter(Mandatory=$true)]
    [Management.Automation.PSCredential]$CredMgmt,
    [Parameter(Mandatory=$true)]
    [string]$JSONPayload
)#end Param

Write-Verbose "[INFO] Starting $($MyInvocation.MyCommand.Name)"

#region --- environment setup -------------------------------------------------

#Uncomment one or more of these parameters to skip past tests. Mainly for testing purposes.
$skipICMP = $true
#$skipvCenter = $true
#$skipvRA = $true
#$skipvRO = $true
#$skipIaaSMgr = $true
#$skipIaaSWeb = $true
#$skipTemplate = $true

#Get the DNS domain for where this test script is being run from
$testerDomain = (Get-WmiObject win32_computersystem).Domain

#Get the list of servers to test and convert to a Powershell Object
#$serverList = $JSONPayload | ConvertFrom-Json
#hack work around to get sub section of json into an Object for easier use
$serverList = $jsonData | ConvertFrom-Json | Select -ExpandProperty Server | ConvertTo-Json -Depth 5 | ConvertFrom-Json
$serviceList = $jsonData | ConvertFrom-Json | Select -ExpandProperty Service | ConvertTo-Json -Depth 5 | ConvertFrom-Json
$vRAEndpointList = $jsonData | ConvertFrom-Json | Select -ExpandProperty vRAEndpoint | ConvertTo-Json -Depth 5 | ConvertFrom-Json
$templateList = $jsonData | ConvertFrom-Json | Select -ExpandProperty Template | ConvertTo-Json -Depth 5 | ConvertFrom-Json

<#
Split out the password from the credential as this is required to perfrom the 
REST requests. Where possible should always use a Credential rather than
clear text passwords
#>
$mgmtUsername = $CredMgmt.UserName
$mgmtPassword = $CredMgmt.GetNetworkCredential().Password



#endregion --- environment setup ----------------------------------------------


#region --- ICMP and Name resolution ---------------------------------------------
if($skipICMP) {
    Write-Verbose "[INFO] Skipping: ICMP and Name resolution"
} else {

    Write-Verbose "[INFO] ICMP and Name resolution"

    Describe 'ICMP and Name resolution' {

        Write-Verbose "[INFO] Server count: $($serverList.Count)"

        foreach ($server in $serverList)
        {
            #avoiding the use of $hostname
            $computerName = $server.Hostname
            $fqdn = "$($server.Hostname).$($server.DNSDomain)"
            $ipAddress = $server.IPAddress
            $type = $server.Type
            $dataCenter = $server.DataCenter
            $dnsDomain = $server.DNSDomain

            <#
            Context "$($server.Type) $($server.Hostname) - Mock Tests" {
                it 'should return $true when the computer is online' {
                    Mock 'Test-Connection' -MockWith { $true }

                    Test-Connection -ComputerName $fqdn | should be $true
                }#end it

                it 'should return $false when the computer is offline' {
                    Mock 'Test-Connection' -MockWith { $false }

                    Test-Connection -ComputerName $fqdn | should be $false
                }#end it

            }#end context mock test
            #>

            Context "$($type) $($fqdn) ($($dataCenter))" {
                it 'FQDN should respond to ICMP packets (ping)' {
                    Test-Connection -ComputerName $fqdn -Quiet | should be $true
                }#end it


                it 'IP Address should respond to ICMP packets (ping)' {
                    Test-Connection -ComputerName $($ipAddress) -Quiet | should be $true
                }#end it

                #can only test in the domain this test script is run from
                if ($dnsDomain -eq $testerDomain)
                {

                    it 'IP Address resolves to hostname' {
                        #Test-Connection -ComputerName $($ipAddress) -Quiet | should be $computerName
                        [System.Net.Dns]::GetHostEntry($ipaddress).HostName | should Be $fqdn

                    }#end it
                }

            }#end context real Pings

        }#end foreach server

        foreach ($service in $serviceList)
        {

            $svcType = $service.Type
            $svcFQDN = $service.FQDN
            $svcPort = $service.Port
            $svcApi = $service.api

            Context "$($svcType) $($fqdn) ($($dataCenter))" {

                it 'Service name should respond to ICMP packets (ping)' {
                    Test-Connection -ComputerName $svcFQDN -Quiet | should Be $true
                }#end it

            }#end context

        }#end foreach service

    }#end describe block

}#end if skipPing

#endregion --- ICMP and Name resolution ---------------------------------------


#region --- vCenter -----------------------------------------------------------
if($skipvCenter)
{
    Write-Verbose "[INFO] Skipping: vCenter tests"
} else {
    Describe 'vCenter Tests' {
        foreach ($server in $serverList | ? { $_.type -eq "vCenter"} )
        {
            #avoiding the use of $hostname
            $computerName = $server.Hostname
            $fqdn = "$($server.Hostname).$($server.DNSDomain)"
            $ipAddress = $server.IPAddress
            $type = $server.Type
            $dataCenter = $server.DataCenter
            $dnsDomain = $server.DNSDomain

            Context "$($type) $($computerName) ($($dataCenter))" {

                it 'PowerCli should successfully connect to vCenter' {
                    Connect-VIServer -Server $fqdn -Credential $credMgmt | should be $true
                }#end it

                #only perform the following tests if there is a successfully connection.
                if ($global:DefaultVIServers | ? { $_.name -eq $fqdn })
                {

                    it 'Datacenter list should be returned' {
                        (Get-Datacenter).Count | should -BeGreaterOrEqual 1
                    }#end it

                    #Templates
                    foreach ($template in ($templateList | ? { $_.type -eq "IaaS" })) {

                        $iaasType = $template.Type
                        $iaasOS = $template.OS
                        $iaasName = $template.Name
                        $result = $null

                        #Context "$($iaasOS) IaaS Template: $($iaasName)" {
                
                            it "$($iaasOS) IaaS Template Exists - $($iaasName)" {
                                $result = Get-Template -Name $iaasName -Server $fqdn
                                #$result | Should Be $true

                            }#end it

                        #}#end Context    

                    }#End foreach template


                    it 'PowerCLI should successfully disconnect from vCenter' {
                        Disconnect-VIServer -Server $fqdn -Confirm:$false | should be $null
                    
                    }#end it

                }#end if

            }#end context

        }#end foreach server

    }#end Describe

}#end if skip

#endregion --- vCenter --------------------------------------------------------


#region --- vRA ---------------------------------------------------------------

if ($skipTemplate)
{
    Write-Verbose "[INFO] Skipping: vRA"
} else {

    #Place any specific region setup here

    Describe 'vRA Tests' {

        foreach ($service in ($serviceList | ? { $_.type -eq "vRA" })) {

            $vraType = $service.Type
            $vraFQDN = $service.FQDN
            $vraPort = $service.Port
            $vraApi = $service.api
            $uri = $null
            $result = $null

            Context "Context" {

                it 'Health Status' {
                    $uri = "https://$($vraFQDN)$($vraApi)/vcac/services/api/status"
                    #https://$($vraFQDN)/component-registry/services/status/current
                    #returns an xml document
                    $result = Invoke-WebRequest -Uri $uri

                    #$result.somthing | should be OK? \ REGISTERED

                }#end it
                
                it 'Create valid access token' {
                    


                }#end it



                it 'Infrastructure -> Monitoring -> DEM Status' {

                }#end it

                it 'Infrastructure -> Monitoring -> Log' {
                    <#should be no errors relating to connectivity to vCenter servers in the past hour
                    Severity: Error
                    Source: VRM Agent
                    Message: 
                    This exception was caught: 
                    Unable to connect to the remote server
                    Inner Exception: A connection attempt failed because the connected party did not properly respond after a period of time, or established connection failed because connected host has failed to respond 10.254.58.21:443
                    #>

                }#end it

                it 'others to test?' {

                }#end it

                it 'Infrastructure -> Compute Resource -> Compute Resource' {


                }#end it

                it 'Test endpoint connection to each of the vCenter server endpoints' {


                }#end it

                it 'Do a test deployment of each IaaS to each vCenter. Red Hat, 2012 R2 and 2016' {


                }#end it

                it 'disconnect test?' {

                }#end it

            }#end Context    

        }#End foreach vRO

    }#end Describe

} #end if skip

#endregion --- vRA ------------------------------------------------------------


#region --- vRO ------------------------------------------------------------
if ($skipvRO)
{
    Write-Verbose "[INFO] Skipping: vRO tests"
} else {

    <#
    vRO 7.x requires tls 1.2 to work, otherwise will receive the error:
    Invoke-RestMethod : The underlying connection was closed: An unexpected error occurred on a send.
    when attempting to do Invoke-restmethod
    #>
    if (-not ("Tls12" -in  (([System.Net.ServicePointManager]::SecurityProtocol).ToString() -split ", ")))
    {
        Write-Verbose "[INFO] Adding Tls 1.2 to security protocol"
        [System.Net.ServicePointManager]::SecurityProtocol += [System.Net.SecurityProtocolType]::Tls12
    }#end if tls12

    #Setup REST variables
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $mgmtUsername,$mgmtPassword)))
    $headers = @{"Authorization"=("Basic {0}" -f $base64AuthInfo)}

    $method = "GET"

    Describe 'vRO Tests' {

        foreach ($service in ($serviceList | ? { $_.type -eq "vRO" })) {

            $vroType = $service.Type
            $vroFQDN = $service.FQDN
            $vroPort = $service.Port
            $vroApi = $service.api
            $uri = $null
            $result = $null

            Context "$($vroFQDN)" {

                $uri = "https://$($vroFQDN)$($vroApi)/healthstatus?showDetails=false"
                $result = Invoke-RestMethod -Method $method -UseBasicParsing -Uri $uri -Headers $headers

                it 'Status is RUNNING' {
                    $result.state | Should Be "RUNNING"
                }#end it
                it 'Health State is OK' {
                    $result.'health-status'.state | Should Be "OK"
                }#end it

                $uri = $null
                $result = $null


                it 'Retrieve list of workflows' {
                    $uri = "https://$($vroFQDN)$($vroApi)/workflows?maxResult=2147483647&startIndex=0&queryCount=false"
                    
                    $result = Invoke-RestMethod -Method $method -UseBasicParsing -Uri $uri -Headers $headers
                    $result.total | Should -BeGreaterThan 1
                }#end it

                it 'Retrieve list of actions' {
                    $uri = "https://$($vroFQDN)$($vroApi)/actions?maxResult=2147483647&startIndex=0&queryCount=false"
                    
                    $result = Invoke-RestMethod -Method $method -UseBasicParsing -Uri $uri -Headers $headers
                    $result.total | Should -BeGreaterThan 1
                }#end it

                it 'Test endpoints?' {
                    #$uri = "/resources "
                    <#
                      <link href="https://vroserver.corp.local:443/vco/api/resources/caa6be44-5d00-461a-91b2-2f8b19fc1872/" rel="resource">
                        <attributes>
                          <attribute value="caa6be44-5d00-461a-91b2-2f8b19fc1872" name="id"/>
                          <attribute value="ENDPOINT--https___vcenter.corp.local.au_api" name="name"/>
                    #>
                    
                }#end it

            }#end Context    

        }#End foreach vRO

    }#end Describe

} #end if skip

#endregion --- vRO ------------------------------------------------------------


#region --- IaaS Manager ------------------------------------------------------

#Status uri?  : /VMPS2   or  /VMPS2/Provision

if ($skipIaaSMgr)
{
    Write-Verbose "[INFO] Skipping: IaaS Manager"
} else {

    #Place any specific region setup here

    Describe 'IaaS Manager Tests' {

        foreach ($server in ($serverList | ? { $_.type -eq "IaaSMgr" })) {

            $fqdn = "$($server.Hostname).$($server.DNSDomain)"

            Context "Services" {
                
                #NOTE: Not going to work unless WinRM connectivity available?
                #$result = Get-Service -Name "VMware*" -ComputerName $fqdn

                foreach ($service in $result)
                {
                    it "$($service.name) is running" {
                        #$service.State | should Be "Running"

                    }#end it

                }#end foreach

                $result = $null

            }#end Context    

        }#End foreach

    }#end Describe

} #end if skip

#endregion --- IaaS Manager ---------------------------------------------------


#region --- IaaS Web ----------------------------------------------------------

#status uri?  : /WAPI/api/status   or   /WAPI/api/status/Web

#repository:  /Repository/Data/MetaModel.svc

if ($skipIaaSWeb)
{
    Write-Verbose "[INFO] Skipping: IaaS Web"
} else {

    #Place any specific region setup here

    Describe 'IaaS Web Tests' {

        foreach ($server in ($serverList | ? { $_.type -eq "IaaSWeb" })) {

            $fqdn = "$($server.Hostname).$($server.DNSDomain)"

            Context "Services" {
                
                #NOTE: Not going to work unless WinRM connectivity available?
                #$result = Get-Service -Name "VMware*" -ComputerName $fqdn

                foreach ($service in $result)
                {
                    it "$($service.name) is running" {
                        #$service.State | should Be "Running"

                    }#end it

                }#end foreach

                $result = $null

            }#end Context    

        }#End foreach

    }#end Describe

} #end if skip

#endregion --- IaaS Web -------------------------------------------------------


#region --- Template ----------------------------------------------------------

if ($skipTemplate)
{
    Write-Verbose "[INFO] Skipping: Template"
} else {

    #Place any specific region setup here

    Describe 'Template Tests' {

        foreach ($service in ($serviceList | ? { $_.type -eq "vRO" })) {

            Context "Context" {
                
                it 'Template Test should be true' {
                    $true | Should Be $true
                }#end it

            }#end Context    

        }#End foreach

    }#end Describe

} #end if skip

#endregion --- Template -------------------------------------------------------
