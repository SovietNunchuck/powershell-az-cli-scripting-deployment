# Setting variables
$studentName = "mitch"
$rgName = "$studentName-lc0820-ps-rg"
$vmName = "$studentName-lc0820-ps-vm"
$vmSize = "Standard_B2s"
$vmImage = $(az vm image list --query "[? contains(urn, 'Ubuntu')] | [0].urn")
$vmAdminUsername = "student"

$kvName = "$studentName-lc0820-ps-kv"
$kvSecretName = "ConnectionStrings--Default"
$kvSecretValue = "server=localhost;port=3306;database=coding_events;user=coding_events;password=launchcode"

az configure --default location=eastus

# Provision RG
az group create -n "$rgName"
az configure --default group=$rgName

# Provision VM
$vmData = $(az vm create -n $vmName --size $vmSize --image $vmImage --admin-username $vmAdminUsername --admin-password $(Read-Host "Authenticate to Azure (student)" -AsSecureString) --authentication-type password --assign-identity)
az configure --default vm=$vmName

# Capture the VM systemAssignedIdentity and IP Address
$vmId = $(az vm identity show --name $vmName --query "principalId").Trim('"')
$vmIp = $(az vm list-ip-addresses -n $vmName --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress").Trim('"')

# Open vm port 443
az vm open-port --port 443

# Provision KV
az keyvault create -n $kvName --enable-soft-delete false --enabled-for-deployment true

# Create KV secret (database connection string)
az keyvault secret set --vault-name $kvName --description 'connection string' --name $kvSecretName --value $kvSecretValue

# Set KV access-policy (using the vm ``systemAssignedIdentity``)
az keyvault set-policy --name $kvName --object-id $vmId --secret-permissions list get

# Send 3 bash scripts to the VM using az vm run-command invoke
az vm run-command invoke --command-id RunShellScript --scripts @vm-configuration-scripts/1configure-vm.sh
az vm run-command invoke --command-id RunShellScript --scripts @vm-configuration-scripts/2configure-ssl.sh
az vm run-command invoke --command-id RunShellScript --scripts @deliver-deploy.sh

# Print VM public IP address to STDOUT or save it as a file
Write-Host "VM available at $vmIp"