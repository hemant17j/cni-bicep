var networkResourceGroup = 'rg-network-stg'

var vnetName = 'vnet-shared-stg'

var subnetName = 'application'

var vmName = 'vm-buildagent-001'

var vmSize = 'Standard_D4s_v5'

var location = resourceGroup().location

var adminUsername = 'localadmin'

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  scope: resourceGroup(networkResourceGroup)
  name: vnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' existing = {
  parent: vnet
  name: subnetName
}

@secure()
param adminPassword string

param domainJoinUsername string

@secure()
param domainJoinPassword string

var bootstrapCommand = 'powershell -ExecutionPolicy Unrestricted -Command "$s=[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(\'${base64(loadTextContent(\'./scripts/bootstrap.ps1\'))}\')); Set-Content -Path C:\\bootstrap.ps1 -Value $s; & C:\\bootstrap.ps1"'

module vm '../modules/windows-vm.bicep' = {
  name: 'windowsVm'
  params: {
    vmName: vmName
    location: location
    numberOfDatadisks: 0
    vmDiskType: 'Premium_LRS'
    vmSize: vmSize
    administratorAccountUserName: adminUsername
    administratorAccountPassword: adminPassword
    existingVNETResourceGroup: networkResourceGroup
    existingVNETName: vnet.name
    existingSubnetName: subnet.name
    domainJoinUserName: domainJoinUsername
    domainJoinUserPassword: domainJoinPassword
    osVersion: '2022-datacenter'
  }
}

resource deployedVm 'Microsoft.Compute/virtualMachines@2020-06-01' existing = {
  name: vmName
}

resource bootstrapExtension 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = {
  name: '${vmName}/bootstrap'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    forceUpdateTag: utcNow()
    protectedSettings: {
      commandToExecute: bootstrapCommand
    }
  }
  dependsOn: [
    vm
  ]
}
