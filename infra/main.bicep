// ============================================================================
// AZURE HUB & SPOOKE ARCHITECTURE WITH NVA ROUTING & PRIVATE DNS
// ============================================================================

targetScope = 'resourceGroup'

@description('Région Azure pour le déploiement.')
param location string = resourceGroup().location

@description('Nom de l utilisateur administrateur des VMs.')
param adminUsername string = 'ubuadmin'

@description('Mot de passe administrateur sécurisé pour les VMs.')
@secure()
param adminPassword string

@description('Nom de la Zone DNS Privée.')
param dnsZoneName string = 'tp.internal'

// ----------------------------------------------------------------------------
// 1. TABLES DE ROUTAGE (UDR) POUR LES SPOKES
// ----------------------------------------------------------------------------
resource udrSpokeB 'Microsoft.Network/routeTables@2023-09-01' = {
  name: 'udr-spokeB'
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'To-SpokeC-via-NVA'
        properties: {
          addressPrefix: '10.2.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.1.4'
        }
      }
    ]
  }
}

resource udrSpokeC 'Microsoft.Network/routeTables@2023-09-01' = {
  name: 'udr-spokeC'
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'To-SpokeB-via-NVA'
        properties: {
          addressPrefix: '10.1.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.1.4'
        }
      }
    ]
  }
}

// ----------------------------------------------------------------------------
// 2. RÉSEAUX VIRTUELS & SOUS-RÉSEAUX (ASSOCIATION UDR INCLUSE)
// ----------------------------------------------------------------------------
resource vnetHubA 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'hubA'
  location: location
  properties: {
    addressSpace: { addressPrefixes: [ '10.0.0.0/16' ] }
    subnets: [
      {
        name: 'subnetA'
        properties: { addressPrefix: '10.0.1.0/24' }
      }
    ]
  }
}

resource vnetSpokeB 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'spokeB'
  location: location
  properties: {
    addressSpace: { addressPrefixes: [ '10.1.0.0/16' ] }
    subnets: [
      {
        name: 'subnetB'
        properties: {
          addressPrefix: '10.1.1.0/24'
          routeTable: { id: udrSpokeB.id } // Association explicite UDR
        }
      }
    ]
  }
}

resource vnetSpokeC 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'spokeC'
  location: location
  properties: {
    addressSpace: { addressPrefixes: [ '10.2.0.0/16' ] }
    subnets: [
      {
        name: 'subnetC'
        properties: {
          addressPrefix: '10.2.1.0/24'
          routeTable: { id: udrSpokeC.id } // Association explicite UDR
        }
      }
    ]
  }
}

// ----------------------------------------------------------------------------
// 3. PEERINGS VNET (AllowForwardedTraffic activé pour le transit NVA)
// ----------------------------------------------------------------------------
resource peerHubToSpokeB 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: vnetHubA
  name: 'hubA-to-spokeB'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    remoteVirtualNetwork: { id: vnetSpokeB.id }
  }
}

resource peerSpokeBToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: vnetSpokeB
  name: 'spokeB-to-hubA'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    remoteVirtualNetwork: { id: vnetHubA.id }
  }
}

resource peerHubToSpokeC 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: vnetHubA
  name: 'hubA-to-spokeC'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    remoteVirtualNetwork: { id: vnetSpokeC.id }
  }
}

resource peerSpokeCToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: vnetSpokeC
  name: 'spokeC-to-hubA'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    remoteVirtualNetwork: { id: vnetHubA.id }
  }
}

// ----------------------------------------------------------------------------
// 4. INTERFACES RÉSEAU & CONF NVA (enableIPForwarding = true sur vm-A)
// ----------------------------------------------------------------------------
resource nicVmA 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-vm-A'
  location: location
  properties: {
    enableIPForwarding: true // ⚠️ ESSENTIEL POUR LA NVA
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.1.4'
          subnet: { id: vnetHubA.properties.subnets[0].id }
        }
      }
    ]
  }
}

resource nicVmB 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-vm-B'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.1.1.4'
          subnet: { id: vnetSpokeB.properties.subnets[0].id }
        }
      }
    ]
  }
}

resource nicVmC 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-vm-C'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.2.1.4'
          subnet: { id: vnetSpokeC.properties.subnets[0].id }
        }
      }
    ]
  }
}

// ----------------------------------------------------------------------------
// 5. MACHINES VIRTUELLES & CLOUD-INIT (AUTOMATISATION LINUX)
// ----------------------------------------------------------------------------
// Provisionne automatiquement l'IP forwarding sur l'OS Linux de vm-A
var customDataNva = base64('''#cloud-config
write_files:
  - path: /etc/sysctl.d/99-ipforward.conf
    content: |
      net.ipv4.ip_forward=1
runcmd:
  - sysctl -p /etc/sysctl.d/99-ipforward.conf
  - ufw default allow forwarding
''')

resource vmA 'Microsoft.Compute/virtualMachines@2023-09-00' = {
  name: 'vm-A'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B1s' }
    osProfile: {
      computerName: 'vm-A'
      adminUsername: adminUsername
      adminPassword: adminPassword
      customData: customDataNva
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts'
        version: 'latest'
      }
      osDisk: { createOption: 'FromImage' }
    }
    networkProfile: { networkInterfaces: [ { id: nicVmA.id } ] }
  }
}

resource vmB 'Microsoft.Compute/virtualMachines@2023-09-00' = {
  name: 'vm-B'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B1s' }
    osProfile: { computerName: 'vm-B', adminUsername: adminUsername, adminPassword: adminPassword }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts'
        version: 'latest'
      }
      osDisk: { createOption: 'FromImage' }
    }
    networkProfile: { networkInterfaces: [ { id: nicVmB.id } ] }
  }
}

resource vmC 'Microsoft.Compute/virtualMachines@2023-09-00' = {
  name: 'vm-C'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B1s' }
    osProfile: { computerName: 'vm-C', adminUsername: adminUsername, adminPassword: adminPassword }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts'
        version: 'latest'
      }
      osDisk: { createOption: 'FromImage' }
    }
    networkProfile: { networkInterfaces: [ { id: nicVmC.id } ] }
  }
}

// ----------------------------------------------------------------------------
// 6. ZONE DNS PRIVÉE & LIAISONS VNET (INSCRIPTION AUTOMATIQUE)
// ----------------------------------------------------------------------------
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: dnsZoneName
  location: 'global'
}

resource dnsLinkHubA 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: 'hubA-dns'
  location: 'global'
  properties: {
    registrationEnabled: true // Auto-registration ON
    virtualNetwork: { id: vnetHubA.id }
  }
}

resource dnsLinkSpokeB 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: 'spokeB-dns'
  location: 'global'
  properties: {
    registrationEnabled: true
    virtualNetwork: { id: vnetSpokeB.id }
  }
}

resource dnsLinkSpokeC 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: 'spokeC-dns'
  location: 'global'
  properties: {
    registrationEnabled: true
    virtualNetwork: { id: vnetSpokeC.id }
  }
}

// OUTPUTS ENSEIGNANTS / DÉPLOYEURS
output nvaIpAddress string = nicVmA.properties.ipConfigurations[0].properties.privateIPAddress
output privateDnsZone string = privateDnsZone.name
