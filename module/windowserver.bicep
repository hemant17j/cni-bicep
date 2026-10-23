param vmName string

param numberOfDatadisks int

param location string

param vmDiskType string

param vmSize string

param administratorAccountUserName string

@secure()
param administratorAccountPassword string

param existingVNETResourceGroup string

param existingVNETName string

param existingSubnetName string

param enableDcrAssociation bool = false

param perf_log_dcr_rule_id string

param windows_event_log_dcr_rule_id string

// Domain join

param domainFQDN string = 'kestra.local'

param domainJoinUserName string

param ouPath string = 'OU-AVD, OU-Azure, OU-Workstations, OU-KestraCorporate, DC=kestra, DC=local'

@secure()
param domainJoinUserPassword string

param osVersion string = '2016-Datacenter'

var subnetId = resourceId(
  existingVNETResourceGroup,
  'Microsoft.Network/virtualNetworks/subnets',
  existingVNETName,
  existingSubnetName
)

var networkAdapterPostfix = 'nic'

resource nic 'Microsoft.Network/networkInterfaces@2020-06-01' = {
  name: '${vmName}-${networkAdapterPostfix}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
        }
      }
    ]
  }
}

resource dataDisk 'Microsoft.Compute/disks@2022-03-02' [for i in range(0, numberOfDatadisks): {
  location: location
  name: '${vmName}-datadisk${i}'
  sku: {
    name: 'Premium_LRS'
  }
  properties: {
    creationData: {
      createOption: 'Empty'
    }
    diskSizeGB: 128
    maxShares: 1
    tier: 'P10'
    osType: 'Windows'
  }
}]

resource vm 'Microsoft.Compute/virtualMachines@2020-06-01' = {
  name: vmName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    licenseType: 'Windows_Client'
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: administratorAccountUserName
      adminPassword: administratorAccountPassword
    }
    storageProfile: {
      osDisk: {
        name: '${vmName}-osdisk'
        managedDisk: {
          storageAccountType: vmDiskType
        }
        osType: 'Windows'
        createOption: 'FromImage'
      }
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: osVersion
        version: 'latest'
      }
      dataDisks: [
        for i in range(0, numberOfDatadisks): {
          lun: i
          caching: 'ReadWrite'
          createOption: 'Attach'
          managedDisk: {
            id: dataDisk[i].id
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    securityProfile: {
      encryptionAtHost: true
    }
  }
  dependsOn: [
    nic
    dataDisk
  ]
}

resource perfLogsDcrAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2021-04-01' = if (enableDcrAssociation) {
  name: '${vmName}-perf_log_dcr'
  scope: vm
  properties: {
    dataCollectionRuleId: perf_log_dcr_rule_id
    description: 'DCR association for ${vmName}'
  }
}

resource eventLogDcrAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2021-04-01' = if (enableDcrAssociation) {
  name: '${vmName}-events_log_dcr'
  scope: vm
  properties: {
    dataCollectionRuleId: windows_event_log_dcr_rule_id
    description: 'DCR association for ${vmName}'
  }
}
