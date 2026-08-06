@description('Nom de l\'utilisateur administrateur pour les VMs')
param adminUsername string = 'ubuadmin'

@description('Mot de passe administrateur pour les VMs')
@secure()
param adminPassword string

@description('Région Azure pour le déploiement')
param location string = 'francecentral'

// ---------------------------------------------------------------------------
// 1. NETWORK SECURITY GROUPS (NSG)
// ---------------------------------------------------------------------------

resource nsgVmA 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'vm-A-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-Spokes-To-Hub'
        properties: {
          description: 'Autorise le trafic entrant venant des deux Spokes'
          protocol: 'ICMP'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefixes: [
            '10.1.0.0/16'
            '10.2.0.0/16'
          ]
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-Hub-To-Spokes'
        properties: {
          description: 'Permet a la NVA de reemetre le trafic vers les Spokes'
          protocol: 'ICMP'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefixes: [
            '10.1.0.0/16'
            '10.2.0.0/16'
          ]
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
    ]
  }
}

resource nsgVmB 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'vm-B-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-Hub-And-SpokeC-Inbound'
        properties: {
          description: 'Autorise le trafic entrant du Hub et de Spoke C'
          protocol: 'ICMP'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefixes: [
            '10.0.0.0/16'
            '10.2.0.0/16'
          ]
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-SpokeB-To-Hub-And-SpokeC'
        properties: {
          description: 'Permet d envoyer du trafic vers le Hub A et Spoke C'
          protocol: 'ICMP'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefixes: [
            '10.0.0.0/16'
            '10.2.0.0/16'
          ]
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
    ]
  }
}

resource nsgVmC 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'vm-C-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-Hub-And-SpokeB-Inbound'
        properties: {
          description: 'Autorise le trafic entrant du Hub et de Spoke B'
          protocol: 'ICMP'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefixes: [
            '10.0.0.0/16'
            '10.1.0.0/16'
          ]
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-SpokeC-To-Hub-And-SpokeB'
        properties: {
          description: 'Permet d envoyer du trafic vers le Hub A et Spoke B'
          protocol: 'ICMP'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefixes: [
            '10.0.0.0/16'
            '10.1.0.0/16'
          ]
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// 2. TABLES DE ROUTAGE (UDR)
// ---------------------------------------------------------------------------

resource udrSpokeB 'Microsoft.Network/routeTables@2023-11-01' = {
  name: 'udr-spokeB'
  location: location
  properties: {
    routes: [
      {
        name: 'To-SpokeC'
        properties: {
          addressPrefix: '10.2.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.1.4'
        }
      }
    ]
  }
}

resource udrSpokeC 'Microsoft.Network/routeTables@2023-11-01' = {
  name: 'udr-spokeC'
  location: location
  properties: {
    routes: [
      {
        name: 'To-SpokeB'
        properties: {
          addressPrefix: '10.1.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.1.4'
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// 3. RESEAUX VIRTUELS (VNETS & SUBNETS)
// ---------------------------------------------------------------------------

resource vnetHubA 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: 'hubA'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'subnetA'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
    ]
  }
}

resource vnetSpokeB 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: 'spokeB'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'subnetB'
        properties: {
          addressPrefix: '10.1.1.0/24'
          routeTable: {
            id: udrSpokeB.id
          }
        }
      }
    ]
  }
}

resource vnetSpokeC 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: 'spokeC'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.2.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'subnetC'
        properties: {
          addressPrefix: '10.2.1.0/24'
          routeTable: {
            id: udrSpokeC.id
          }
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// 4. VNET PEERINGS
// ---------------------------------------------------------------------------

resource peeringHubAToB 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = {
  parent: vnetHubA
  name: 'hubA-to-spokeB'
  properties: {
    remoteVirtualNetwork: {
      id: vnetSpokeB.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
  }
}

resource peeringHubAToC 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = {
  parent: vnetHubA
  name: 'hubA-to-spokeC'
  properties: {
    remoteVirtualNetwork: {
      id: vnetSpokeC.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
  }
}

resource peeringSpokeBToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = {
  parent: vnetSpokeB
  name: 'spokeB-to-hubA'
  properties: {
    remoteVirtualNetwork: {
      id: vnetHubA.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
  }
}

resource peeringSpokeCToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = {
  parent: vnetSpokeC
  name: 'spokeC-to-hubA'
  properties: {
    remoteVirtualNetwork: {
      id: vnetHubA.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
  }
}

// ---------------------------------------------------------------------------
// 5. INTERFACES RESEAU (NIC)
// ---------------------------------------------------------------------------

resource nicVmA 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: 'nic-vm-A'
  location: location
  properties: {
    enableIPForwarding: true
    networkSecurityGroup: {
      id: nsgVmA.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddress: '10.0.1.4'
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: vnetHubA.properties.subnets[0].id
          }
        }
      }
    ]
  }
}

resource nicVmB 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: 'nic-vm-B'
  location: location
  properties: {
    networkSecurityGroup: {
      id: nsgVmB.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddress: '10.1.1.4'
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: vnetSpokeB.properties.subnets[0].id
          }
        }
      }
    ]
  }
}

resource nicVmC 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: 'nic-vm-C'
  location: location
  properties: {
    networkSecurityGroup: {
      id: nsgVmC.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddress: '10.2.1.4'
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: vnetSpokeC.properties.subnets[0].id
          }
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// 6. MACHINES VIRTUELLES (VMs) + CLOUD-INIT
// ---------------------------------------------------------------------------

var customDataNva = base64('''#cloud-config
write_files:
  - path: /etc/sysctl.d/99-ipforward.conf
    content: |
      net.ipv4.ip_forward=1
runcmd:
  - sysctl -p /etc/sysctl.d/99-ipforward.conf
  - ufw default allow forwarding
''')

resource vmA 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-A'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2als_v7'
    }
    storageProfile: {
      imageReference: {
        publisher: 'canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    osProfile: {
      computerName: 'vm-A'
      adminUsername: adminUsername
      adminPassword: adminPassword
      customData: customDataNva
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicVmA.id
        }
      ]
    }
  }
}

resource vmB 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-B'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2als_v7'
    }
    storageProfile: {
      imageReference: {
        publisher: 'canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    osProfile: {
      computerName: 'vm-B'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicVmB.id
        }
      ]
    }
  }
}

resource vmC 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-C'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2als_v7'
    }
    storageProfile: {
      imageReference: {
        publisher: 'canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    osProfile: {
      computerName: 'vm-C'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicVmC.id
        }
      ]
    }
  }
}

// ---------------------------------------------------------------------------
// 7. PRIVATE DNS ZONE & LINKS
// ---------------------------------------------------------------------------

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'tp.internal'
  location: 'global'
}

resource dnsLinkHubA 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDnsZone
  name: 'huba-dns'
  location: 'global'
  properties: {
    registrationEnabled: true
    virtualNetwork: {
      id: vnetHubA.id
    }
  }
}

resource dnsLinkSpokeB 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDnsZone
  name: 'spokeb-dns'
  location: 'global'
  properties: {
    registrationEnabled: true
    virtualNetwork: {
      id: vnetSpokeB.id
    }
  }
}

resource dnsLinkSpokeC 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDnsZone
  name: 'spokec-dns'
  location: 'global'
  properties: {
    registrationEnabled: true
    virtualNetwork: {
      id: vnetSpokeC.id
    }
  }
}
