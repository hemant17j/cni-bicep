
param location string = resourceGroup().location

@secure()
param adminPassword Hemant@1234567

var networkResourceGroup = 'rg-appnet-dev-ea-01'
var vnetName = 'vnet-app-dev-ea-01'
var subnetName = 'subnet-app-dev-ea-01'

var vmName = 'vm-buildagent-001'
var vmSize = 'Standard_D4s_v5'
var adminUsername = 'hemant'

// Reference the existing virtual network.
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  scope: resourceGroup(networkResourceGroup)
  name: vnetName
}

// Reference the existing subnet.
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' existing = {
  parent: vnet
  name: subnetName
}


var bootstrapScript = loadTextContent('./scripts/bootstrap.ps1')
var bootstrapScriptBase64 = base64(bootstrapScript)

// Decode the script, write it to disk, and execute it.
var bootstrapCommand = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$s=[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(\'${bootstrapScriptBase64}\')); [System.IO.File]::WriteAllText(\'C:/bootstrap.ps1\', $s, (New-Object System.Text.UTF8Encoding($false))); & C:/bootstrap.ps1"'


// Deploy the Windows VM.
module vm '../module/windowserver.bicep' = {
  name: 'windowsVm'
  params: {
    vmName: vmName
    numberOfDatadisks: 0
    location: location
    vmDiskType: 'Premium_LRS'
    vmSize: vmSize
    administratorAccountUserName: adminUsername
    administratorAccountPassword: adminPassword
    existingVNETResourceGroup: networkResourceGroup
    existingVNETName: vnet.name
    existingSubnetName: subnet.name
    osVersion: '2022-datacenter'
  }
}

// Reference the VM deployed by the module.
resource deployedVm 'Microsoft.Compute/virtualMachines@2020-06-01' existing = {
  name: vmName
}

// Execute the bootstrap script after VM deployment.
resource bootstrapExtension 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = {
  parent: deployedVm
  name: 'bootstrap'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    forceUpdateTag: 'bootstrap-v1'
    protectedSettings: {
      commandToExecute: bootstrapCommand
    }
  }
  dependsOn: [
    vm
  ]
}
