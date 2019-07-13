<#
.SYNOPSIS
  Keep ESXi system properly patched
.DESCRIPTION
  By staying up to date on ESXi patches, vulnerabilities in the hypervisor can 
  be mitigated. An educated attacker can exploit known vulnerabilities when 
  attempting to attain access or elevate privileges on an ESXi host.
  Requires access to the internet or a source that contains the latest version
  information to compare the current infrastructure against.
.PARAMETER VersionSource
  Default being the internet 4.0+ : https://kb.vmware.com/s/article/2143832
  Option to point to a file todo: 
.NOTES
  Author: Clint Fritz

#>

#Define variable script blocks for Select-Object
$esxtype = @{Name="ESX"; Expression={$_.Config.Product.ProductLineId} }
$version = @{Name="Version"; Expression={$_.Config.Product.Version} }
$build = @{Name="Build"; Expression={$_.Config.Product.Build} }
 
#Get list of all the esx hosts
$vmhostlist = Get-View -ViewType HostSystem -Property Name, Config.Product.ProductLineId, Config.Product.Version, Config.Product.Build -Filter @{"Config.Product.ProductLineId"="embeddedEsx"}
 
#Create ESXi Version count report
$esxiversions = $vmhostlist | Select Name, $esxtype, $version, $build | Group Build | Select Count, @{Name="Version"; Expression={$_.Group[0].Version} }, @{Name="Build"; Expression={$_.Name} }  | Sort-Object Version -Descending

