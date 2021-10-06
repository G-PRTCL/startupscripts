# Install chocolately
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install Azure CLi
choco install azure-cli -y # TODO: Make sure to either refresh the shell to get az command in PATH or switch to the dir with the az EXE.

# Once solution:
# 1) cmd.exe
# 2) refreshenv
# 3) az login ...

# Azure login
az login --output none

# Setup RG
az group create --name openvpn --location westus --output none

# Create secure random password
$stringAsStream = [System.IO.MemoryStream]::new()
$writer = [System.IO.StreamWriter]::new($stringAsStream)
[string]$randValue = Get-Random
$writer.write("$randValue")
$writer.Flush()
$stringAsStream.Position = 0
[string]$randompass = Get-FileHash -InputStream $stringAsStream | Select-Object Hash -ExpandProperty Hash

# Setup VM with defaults and obtain the newly created machines public IP address
[string]$data = az vm create --resource-group openvpn --name openvpn --image UbuntuLTS --authentication-type password --admin-username azureuser --admin-password Capstone_8051**
$json_data = ConvertFrom-JSON -InputObject $data
$machine_ip = $json_data.publicIpAddress

# TODO: Make this user input
$timer_seconds = 3000

# Open ports to internet (remove port 22 for final release)
az vm open-port --port 443,22 --resource-group openvpn --name openvpn --output none

# Build up this command syntax
$command = {\"fileUris\": [\"https://raw.githubusercontent.com/G-PRTCL/startupscripts/main/startup.sh\"],\"commandToExecute\": \"./startup.sh {0} {1}\"} -f $randompass $timer_seconds;
$command = "{"+$command+"}"
$command = "az vm extension set --resource-group openvpn --vm-name openvpn --name customScript --publisher Microsoft.Azure.Extensions --protected-settings '$command'"
$command = [scriptblock]::Create("$command")

# Install docker and run openvpn container (Asyncronous version of the command)
Start-Job -ScriptBlock $command
# Update start up script to move password variable into a file (into the github startup.sh).

# Start-Job -ScriptBlock{ az vm extension set --resource-group openvpn --vm-name openvpn --name customScript --publisher Microsoft.Azure.Extensions --protected-settings $command }


# TODO: Incoporate these into the script

# Convert the downloaded profile into UTF-8 format 
# [System.Io.File]::ReadAllText($FileName) | Out-File -FilePath $FileName -Encoding Ascii

# Command to connect to the openvpn
# .\OpenVPNConnect.exe --accept-gdpr --import-profile="C:\Program Files\OpenVPN Connect\GPRTCL-profile.ovpn" --username=ghost_user --password=182D24B6CBCEC2B2EFEABB22F7617C0D6AF02C3AE4E32DD183D761E6C9F98377 --minimize --hide-tray

# Endless loop, when the client profile is here, continue
While (!(Test-Path .\GPRTCL-profile.ovpn -ErrorAction SilentlyContinue)){
    # Pull down the user profile from the openvpn server and launch the client.
    curl.exe -k -u ghost_user:"${randompass}" https://${machine_ip}/rest/"GetUserlogin" -o GPRTCL-profile.ovpn
    sleep 1
}

# Create a pass.txt file for openvpn login without prompt
echo "ghost_user`n${randompass}`n" > pass.txt

# login into open vpn using the config file
openvpn --config ./GPRTCL-profile.ovpn --auth-user-pass pass.txt

# Remove the pass.txt file as it is no longer needed (leave no trace)
del pass.txt

# Delete the resource group and machine
# az group delete --resource-group openvpn --yes
# TODO: ADD THIS FEATURE: Az vm create (option to auto delete on shutdown)