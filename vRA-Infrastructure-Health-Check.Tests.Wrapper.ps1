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


TODO:  SSH to vCenter for service status?  eg vsphere-ui - although we do not own the password
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
            "Protocol": "https",
            "api": "",
            "vamiPort": "5480",
            "tenant": "vsphere.local",
            "healthAPI": ""
        },
        {
            "Type": "vRO",
            "FQDN": "vra-app-prd.management.corp.local",
            "Port": "443",
            "Protocol": "https",
            "api": "/vco/api",
            "healthAPI": ""
        },
        {
            "Type": "IaaSMgr",
            "FQDN": "vra-mgr-prd.management.corp.local",
            "Port": "",
            "Protocol": "https",
            "api": "",
            "healthAPI": "/VMPS2"
        },
        {
            "Type": "IaaSMgr",
            "FQDN": "vra-mgr-prd.management.corp.local",
            "Port": "",
            "Protocol": "https",
            "api": "",
            "healthAPI": "/VMPSProvision"
        },
        {
            "Type": "IaaSMgr",
            "FQDN": "vra-mgr-prd.management.corp.local",
            "Port": "",
            "Protocol": "https",
            "api": "",
            "healthAPI": "/VMPS2Proxy"
        },
        {
            "Type": "IaaSWeb",
            "FQDN": "vra-web-prd.management.corp.local",
            "Port": "",
            "Protocol": "https",
            "api": "",
            "healthAPI": "/WAPI/api/status"
        },
        {
            "Type":  "LogInsight",
            "FQDN":  "vrli1-dc1",
            "Port": "",
            "Protocol": "https",
            "api": "",
            "healthAPI": "",
            "IgnoreCert": "true"
        },
        {
            "Type":  "NSXT",
            "FQDN":  "nsxmvp1-dc1",
            "Port": "",
            "Protocol": "https",
            "api": "",
            "healthAPI": ""
        },
        {
            "Type":  "NSXT",
            "FQDN":  "nsxmvp1-cbr2",
            "Port": "",
            "Protocol": "https",
            "api": "",
            "healthAPI": ""
        }
    ],
    "Server": [
        {
            "Type":  "vCenter",
            "Hostname":  "vc1-dc1",
            "DNSDomain":  "management.corp.local",
            "IPAddress":  "192.164.58.21",
            "DataCenter": "DC1"
        },
        {
            "Type":  "vCenter",
            "Hostname":  "vc1-cbr2",
            "DNSDomain":  "management.corp.local",
            "IPAddress":  "192.164.186.21",
            "DataCenter": "CBR2"
        },
        {
            "Type":  "vCenter",
            "Hostname":  "vcenter",
            "DNSDomain":  "sddc.vmwarevmc.com",
            "IPAddress":  "192.163.174.4",
            "DataCenter": "VMC"
        },
        {
            "Type":  "IaaSMgr",
            "Hostname":  "dc1wprdvdp01",
            "DNSDomain":  "management.corp.local",
            "IPAddress":  "192.162.1.19",
            "DataCenter": "DC1"
        },
        {
            "Type":  "IaaSMgr",
            "Hostname":  "dc2wprdvdp01",
            "DNSDomain":  "management.corp.local",
            "IPAddress":  "192.162.1.20",
            "DataCenter": "CBR2"
        },
        {
            "Type":  "IaaSWeb",
            "Hostname":  "dc1wprdvwm01",
            "DNSDomain":  "management.corp.local",
            "IPAddress":  "192.162.1.21",
            "DataCenter": "DC1"
        },
        {
            "Type":  "IaaSWeb",
            "Hostname":  "dc2wprdvwm01",
            "DNSDomain":  "management.corp.local",
            "IPAddress":  "192.162.1.22",
            "DataCenter": "CBR2"
        },
        {
            "Type":  "vRA",
            "Hostname":  "dc1aprdvaa01",
            "DNSDomain":  "management.corp.local",
            "IPAddress":  "192.162.1.16",
            "DataCenter": "DC1"
        },
        {
            "Type":  "vRA",
            "Hostname":  "dc2aprdvaa02",
            "DNSDomain":  "management.corp.local",
            "IPAddress":  "192.162.1.17",
            "DataCenter": "CBR2"
        },
        {
            "Type":  "VRA",
            "Hostname":  "dc1aprdvaa03",
            "DNSDomain":  "management.corp.local",
            "IPAddress":  "192.162.1.18",
            "DataCenter": "DC1"
        },
        {
            "Type":  "SQL",
            "Hostname":  "dc1wprdsql04",
            "DNSDomain":  "management.corp.local",
            "IPAddress":  "192.162.48.26",
            "DataCenter": "DC1"
        },
        {
            "Type":  "SQL",
            "Hostname":  "dc2wprdsql04",
            "DNSDomain":  "management.corp.local",
            "IPAddress":  "192.162.48.29",
            "DataCenter": "CBR2"
        },
        {
            "Type":  "AD",
            "Hostname":  "DC1WPRDADS1",
            "DNSDomain":  "subdomain.corp.local",
            "IPAddress":  "192.164.63.1",
            "DataCenter": "DC1"
        },
        {
            "Type":  "AD",
            "Hostname":  "DC2WPRDADS1",
            "DNSDomain":  "subdomain.corp.local",
            "IPAddress":  "192.164.191.1",
            "DataCenter": "CBR2"
        },
        {
            "Type":  "AD",
            "Hostname":  "DC3WPRDADS1",
            "DNSDomain":  "subdomain.corp.local",
            "IPAddress":  "192.163.191.1",
            "DataCenter": "VMC"
        },
        {
            "Type":  "AD",
            "Hostname":  "DC1WPPDADS1",
            "DNSDomain":  "nonprod.subdomain.corp.local",
            "IPAddress":  "192.164.63.17",
            "DataCenter": "DC1"
        },
        {
            "Type":  "AD",
            "Hostname":  "DC2WPPDADS1",
            "DNSDomain":  "nonprod.subdomain.corp.local",
            "IPAddress":  "192.164.191.17",
            "DataCenter": "CBR2"
        },
        {
            "Type":  "AD",
            "Hostname":  "DC3WPPDADS1",
            "DNSDomain":  "nonprod.subdomain.corp.local",
            "IPAddress":  "192.163.191.17",
            "DataCenter": "VMC"
        },
        {
            "Type":  "LogInsight",
            "Hostname":  "vrlim1-dc1",
            "DNSDomain":  "management.corp.local",
            "IPAddress":  "192.164.58.25",
            "DataCenter": "DC1"
        },
        {
            "Type":  "LogInsight",
            "Hostname":  "vrliw1-dc1",
            "DNSDomain":  "management.corp.local",
            "IPAddress":  "192.164.58.26",
            "DataCenter": "DC1"
        },
        {
            "Type":  "LogInsight",
            "Hostname":  "vrliw2-dc1",
            "DNSDomain":  "management.corp.local",
            "IPAddress":  "192.164.58.27",
            "DataCenter": "DC1"
        },
        {
            "Type":  "NSXTMgr",
            "Hostname":  "nsxm1-dc1",
            "DNSDomain":  "management.corp.local",
            "IPAddress":  "192.164.58.31",
            "DataCenter": "DC1"
        },
        {
            "Type":  "NSXTMgr",
            "Hostname":  "nsxm2-dc1",
            "DNSDomain":  "management.corp.local",
            "IPAddress":  "192.164.58.32",
            "DataCenter": "DC1"
        },        
        {
            "Type":  "NSXTMgr",
            "Hostname":  "nsxm3-dc1",
            "DNSDomain":  "management.corp.local",
            "IPAddress":  "192.164.58.33",
            "DataCenter": "DC1"
        },       
        {
            "Type":  "NSXTMgr",
            "Hostname":  "nsxm1-cbr2",
            "DNSDomain":  "management.corp.local",
            "IPAddress":  "192.164.186.31",
            "DataCenter": "CBR2"
        },
        {
            "Type":  "NSXTMgr",
            "Hostname":  "nsxm2-cbr2",
            "DNSDomain":  "management.corp.local",
            "IPAddress":  "192.164.186.32",
            "DataCenter": "CBR2"
        },        
        {
            "Type":  "NSXTMgr",
            "Hostname":  "nsxm3-cbr2",
            "DNSDomain":  "management.corp.local",
            "IPAddress":  "192.164.186.33",
            "DataCenter": "CBR2"
        },
        {
            "Type":  "vRNI",
            "Hostname":  "vrnipt1-dc1",
            "DNSDomain":  "management.corp.local",
            "IPAddress":  "192.164.58.60",
            "DataCenter": "DC1"
        },
        {
            "Type":  "vRNI",
            "Hostname":  "vrnipt1-cbr2",
            "DNSDomain":  "management.corp.local",
            "IPAddress":  "192.164.186.60",
            "DataCenter": "DC1"
        },
        {
            "Type":  "vRNI",
            "Hostname":  "vrnipx1-dc1",
            "DNSDomain":  "management.corp.local",
            "IPAddress":  "192.164.58.61",
            "DataCenter": "DC1"
        },
        {
            "Type":  "vRNI",
            "Hostname":  "vrnipx1-cbr2",
            "DNSDomain":  "management.corp.local",
            "IPAddress":  "192.164.186.61",
            "DataCenter": "CBR2"
        },
        {
            "Type":  "vRNI",
            "Hostname":  "vrnipx1-vmc",
            "DNSDomain":  "management.corp.local",
            "IPAddress":  "192.163.191.61",
            "DataCenter": "VMC"
        },
        {
            "Type":  "vIDM",
            "Hostname":  "vidm1-dc1",
            "DNSDomain":  "management.corp.local",
            "IPAddress":  "192.164.58.55",
            "DataCenter": "DC1"
        },
        {
            "Type":  "vIDM",
            "Hostname":  "vidm1-cbr2",
            "DNSDomain":  "management.corp.local",
            "IPAddress":  "192.164.186.55",
            "DataCenter": "CBR2"
        }
    ],
    "Template": [

        {
            "Type": "IaaS",
            "OS": "windows2016",
            "Name": "win16_std_20190611_1414_template"
        },
        {
            "Type": "IaaS",
            "OS": "windows2012r2",
            "Name": "win12r2_std_20190612_1711_template"
        },
        {
            "Type": "IaaS",
            "OS": "rhel7",
            "Name": "rhel75_20190514_927dd36e_template"
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
    #ParamName = "myParamValue";
    Credential = $credMgmt;
    JSONPayload = $jsonData;
    ICMP = $true;
    vCenter = $true;
    vRA = $true;
    vRO = $true;
    vRAIaaS = $true;
    NSXT = $true;
    LogInsight = $true;

}

#To save the result as an NUnit file add the following :  -OutputFile $pesterOutput -OutputFormat NUnitXml 
Invoke-Pester -Script @{ Path = "$($pesterScript)"; Parameters = $Params } -OutVariable PesterResults

$VerbosePreference = "SilentlyContinue"

Return
<#


Service JSON Template
        {
            "Type": "",
            "FQDN": "",
            "Port": "",
            "Protocol": "",
            "api": "",
            "vamiPort": "",
            "tenant": "",
            "HealthAPI": "",
            "IgnoreCert": "true"
        },

Service designed for load balanced systems or points of entry.
Could add IP address, however some environments do not do reverse look
ups for load balancers. could be added as another item and if IP Address
is set, then test it. If not then skip it.
tenant is only used by vRA at this point.

IgnoreCert is for those servers where certificate replacement has not been done
or the system running the Pester tests does not trust the certificate.
Not fully implemented yet. - Only done for LogInsight


Server JSON template

            {
                "Type":  "",
                "Hostname":  "",
                "DNSDomain":  "subdomain.corp.local",
                "IPAddress":  "10.",
                "DataCenter": ""
            }

vCenter template template

        {
            "Type": "",
            "OS": "",
            "Name": "<name of template>"
        }

Break out template into new section? ie out of vCenter?
as not all environments will be replicating to all vCenters?
Possibly add an optional vCenter value. if set then only check
this vCenter. Or may have to be an array of vCenters.


Add new section of health checking to test Ports?
Port scanning by telnet?
If wanting health check multiple ports?
Add extra server config
or
Make into array of ports. then add some logic to handle single vs array
or
Create a port scan section in JSON payload.


#>

<#

Services that should be running on a functioning VCSA 6.5 

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
