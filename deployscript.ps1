# user prompts
Write-host @"
                                                                                                                                                                                                    
                                                                                                                                                                                                    
          GGGGGGGGGGGGGhhhhhhh                                                        tttt               PPPPPPPPPPPPPPPPP                                                    tttt          lllllll 
       GGG::::::::::::Gh:::::h                                                     ttt:::t               P::::::::::::::::P                                                ttt:::t          l:::::l 
     GG:::::::::::::::Gh:::::h                                                     t:::::t               P::::::PPPPPP:::::P                                               t:::::t          l:::::l 
    G:::::GGGGGGGG::::Gh:::::h                                                     t:::::t               PP:::::P     P:::::P                                              t:::::t          l:::::l 
   G:::::G       GGGGGG h::::h hhhhh          ooooooooooo       ssssssssss   ttttttt:::::ttttttt           P::::P     P:::::Prrrrr   rrrrrrrrr       ccccccccccccccccttttttt:::::ttttttt     l::::l 
  G:::::G               h::::hh:::::hhh     oo:::::::::::oo   ss::::::::::s  t:::::::::::::::::t           P::::P     P:::::Pr::::rrr:::::::::r    cc:::::::::::::::ct:::::::::::::::::t     l::::l 
  G:::::G               h::::::::::::::hh  o:::::::::::::::oss:::::::::::::s t:::::::::::::::::t           P::::PPPPPP:::::P r:::::::::::::::::r  c:::::::::::::::::ct:::::::::::::::::t     l::::l 
  G:::::G    GGGGGGGGGG h:::::::hhh::::::h o:::::ooooo:::::os::::::ssss:::::stttttt:::::::tttttt           P:::::::::::::PP  rr::::::rrrrr::::::rc:::::::cccccc:::::ctttttt:::::::tttttt     l::::l 
  G:::::G    G::::::::G h::::::h   h::::::ho::::o     o::::o s:::::s  ssssss       t:::::t                 P::::PPPPPPPPP     r:::::r     r:::::rc::::::c     ccccccc      t:::::t           l::::l 
  G:::::G    GGGGG::::G h:::::h     h:::::ho::::o     o::::o   s::::::s            t:::::t                 P::::P             r:::::r     rrrrrrrc:::::c                   t:::::t           l::::l 
  G:::::G        G::::G h:::::h     h:::::ho::::o     o::::o      s::::::s         t:::::t                 P::::P             r:::::r            c:::::c                   t:::::t           l::::l 
   G:::::G       G::::G h:::::h     h:::::ho::::o     o::::ossssss   s:::::s       t:::::t    tttttt       P::::P             r:::::r            c::::::c     ccccccc      t:::::t    tttttt l::::l 
    G:::::GGGGGGGG::::G h:::::h     h:::::ho:::::ooooo:::::os:::::ssss::::::s      t::::::tttt:::::t     PP::::::PP           r:::::r            c:::::::cccccc:::::c      t::::::tttt:::::tl::::::l
     GG:::::::::::::::G h:::::h     h:::::ho:::::::::::::::os::::::::::::::s       tt::::::::::::::t     P::::::::P           r:::::r             c:::::::::::::::::c      tt::::::::::::::tl::::::l
       GGG::::::GGG:::G h:::::h     h:::::h oo:::::::::::oo  s:::::::::::ss          tt:::::::::::tt     P::::::::P           r:::::r              cc:::::::::::::::c        tt:::::::::::ttl::::::l
          GGGGGG   GGGG hhhhhhh     hhhhhhh   ooooooooooo     sssssssssss              ttttttttttt       PPPPPPPPPP           rrrrrrr                cccccccccccccccc          ttttttttttt  llllllll
                                                                                                                                                                                             
"@
$rgname = -join ((65..80) + (97..100) | Get-Random -Count 10 | % {[char]$_})
$vmname = -join ((65..80) + (97..100) | Get-Random -Count 14 | % {[char]$_})
$randomvmpasswd = -join ((0x30..0x39) + ( 0x41..0x5A) + ( 0x61..0x7A) | Get-Random -Count 20  | % {[char]$_}) # The password length must be between 12 and 72. Password must have the 3 of the following: 1 lower case character, 1 upper case character, 1 number and 1 special character.
#set location based on user input, else defaults to USEast
$loc = Read-Host -Prompt "Provide the location to host your VPN service [defaults to USA]"
if ([string]::IsNullOrWhiteSpace($loc))
{
$loc = "eastus2"
}
#self-destroy timmer
$timer = Read-Host -Prompt "Duration of VPN Service in incements of 1 hrs. [defaults to 1hr]"
if ([string]::IsNullOrWhiteSpace($timer))
{
$timer = 1
}

# Install chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install Azure CLi
choco install azure-cli -y

# After installing packages from chocolatey, refresh powershell environment variables
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Azure login
az login --output none

# Setup RG
az group create --name $rgname --location $loc --output none

# Create secure random password
$stringAsStream = [System.IO.MemoryStream]::new()
$writer = [System.IO.StreamWriter]::new($stringAsStream)
[string]$randValue = Get-Random
$writer.write("$randValue")
$writer.Flush()
$stringAsStream.Position = 0
[string]$randompass = Get-FileHash -InputStream $stringAsStream | Select-Object Hash -ExpandProperty Hash

# Setup VM with defaults and obtain the newly created machines public IP address
[string]$data = az vm create --resource-group $rgname --name $vmname --image UbuntuLTS --size Standard_DS1_v2 --authentication-type password --admin-username $vmname.ToLower() --admin-password $randomvmpasswd --public-ip-sku Standard # not working on student account --priority spot --eviction-policy Delete 
$json_data = ConvertFrom-JSON -InputObject $data
$machine_ip = $json_data.publicIpAddress

# Open ports to internet (remove port 22 for final release)
az vm open-port --port 443,22 --resource-group $rgname --name $vmname --output none

# converts to seconds
$timer_seconds = $timer*60*60
# Build up this command syntax
$command = {\"fileUris\": [\"https://raw.githubusercontent.com/G-PRTCL/startupscripts/main/startup.sh\"],\"commandToExecute\": \"./startup.sh {0} {1}\"} -f $randompass, $timer_seconds;
$command = "{"+$command+"}"
$command = "az vm extension set --resource-group $rgname --vm-name $vmname --name customScript --publisher Microsoft.Azure.Extensions --protected-settings '$command'"
$command = [scriptblock]::Create("$command")

# Install docker and run openvpn container (Asyncronous version of the command)
Start-Job -ScriptBlock $command

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
#echo "ghost_user`n${randompass}`n" > pass.txt

# login into open vpn using the config file
# openvpn --config ./GPRTCL-profile.ovpn --auth-user-pass pass.txt

# Remove the pass.txt file as it is no longer needed (leave no trace)
# del pass.txt

# Loop based on timer (in hours)
$loop_timeout = new-timespan -Seconds $timer_seconds
$sw = [diagnostics.stopwatch]::StartNew()
while ($sw.elapsed -lt $loop_timeout){
  start-sleep -seconds 1
}

Write-host " Deleting your VPN service"
az group delete --name $rgname --yes

# Delete the resource group and machine
# az group delete --resource-group openvpn --yes
# TODO: ADD THIS FEATURE: Az vm create (option to auto delete on shutdown)
