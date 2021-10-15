# Print the project name for the user
Write-host @"
     ________               __     ____             __                   __
    / ____/ /_  ____  _____/ /_   / __ \_________  / /_____  _________  / /
   / / __/ __ \/ __ \/ ___/ __/  / /_/ / ___/ __ \/ __/ __ \/ ___/ __ \/ / 
  / /_/ / / / / /_/ (__  ) /_   / ____/ /  / /_/ / /_/ /_/ / /__/ /_/ / /  
  \____/_/ /_/\____/____/\__/  /_/   /_/   \____/\__/\____/\___/\____/_/   
  *************************************************************************
"@

# Initilizing variables
$rgname = -join ((65..80) + (97..100) | Get-Random -Count 10 | % {[char]$_})
$vmname = -join ((65..80) + (97..100) | Get-Random -Count 14 | % {[char]$_})
$winvmname = -join ((65..80) + (97..100) | Get-Random -Count 14 | % {[char]$_})
$randomvmpasswd = -join ((0x30..0x39) + ( 0x41..0x5A) + ( 0x61..0x7A) | Get-Random -Count 20  | % {[char]$_}) # The password length must be between 12 and 72. Password must have the 3 of the following: 1 lower case character, 1 upper case character, 1 number and 1 special character.

# List of Azure region ids that we support: https://azureprice.net/regions
$region_ids = @("australiacentral","australiacentral2","australiaeast","australiasoutheast","brazilsouth","brazilsoutheast","canadacentral","canadaeast","centralindia",
                "centralus","eastasia","eastus","eastus2","francecentral","francesouth","germanynorth","germanywestcentral","japaneast","japanwest","jioindiawest",
                "koreacentral","koreasouth","northcentralus","northeurope","norwayeast","norwaywest","southafricanorth","southafricawest","southcentralus","southeastasia",
                "southindia","switzerlandnorth","switzerlandwest","uaecentral","uaenorth","uksouth","ukwest","usgovarizona","usgovtexas","usgovvirginia","westcentralus",
                "westeurope","westindia","westus","westus2","westus3")

# Set location based on user input, else defaults to certral US
$loc = Read-Host -Prompt "Provide the region to host your VPN service [defaults to USA]"
if ([string]::IsNullOrWhiteSpace($loc) -or !$region_ids.Contains($loc)){
  write-host "Using default region id"
  $loc = "centralus"
}

# Self-destroy timer
$timer = Read-Host -Prompt "Duration of VPN Service in incements of 1 hrs. [defaults to 1hr] This service costs 5 cents per hour" ## Please reword
$timer_int = ($timer -as [int])
if ([string]::IsNullOrWhiteSpace($timer) -or ($timer_int -eq $null)){
  write-host "Using default timer"
  $timer = 1
}

# Install openvpn daemon (if not already present on host machine)
if(!(Test-Path -Path "C:\Program Files\OpenVPN\bin\openvpn.exe" -ErrorAction SilentlyContinue)){
  write-host "Installing VPN client"
  Invoke-WebRequest -Uri "https://swupdate.openvpn.org/community/releases/OpenVPN-2.5.4-I602-amd64.msi" -OutFile .\OpenVPN-2.5.4-I602-amd64.msi
  msiexec /i OpenVPN-2.5.4-I602-amd64.msi /quiet

  # Clean up after ourselves
  del OpenVPN-2.5.4-I602-amd64.msi
}

# Install chocolatey and Azure cli 
if(!(Test-Path -Path "C:\ProgramData\chocolatey\bin\choco.exe" -ErrorAction SilentlyContinue)){
  write-host "Installing Chocolatey"
  Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')) | Out-Null
}

choco install azure-cli -y | Out-Null

# After installing packages from chocolatey, refresh powershell environment variables and set the path to openvpn daemon
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
$env:Path += ";C:\Program Files\OpenVPN\bin"

# Azure login
write-host "Logging into Azure"
az login --only-show-errors --output none

# Setup RG
write-host "Setting up Resource Group"
[string]$rgdata = az group create --name $rgname --location $loc --only-show-errors
$rgjson = ConvertFrom-Json -InputObject $rgdata
$rgid = $rgjson.id

# Create secure random password for use within OpenVpn
$stringAsStream = [System.IO.MemoryStream]::new()
$writer = [System.IO.StreamWriter]::new($stringAsStream)
[string]$randValue = Get-Random
$writer.write("$randValue")
$writer.Flush()
$stringAsStream.Position = 0
[string]$randompass = Get-FileHash -InputStream $stringAsStream | Select-Object Hash -ExpandProperty Hash

# Setup VM with defaults and obtain the newly created machines public IP address
write-host "Creating VM"
[string]$data = az vm create --resource-group $rgname --name $vmname --image UbuntuLTS --size Standard_DS1_v2 --authentication-type password --admin-username $vmname.ToLower() --admin-password $randomvmpasswd --public-ip-sku Standard --assign-identity [system] --accelerated-networking true --ephemeral-os-disk true --only-show-errors # not supported for student accounts --priority spot --eviction-policy Delete --encryption-at-host true 
$json_data = ConvertFrom-JSON -InputObject $data
$machine_ip = $json_data.publicIpAddress
sleep 5

write-host "Role Assignment to enable self destruction" # TODO: Refine this statement for users to understand!
az role assignment create --assignee $json_data.identity.systemAssignedIdentity --role "Contributor" --scope $rgid --only-show-errors --output none

# Get local network details
[string]$network = az network vnet list --resource-group $rgname --only-show-errors
$json_network = ConvertFrom-JSON -InputObject $network

# Open ports to internet (remove port 22 for final release)
az vm open-port --port 443,22 --resource-group $rgname --name $vmname --only-show-errors --output none
Write-host "Initiaiting OpenVPN deployment"

# Convert to seconds
$timer_seconds = $timer*60*60

# Build up this command syntax
write-host "Setting timer on VM for self-destruction"
$command = {\"fileUris\": [\"https://raw.githubusercontent.com/G-PRTCL/startupscripts/main/startup.sh\"],\"commandToExecute\": \"./startup.sh {0} {1} {2}\"} -f $randompass,$timer_seconds,$rgname;
$command = "{"+$command+"}"
$command = "az vm extension set --resource-group $rgname --vm-name $vmname --name customScript --publisher Microsoft.Azure.Extensions --protected-settings '$command' --only-show-errors"
$command = [scriptblock]::Create("$command")
sleep 5

# Install docker and run openvpn container (Asyncronous version of the command)
Start-Job -ScriptBlock $command | Out-Null

# Deploys windows machine into existing network, keeping the VM in the same RG to enable self destruct 
# TODO: make this a optional based on user input
Write-Host "Setting up VDI"
[string]$winvm = az vm create --resource-group $rgname --name $winvmname --vnet-name $json_network.name --subnet $json_network.subnets.name --image Win2019Datacenter --admin-username $vmname.ToLower() --admin-password $randomvmpasswd --only-show-errors # not supported for student accounts --priority spot --eviction-policy Delete --encryption-at-host true
$json_winvm = ConvertFrom-JSON -InputObject $winvm
$win_machine_ip = $json_winvm.publicIpAddress

Write-host -NoNewline "Downloading profile ..."

# Endless loop, when the client profile is here, continue
While (!(Test-Path .\GPRTCL-profile.ovpn -ErrorAction SilentlyContinue)){

  # Pull down the user profile silently from the openvpn server
  $profile = curl.exe -k -s -u ghost_user:"${randompass}" https://${machine_ip}/rest/"GetUserlogin"

  # Determine if correct profile was obtained.
  if ($profile -like "*ghost_user@${machine_ip}*"){
    curl.exe -k -s -u ghost_user:"${randompass}" https://${machine_ip}/rest/"GetUserlogin" -o GPRTCL-profile.ovpn
    Write-host "DONE!"
    break
  }
  sleep 3
  Write-host -NoNewline "."
}

Write-host "Connecting to VPN"

# Create a pass.txt file for openvpn login without prompt
New-Item .\pass.txt | Out-Null; Set-Content .\pass.txt "ghost_user`n${randompass}"

# Login into open vpn using the config file
openvpn --config .\GPRTCL-profile.ovpn --auth-user-pass .\pass.txt | Out-Null

# Start-Process -FilePath "openvpn" -ArgumentList "--config .\GPRTCL-profile.ovpn --auth-user-pass .\pass.txt" -NoNewWindow
# Start-Process -FilePath "openvpn" -ArgumentList "--config .\GPRTCL-profile.ovpn --auth-user-pass .\pass.txt" -WindowStyle Hidden

# Remove the pass.txt and GPRTCL-profile.ovpn files as they are no longer needed (leave no trace)
del pass.txt , GPRTCL-profile.ovpn

# Write-host "Looping until self-destruction"
# # Loop based on timer (in hours)
# $loop_timeout = new-timespan -Seconds $timer_seconds
# $sw = [diagnostics.stopwatch]::StartNew()
# while ($sw.elapsed -lt $loop_timeout){
#   start-sleep -seconds 1
# }

# # Delete the resource group and machine
# Write-host "Deleting your VPN service"
# az group delete --name $rgname --yes
