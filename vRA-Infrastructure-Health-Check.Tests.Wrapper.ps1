<#
.SYNOPSIS
  Wrapper script to call the Pester tests for vRA
.NOTES
  Author: Clint Fritz
#>
#requires -Modules Pester

#$VerbosePreference = "Continue"

#NOTE: .replace _is_ case senstive
$pesterScript = $MyInvocation.MyCommand.Path.replace(".Wrapper","")
$pesterOutput = $pesterScript.replace(".ps1",".xml")

Write-Verbose "[INFO] pesterScript : $($pesterScript)"
Write-Verbose "[INFO] pesterOutput : $($pesterOutput)"

#Obtain some credentials for use in the testing
if(-not $credMgmt)
{
    $credMgmt = Get-Credential -Message "Credentials to be used in Pester tests."
}#end if credvRA

#region --- variables ---------------------------------------------------------
Write-Verbose "[INFO] Declaring variables"
<#
TODO: Update this help area

JSON structure for all the systems and data required.
Hostname and DNSDomain are combined to make the FQDN
Datacenter is the physical hosted location of the virtual machine
[
    {
        "Type":  "",
        "Hostname":  "",
        "DNSDomain":  "management.corp.local",
        "IPAddress":  "",
        "DataCenter": ""
    }
]

vRAEndpoints
Infrastructure -> Endpoints -> Endpoints
Name Platform Type
Address
Username
Password

NOTE: Backslashes as values are escape characters. Therefore user\domain becomes user\\domain


TODO:  Add Log Insight etc to the list...
       Add NSX to the list?
       SSH to vCenter for service status?  eg vsphere-ui - although we do not own the password
       SSH to vRA
       WinRM to IaaS Manager and Web servers to check Services etc

#>

$jsonData = @"
{
    "Service": [
        {
            "Type": "vRA",
            "FQDN": "vra-app-prd.management.corp.local",
            "Port": "443",
            "api": "",
            "vamiPort": "5480",
            "tenant": "vsphere.local"
        },
        {
            "Type": "vRO",
            "FQDN": "vra-app-prd.management.corp.local",
            "Port": "443",
            "api": "/vco/api"
        },
        {
            "Type": "IaaSMgr",
            "FQDN": "vra-mgr-prd.management.corp.local",
            "Port": "",
            "healthAPI": "/VMPS2"
        },
        {
            "Type": "IaaSWeb",
            "FQDN": "vra-web-prd.management.corp.local",
            "Port": "",
            "healthAPI": "/WAPI/api/status"
        }
    ],
    "Server": [
            {
                "Type":  "vCenter",
                "Hostname":  "corpvc1-dc1",
                "DNSDomain":  "management.corp.local",
                "IPAddress":  "192.164.58.21",
                "DataCenter": "DC1"
            },
            {
                "Type":  "vCenter",
                "Hostname":  "corpvc1-dc2",
                "DNSDomain":  "management.corp.local",
                "IPAddress":  "192.164.186.21",
                "DataCenter": "DC2"
            },
            {
                "Type":  "vCenter",
                "Hostname":  "vcenter",
                "DNSDomain":  "sddc-13-211-5-135.vmwarevmc.com",
                "IPAddress":  "192.163.174.4",
                "DataCenter": "VMC"
            },
            {
                "Type":  "IaaSMgr",
                "Hostname":  "iaas-dc1",
                "DNSDomain":  "management.corp.local",
                "IPAddress":  "192.162.1.19",
                "DataCenter": "DC1"
            },
            {
                "Type":  "IaaSMgr",
                "Hostname":  "iaas-dc2",
                "DNSDomain":  "management.corp.local",
                "IPAddress":  "192.162.1.20",
                "DataCenter": "DC2"
            },
            {
                "Type":  "IaaSWeb",
                "Hostname":  "iaasweb-dc1",
                "DNSDomain":  "management.corp.local",
                "IPAddress":  "192.162.1.21",
                "DataCenter": "DC1"
            },
            {
                "Type":  "IaaSWeb",
                "Hostname":  "iaasweb-dc2",
                "DNSDomain":  "management.corp.local",
                "IPAddress":  "192.162.1.22",
                "DataCenter": "DC2"
            },
            {
                "Type":  "vRA",
                "Hostname":  "vra01",
                "DNSDomain":  "management.corp.local",
                "IPAddress":  "192.162.1.16",
                "DataCenter": "DC1"
            },
            {
                "Type":  "vRA",
                "Hostname":  "vra02",
                "DNSDomain":  "management.corp.local",
                "IPAddress":  "192.162.1.17",
                "DataCenter": "DC2"
            },
            {
                "Type":  "VRA",
                "Hostname":  "vra03",
                "DNSDomain":  "management.corp.local",
                "IPAddress":  "192.162.1.18",
                "DataCenter": "DC1"
            },
            {
                "Type":  "SQL",
                "Hostname":  "corpsql-dc1",
                "DNSDomain":  "management.corp.local",
                "IPAddress":  "192.162.48.26",
                "DataCenter": "DC1"
            },
            {
                "Type":  "SQL",
                "Hostname":  "corpsql-dc2",
                "DNSDomain":  "management.corp.local",
                "IPAddress":  "192.162.48.29",
                "DataCenter": "DC2"
            },
            {
                "Type":  "AD",
                "Hostname":  "corpdc-dc1",
                "DNSDomain":  "myac.gov.au",
                "IPAddress":  "192.164.63.1",
                "DataCenter": "DC1"
            },
            {
                "Type":  "AD",
                "Hostname":  "corpdc-dc2",
                "DNSDomain":  "myac.gov.au",
                "IPAddress":  "192.164.191.1",
                "DataCenter": "DC2"
            },
            {
                "Type":  "AD",
                "Hostname":  "corpdc-vmc",
                "DNSDomain":  "myac.gov.au",
                "IPAddress":  "192.163.191.1",
                "DataCenter": "VMC"
            }
    ],
    "Template": [

        {
            "Type": "IaaS",
            "OS": "windows2016",
            "Name": "corp_win16_std_20190611_1414_template"
        },
        {
            "Type": "IaaS",
            "OS": "windows2012r2",
            "Name": "corp_win12r2_std_20190612_1711_template"
        },
        {
            "Type": "IaaS",
            "OS": "rhel7",
            "Name": "corp_rhel75_20190514_927dd36e_template"
        }
    ]

}
"@


#endregion --- variables ------------------------------------------------------

<#
Add any variables you want passed into the Pester test script. The test script
must be set up to receive parameters (variables) like a function would be.
#>
$Params = @{
    #myVar = "myValue";
    CredMgmt = $credMgmt;
    JSONPayload = $jsonData;
}

#To save the result as an NUnit file add the following :  -OutputFile $pesterOutput -OutputFormat NUnitXml 
Invoke-Pester -Script @{ Path = "$($pesterScript)"; Parameters = $Params } -OutVariable PesterResults

$VerbosePreference = "SilentlyContinue"

Return
<#

Services that should be running on a functioning vRA 7.5 system.

Command> shell
Shell access is granted to root
root@vcenter-dc1 [ ~ ]# service-control --list
vmware-netdumper (VMware vSphere ESXi Dump Collector)
vmware-cm (VMware Component Manager)
vmware-statsmonitor (VMware Appliance Monitoring Service)
vmonapi (VMware Service Lifecycle Manager API)
vmware-perfcharts (VMware Performance Charts)
vmware-vapi-endpoint (VMware vAPI Endpoint)
vmware-vpxd-svcs (VMware vCenter-Services)
vmdird (VMware Directory Service)
vsphere-client (VMware vSphere Web Client)
vmware-vmon (VMware Service Lifecycle Manager)
vmware-eam (VMware ESX Agent Manager)
vsan-dps (VMware VSAN Data Protection Service)
vmware-postgres-archiver (VMware Postgres Archiver)
vmdnsd (VMware Domain Name Service)
applmgmt (VMware Appliance Management Service)
vmware-vpostgres (VMware Postgres)
vmware-rbd-watchdog (VMware vSphere Auto Deploy Waiter)
vmware-vpxd (VMware vCenter Server)
vsphere-ui (VMware vSphere Client)
vmware-sps (VMware vSphere Profile-Driven Storage Service)
vmware-rhttpproxy (VMware HTTP Reverse Proxy)
vmware-cis-license (VMware License Service)
vmware-mbcs (VMware Message Bus Configuration Service)
vmware-sts-idmd (VMware Identity Management Service)
vmware-vsan-health (VMware VSAN Health Service)
vmware-sca (VMware Service Control Agent)
vmware-vcha (VMware vCenter High Availability)
pschealth (VMware Platform Services Controller Health Monitor)
vmware-vsm (VMware vService Manager)
lwsmd (Likewise Service Manager)
vmafdd (VMware Authentication Framework)
vmcad (VMware Certificate Service)
vmware-stsd (VMware Security Token Service)
vmcam (VMware vSphere Authentication Proxy)
vmware-pod (VMware Patching and Host Management Service)
vmware-imagebuilder (VMware Image Builder Manager)
vmware-content-library (VMware Content Library Service)
vmware-updatemgr (VMware Update Manager)
vmware-analytics (VMware Analytics Service)
root@vcenter-dc1 [ ~ ]# service-control --status
Running:
 applmgmt lwsmd pschealth vmafdd vmcad vmdird vmdnsd vmonapi vmware-analytics vmware-cis-license vmware-cm vmware-content-library vmware-eam vmware-perfcharts vmware-pod vmware-postgres-archiver vmware-rhttpproxy vmware-sca vmware-sps vmware-statsmonitor vmware-sts-idmd vmware-stsd vmware-updatemgr vmware-vapi-endpoint vmware-vmon vmware-vpostgres vmware-vpxd vmware-vpxd-svcs vmware-vsan-health vmware-vsm vsphere-client vsphere-ui
Stopped:
 vmcam vmware-imagebuilder vmware-mbcs vmware-netdumper vmware-rbd-watchdog vmware-vcha vsan-dps

#>
