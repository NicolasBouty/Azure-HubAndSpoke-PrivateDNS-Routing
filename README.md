# Azure-HubAndSpoke-PrivateDNS-Routing
Architecture réseau Azure Hub-and-Spoke sécurisée avec NVA Ubuntu (sysctl, IP forwarding NIC), routage symétrique via UDR et résolution FQDN inter-VNets via Azure Private DNS Zone. Inclus : tests de transitivité, validation Network Watcher et captures tcpdump.
# ☁️ Architecture Hub-and-Spoke Azure : Routage NVA Linux & Résolution Private DNS

> **Projet d'Architecture Cloud & Sécurité Réseau (AZ-104)**  
> Mise en œuvre d'un modèle d'interconnexion *Hub-and-Spoke* sur Microsoft Azure avec inspection centralisée du trafic via une Appliance Virtuelle Réseau (NVA Ubuntu), routage sur-mesure (UDR) et résolution de noms FQDN inter-VNets via Azure Private DNS.

---

## 📐 1. Architecture & Adressage Réseau

Le projet repose sur 3 réseaux virtuels (VNets) sans Peering direct entre les Spokes pour forcer la transitivité via le Hub central.

| Ressource | VNet / Subnet | Adresse IP Privée | Rôle dans l'Architecture |
| :--- | :--- | :--- | :--- |
| **Hub-A-VNet** | `10.0.0.0/16` (`10.0.1.0/24`) | **VM-A** : `10.0.1.4` | **NVA (Routeur Linux)** |
| **Spoke-B-VNet** | `10.1.0.0/16` (`10.1.1.0/24`) | **VM-B** : `10.1.1.4` | Client Spoke B |
| **Spoke-C-VNet** | `10.2.0.0/16` (`10.2.1.4`) | **VM-C** : `10.2.1.4` | Client Spoke C |

---

## 🗺️ 2. Schéma d'Architecture (Flux & Routage)

```mermaid
graph LR
    subgraph Spoke_B [Spoke B : 10.1.0.0/16]
        VM_B[VM-B : 10.1.1.4]
    end

    subgraph Hub_A [Hub A : 10.0.0.0/16]
        NVA[VM-A / NVA : 10.0.1.4<br/>IP Forwarding = ON]
    end

    subgraph Spoke_C [Spoke C : 10.2.0.0/16]
        VM_C[VM-C : 10.2.1.4]
    end

    subgraph Private_DNS [Azure Private DNS Zone]
        DNS[internal.cloud]
    end

    VM_B -->|1. Ping vm-c.internal.cloud| DNS
    DNS -->|2. Résout 10.2.1.4| VM_B
    VM_B -->|3. UDR: Next Hop 10.0.1.4| NVA
    NVA -->|4. Forwarding Kernel| VM_C
    VM_C -->|5. UDR Retour: Next Hop 10.0.1.4| NVA
    NVA -->|6. Reponse ICMP| VM_B
