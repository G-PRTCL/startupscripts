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

# Setup VM with defaults and obtain the newly created machines public IP address
[string]$data = az vm create --resource-group openvpn --name openvpn --image UbuntuLTS --authentication-type password --admin-username azureuser --admin-password Capstone_8051**
$json_data = ConvertFrom-JSON -InputObject $data
$machine_ip = $json_data.publicIpAddress

# Open ports to internet
az vm open-port --port 943,9443,1194,22 --resource-group openvpn --name openvpn --output none

# Install docker and run openvpn container (Asyncronous version of the command)
Start-Job -ScriptBlock{az vm extension set --resource-group openvpn --vm-name openvpn --name customScript --publisher Microsoft.Azure.Extensions --protected-settings '{\"fileUris\": [\"https://raw.githubusercontent.com/G-PRTCL/startupscripts/main/startup.sh\"],\"commandToExecute\": \"./startup.sh\"}'}

# TODO: We need to check for connectivity, and once connected:

# Add check for this here!

# Pull down the user profile from the openvpn server and launch the client.
curl.exe -k -u ghost_user:test123 https://${machine_ip}:943/rest/"GetUserlogin" > GPRTCL-profile.ovpn

# Create a pass.txt file for openvpn login without prompt
echo "ghost_user`ntest123`n" > pass.txt

# login into open vpn using the config file
openvpn --config ./GPRTCL-profile.ovpn --auth-user-pass pass.txt

# Remove the pass.txt file as it is no longer needed (leave no trace)
del pass.txt

# Delete the resource group and machine
# az group delete --resource-group openvpn --yes
# TODO: ADD THIS FEATURE: Az vm create (option to auto delete on shutdown)