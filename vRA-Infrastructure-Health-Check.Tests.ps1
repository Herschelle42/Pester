<#
.SYNOPSIS
  Run Pester test health checks across the vRA infrastructure.
.DESCRIPTION
  Test all the individual components that make up and support the vRA 
  infrastructure. From simply pings, to checking event logs and services.
.PARAMETER CredMgmt
  The Management domain credentials to use to connect to vCenter, vRA, IaaS
.PARAMETER JSONPayload
  Data to be used in these tests, rather than creating dozens of parameters.
  The tests are tightly related to the json structure but by keeping them 
  separate they can be edited independently from the tests themselves. Reducing
  fat fingering of scripts.
.PARAMETER ICMP
  Enable ICMP (ping) tests, default is true. Currently only tested using ICMPv4
  ICMP pings all Servers and Services
.PARAMETER vCenter
  Enable tests for vCenter, default is false
.PARAMETER vRA
  Enable tests for vRealize Automation, default is false
.PARAMETER vRAIaaS
  Enable tests for vRealize Automation IaaS Manager and Web Windows servers, default is false
.PARAMETER vRO
  Enable tests for vRealize Orchestrator, default is false
.PARAMETER LogInsight
  Enable tests, default is false
.PARAMETER NSXT
  Enable tests, default is false
.PARAMETER vRNI
  Enable tests for vRealize Network Insight, default is false
.INPUTS
  [Management.Automation.PSCredential]
  [string]
  [switch]
.NOTES
  Author: Clint Fritz
  Note: Not using PowervRO or PowervRA modules as they are not supported by
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
    [string]$JSONPayload,
    [Parameter(Mandatory=$false)]
    [switch]$ICMP=$true,
    [Parameter(Mandatory=$false)]
    [switch]$vCenter=$false,
    [Parameter(Mandatory=$false)]
    [switch]$vRA=$false,
    [Parameter(Mandatory=$false)]
    [switch]$vRAIaaS=$false,
    [Parameter(Mandatory=$false)]
    [switch]$vRO=$false,
    [Parameter(Mandatory=$false)]
    [switch]$LogInsight=$false,
    [Parameter(Mandatory=$false)]
    [switch]$NSXT=$false,
    [Parameter(Mandatory=$false)]
    [switch]$vRNI=$false
)#end Param

Write-Verbose "[INFO] Starting $($MyInvocation.MyCommand.Name)"

#region --- environment setup -------------------------------------------------

#Get the DNS domain for where this test script is being run from
$testerDomain = (Get-WmiObject win32_computersystem).Domain

#Get the list of servers to test and convert to a Powershell Object
#$serverList = $JSONPayload | ConvertFrom-Json
#hack work around to get sub section of json into an Object for easier use
$serverList = $jsonData | ConvertFrom-Json | Select -ExpandProperty Server | ConvertTo-Json -Depth 5 | ConvertFrom-Json
$serviceList = $jsonData | ConvertFrom-Json | Select -ExpandProperty Service | ConvertTo-Json -Depth 5 | ConvertFrom-Json
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
if($ICMP) {

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
                #if ($dnsDomain -eq $testerDomain)
                #exlcude vmwarevmc.com as reverse lookup to vCenter in VMC will not work.
                if ($dnsDomain -notmatch "vmwarevmc.com")
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

            Context "$($svcType) $($svcFQDN)" {

                it 'Service name should respond to ICMP packets (ping)' {
                    Test-Connection -ComputerName $svcFQDN -Quiet | should Be $true
                }#end it

            }#end context

        }#end foreach service

    }#end describe block

} else {
    Write-Verbose "[INFO] Skipping: ICMP and Name resolution"
}#end if skipPing

#endregion --- ICMP and Name resolution ---------------------------------------


#region --- vCenter -----------------------------------------------------------
if($vCenter)
{
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

} else {
    Write-Verbose "[INFO] Skipping: vCenter tests"

}#end if skip

#endregion --- vCenter --------------------------------------------------------


#region --- vRA ---------------------------------------------------------------

if ($vRA)
{
    <#
    vRA 7.x requires tls 1.2 to work, otherwise will receive the error:
    Invoke-RestMethod : The underlying connection was closed: An unexpected error occurred on a send.
    when attempting to do Invoke-restmethod
    #>
    if (-not ("Tls12" -in  (([System.Net.ServicePointManager]::SecurityProtocol).ToString() -split ", ")))
    {
        Write-Verbose "[INFO] Adding Tls 1.2 to security protocol"
        [System.Net.ServicePointManager]::SecurityProtocol += [System.Net.SecurityProtocolType]::Tls12
    }#end if tls12

    Describe 'vRA Tests' {

        foreach ($service in ($serviceList | ? { $_.type -eq "vRA" })) {

            $vraType = $service.Type
            $vraFQDN = $service.FQDN
            $vraPort = $service.Port
            $vraApi = $service.api
            $vamiPort = $service.vamiPort
            $tenant = $service.tenant
            $uri = $null
            $result = $null

            <#
            Health of vRA 
            docs.vmware.com  "Support for Monitoring health for a HA Enabled vRealize Automation"

            vRealize Automation Server            /vcac
            vRealize Automation Manager Server    /vco
            #>

            Context "Web page tests" {
                
                it 'Health Status url loads without error' {
                    $uri = "https://$($vraFQDN)$($vraApi)/vcac/services/api/status"
                    $result = Invoke-WebRequest -Uri $uri

                    $result.StatusCode | Should Be "200"

                }#end it

                it 'Health Status is REGISTERED' {
                    $uri = "https://$($vraFQDN)$($vraApi)/vcac/services/api/status"
                    $result = Invoke-WebRequest -Uri $uri

                    ($result.Content | ConvertFrom-Json).serviceInitializationStatus | Should Be "REGISTERED"

                }#end it


                it 'VAMI Login page loads without error' {
                    $uri = "https://$($vraFQDN):$($vamiPort)"
                    $result = Invoke-WebRequest -Uri $uri

                    $result.StatusCode | Should Be "200"

                }
                
                it 'vRA Login GUI Page Loads without error' {
                    $uri = "https://$($vraFQDN)/vcac"
                    $result = Invoke-WebRequest -Uri $uri

                    $result.StatusCode | Should Be "200"

                }#end it

            }#end context Web Pages

            Context "REST API" {

                #region --- generate token for vRA REST requests ------------------------------
                #Must be outside the 'it' as this is a scope and we need to use the token in other tests

                $method = "POST"
                $uri = "https://$($vraFQDN)/identity/api/tokens"

                $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
                $headers.Add("Accept", 'application/json')
                $headers.Add("Content-Type", 'application/json')

                $body = @{
                    username = $mgmtUsername
                    password = $mgmtPassword
                    tenant = $tenant
                } | ConvertTo-Json


                $response = $null

                try
                {
                    $response = Invoke-RestMethod -Uri $uri -Method $method -Headers $headers -Body $body
                }
                catch 
                {
                    Write-Output "StatusCode:" $_.Exception.Response.StatusCode.value__
                    throw
                }
                $vraToken = $response
                $bearer_token = $vraToken.id

                #endregion --- generate token for vRA REST requests ---------------------------


                it 'Creates a valid access token' {
                    $vraToken | Should Be $true
                }#end it


                #region --- Validate all configured Endpoints ---------------------------------

                #Get all Endpoints
                $uri = "https://$($vraServer)/endpoint-configuration-service/api/endpoints?limit=1000"
                $method = "GET"

                $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
                $headers.Add("Accept", 'application/json')
                $headers.Add("Content-Type", 'application/json')
                $headers.Add("Authorization", "Bearer $($bearer_token)")

                try
                {
                    $response = Invoke-RestMethod -Uri $uri -Method $method -Headers $headers
                }
                catch 
                {
                    Write-Output "StatusCode: $($_.Exception.Response.StatusCode.value__)"
                    throw
                }

                $endpointList = $response.content
                Write-Output "[INFO] Total vRA Endpoints: $($endpointList.Count)"

                #uri to validate the endpoint connection
                $method = "POST"
                $uri = "https://$($vraServer)/endpoint-configuration-service/api/endpoints/validate"

                foreach ($endpoint in $endpointList)
                {
                    $epJSON = $endpoint | ConvertTo-Json -Depth 5
                    $response = $null
                    try
                    {
                        $response = Invoke-RestMethod -Uri $uri -Method $method -Headers $headers -Body $epJSON
                    }
                    catch 
                    {
                        Write-Output "StatusCode: $($_.Exception.Response.StatusCode.value__)"
                        throw
                    }
                    
                    it "Endpoint [$($endpoint.name)] validation is successful." {
                        $($response.status) | Should Be "SUCCESS"
                    }#end it

                }#end foreach endpoint


                #endregion --- Validate all configured Endpoints ------------------------------

            }#end Context REST API

            Context 'Other Test Ideas' {
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



                it 'Do a test deployment of each IaaS to each vCenter. Red Hat, 2012 R2 and 2016' {


                }#end it

            }#end Context Other Test Ideas

        }#End foreach vRO

    }#end Describe
} else {
    Write-Verbose "[INFO] Skipping: vRA"

} #end if skip

#endregion --- vRA ------------------------------------------------------------


#region --- vRO ------------------------------------------------------------
if ($vRO)
{
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
                    
                    <#
                      Run a workflow that does a search of each of the AD configurations?
                      This would confirm the configuration itself is correct and that vRO 
                      can connect to it to be able to do a simply search and retrieve info.
                    #>

                }#end it

                it 'vRO Links Page Loads without error' {
                    $uri = "https://$($vroFQDN)/vco"
                    $result = Invoke-WebRequest -Uri $uri

                    $result.StatusCode | Should Be "200"

                }#end it


            }#end Context    

        }#End foreach vRO

    }#end Describe

} else {
    Write-Verbose "[INFO] Skipping: vRO tests"

} #end if skip

#endregion --- vRO ------------------------------------------------------------


#region --- vRA IaaS Manager --------------------------------------------------

<#
Health of vRA 
docs.vmware.com  "Support for Monitoring health for a HA Enabled vRealize Automation"

#>

if ($vRAIaaS)
{

    #Place any specific region setup here

    Describe 'IaaS Manager Tests' {

        foreach ($service in ($serviceList | ? { $_.type -eq "IaaSMgr" })) {

            $fqdn = "$($service.FQDN)"
            $healthAPI = "$($service.healthAPI)"

            Context "Health Status" {
                $uri = "https://$($fqdn)$($healthAPI)"
                $result = Invoke-WebRequest -Uri $uri -Credential $CredMgmt

                it 'IaaS Manager' {
                    $result.StatusCode | Should Be "200"
                }#end it

                #Not sure if we need this just yet. As cannot see anything in the content to suggest successful
                #above a 200 status return
                #$xml = $result.rawcontent.Substring($result.RawContent.IndexOf("<?xml")) | ConvertTo-Xml

            }#end Context

        }#End foreach

        foreach ($server in ($serverList | ? { $_.type -eq "IaaSMgr" })) {

            $fqdn = "$($server.Hostname).$($server.DNSDomain)"

            <#
                this will require WinRM from the location of this test to each
                of the Windows servers that are in the list
            #>
            Context "Windows Services - $($server.Hostname)" {
                
                #NOTE: Not going to work unless WinRM connectivity available
                #$result = Get-Service -Name "VMware*" -ComputerName $fqdn

                foreach ($winService in $result)
                {
                    it "$($winService.name) is running" {
                        #$service.State | should Be "Running"

                    }#end it

                }#end foreach

                $result = $null
            }#end Context    

        }#End foreach

    }#end Describe

    <#
    Health of vRA 
    docs.vmware.com  "Support for Monitoring health for a HA Enabled vRealize Automation"

    vRealize Orchestrator App Server      /WAPI/api/status

    #Requires authentication
    repository:  /Repository/Data/MetaModel.svc
    #>


    #Place any specific region setup here

    Describe 'IaaS Web Tests' {


        foreach ($service in ($serviceList | ? { $_.type -eq "IaaSWeb" })) {

            $fqdn = "$($service.FQDN)"
            $healthAPI = "$($service.healthAPI)"

            Context "Health Status" {

                it 'Health Status is registerd' {
                    $uri = "https://$($fqdn)$($healthAPI)"
                    $result = Invoke-WebRequest -Uri $uri

                    ($result.Content | ConvertFrom-Json).serviceInitializationStatus | Should Be "REGISTERED"

                }#end it

            }#end Context

        }#end foreach

        foreach ($server in ($serverList | ? { $_.type -eq "IaaSWeb" })) {

            $fqdn = "$($server.Hostname).$($server.DNSDomain)"

            <#
                this will require WinRM from the location of this test to each
                of the Windows servers that are in the list
            #>
            Context "Windows Services - $($server.Hostname)" {
                
                #NOTE: Not going to work unless WinRM connectivity available?
                #$result = Get-Service -Name "VMware*" -ComputerName $fqdn

                foreach ($winService in $result)
                {
                    it "$($winService.name) is running" {
                        #$service.State | should Be "Running"

                    }#end it

                }#end foreach

                $result = $null
            }#end Context    

        }#End foreach

    }#end Describe


} else {
    Write-Verbose "[INFO] Skipping: vRA IaaS"

} #end if skip

#endregion --- vRA IaaS ---------------------------------------------------



#region --- Template ----------------------------------------------------------
<#
This is a template region to be used to copy when creating new blocks of tests.
When adding a new section, add a new switch parameter
#>

if ($templateType)
{

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

} else {
    Write-Verbose "[INFO] Skipping: Template"

} #end if skip

#endregion --- Template -------------------------------------------------------
