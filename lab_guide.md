## Guide d'implémentation pas-à-pas (Lab)

Ce document retrace les étapes d'implémentation de l'architecture réseau Hub-and-Spoke.

---

## 1. Création des VNets et des Sous-réseaux

Déploiement des trois réseaux virtuels dans le groupe de ressources `grp_tpaz104_05` :
* **hubA** : `10.0.0.0/16` (subnet `10.0.1.0/24`)
* **spokeB** : `10.1.0.0/16` (subnet `10.1.1.0/24`)
* **spokeC** : `10.2.0.0/16` (subnet `10.2.1.0/24`)

<img width="1330" height="300" alt="vnet-creation-overview" src="https://github.com/user-attachments/assets/0df74693-e278-4199-bb45-98a7883c5e80" />

---

## 2. Configuration des Peerings (Hub-and-Spoke)

Mise en place de la topologie réseau en étoile (Hub-and-Spoke) avec l'option **Allow Forwarded Traffic** :
* Création du peering bidirectionnel entre **hubA** et **spokeB** (`hubA-to-spokeB` / `spokeB-to-hubA`).
* Création du peering bidirectionnel entre **hubA** et **spokeC** (`hubA-to-spokeC` / `spokeC-to-hubA`).
* Activation du **trafic transféré** (*Allow Forwarded Traffic*) sur l'ensemble des liens pour autoriser le futur routage via la NVA.
* Absence volontaire de peering entre `spokeB` et `spokeC` (isolation réseau).

<img width="1291" height="159" alt="perring" src="https://github.com/user-attachments/assets/e6022fa6-1cb3-47a5-81c0-697d8579c160" />

---

## 3. Déploiement des Machines Virtuelles (VMs)

Déploiement des 3 machines virtuelles Linux (Ubuntu Server) dans leurs sous-réseaux respectifs, sans IP publique (accès d'administration via la Console Série Azure) :
* **`vm-A`** : Placée dans `hubA` (`subnetA` - `10.0.1.4`) — Rôle : NVA / Routeur
* **`vm-B`** : Placée dans `spokeB` (`subnetB` - `10.1.1.4`) — Rôle : Machine hôte Spoke B
* **`vm-C`** : Placée dans `spokeC` (`subnetC` - `10.2.1.4`) — Rôle : Machine hôte Spoke C

<img width="1184" height="426" alt="vm-disque-nic" src="https://github.com/user-attachments/assets/6e8705aa-d142-426c-849e-3a3e0dc3e803" />

---

## 4. Configuration du transfert IP Azure sur la NVA

Afin de permettre à `vm-A` d'agir comme un routeur réseau (Virtual Network Appliance - NVA) et de retransmettre le trafic entre les Spokes, le transfert IP (IP Forwarding) a été activé au niveau de l'interface réseau (NIC) d'Azure.

* **Interface Réseau :** `vm-a823_z1` (NIC de `vm-A`)
* **Paramètre :** `Activer le transfert IP` = **Activé**
* **IP Privée :** `10.0.1.4`

<img width="696" height="197" alt="transfert-ip2" src="https://github.com/user-attachments/assets/c2c055e9-2271-4cef-831c-832576b624c1" />

---

## 5. Configuration du système d'exploitation de la NVA (vm-A)

Afin de transformer la machine virtuelle `vm-A` en routeur (NVA), la configuration réseau du système d'exploitation Ubuntu a été ajustée via la Console Série :

1. **Activation de l'IP Forwarding IPv4 (Noyau Linux) :**
   * Activation à chaud : `net.ipv4.ip_forward = 1`
   * Persistance au redémarrage via `/etc/sysctl.conf`
2. **Configuration du Pare-feu (UFW) :**
   * Modification de la politique de transfert par défaut de `DROP` vers `ACCEPT` dans `/etc/default/ufw` pour autoriser le relai des paquets (Ping / ICMP et trafic transitant).
   * Rechargement des règles du pare-feu (`Firewall is active and enabled`).

<img width="890" height="240" alt="conf-vm-A" src="https://github.com/user-attachments/assets/e0fe58e7-f946-450f-a64e-b92d00692254" />

---

## 6. Configuration des Network Security Groups (NSG)

Afin d'autoriser le trafic ICMP (ping) à travers la topologie Hub-and-Spoke tout en appliquant le principe du moindre privilège, des règles spécifiques ont été appliquées sur chaque NSG :

1. **Hub NSG (`vm-A-nsg`) :**
   - **Inbound (`Allow-Spokes-To-Hub`) :** Autorise ICMP depuis `10.1.0.0/16, 10.2.0.0/16` (Priorité 100).
   - **Outbound (`Allow-Hub-To-Spokes`) :** Autorise ICMP vers `10.1.0.0/16, 10.2.0.0/16` (Priorité 100).

<img width="1155" height="178" alt="nsg-hub" src="https://github.com/user-attachments/assets/162727de-37b0-4b74-90bc-10bdbf1fec3c" />

2. **Spoke B NSG (`vm-B-nsg`) :**
   - **Inbound (`Allow-Hub-And-SpokeC`) :** Autorise ICMP depuis `10.0.0.0/16, 10.2.0.0/16` (Priorité 100).
   - **Outbound (`Allow-SpokeB-To-Hub-And-SpokeC`) :** Autorise ICMP vers `10.0.0.0/16, 10.2.0.0/16` (Priorité 100).

<img width="1169" height="171" alt="nsg-spokeB" src="https://github.com/user-attachments/assets/e2611311-062a-4c59-bcb3-15dd2cd35571" />

3. **Spoke C NSG (`vm-C-nsg`) :**
   - **Inbound (`Allow-Hub-And-SpokeB`) :** Autorise ICMP depuis `10.0.0.0/16, 10.1.0.0/16` (Priorité 100).
   - **Outbound (`Allow-SpokeC-To-Hub-And-SpokeB`) :** Autorise ICMP vers `10.0.0.0/16, 10.1.0.0/16` (Priorité 100).

<img width="1171" height="180" alt="nsg-spokeC" src="https://github.com/user-attachments/assets/a3714106-3f61-4cfb-b69a-f70059fa738b" />

---

## 7. Configuration du Routage Personnalisé (UDR)

Par défaut, l'appairage VNet (Peering) n'est pas transitif. Pour permettre la communication inter-spokes à travers la VM NVA (`10.0.1.4`), deux tables de routage personnalisées ont été créées et associées :

1. **Table de routage `udr-spokeB` :**
   - **Nom de la route :** `To-SpokeC`
   - **Destination :** `10.2.0.0/16` (Spoke C)
   - **Next Hop Type :** `Virtual Appliance`
   - **Next Hop Address :** `10.0.1.4` (VM-A / NVA Hub)
   - **Association :** Appliquée au sous-réseau `subnetB` (`spokeB`)

<img width="1299" height="97" alt="udr-spokeB" src="https://github.com/user-attachments/assets/96198400-7504-4138-8f2f-127b4eb63b36" />

2. **Table de routage `udr-spokeC` :**
   - **Nom de la route :** `To-SpokeB`
   - **Destination :** `10.1.0.0/16` (Spoke B)
   - **Next Hop Type :** `Virtual Appliance`
   - **Next Hop Address :** `10.0.1.4` (VM-A / NVA Hub)
   - **Association :** Appliquée au sous-réseau `subnetC` (`spokeC`)
  
<img width="1298" height="97" alt="udr-spokeC" src="https://github.com/user-attachments/assets/2870e8b9-008a-4db7-9d67-79a4333a8001" />

Les tables de routage sont associées a leur subnet respectif

---

## 8. Validation du Routage et Transit Inter-Spokes (NVA)

Afin de valider la configuration des tables de routage (UDR), du transfert IP (*IP Forwarding*) et de la NVA (`vm-A`), deux tests de connectivité ont été réalisés depuis la machine **`vm-B`** (Spoke B - `10.1.1.4`) vers **`vm-C`** (Spoke C - `10.2.1.4`).

### 1. Test de connectivité ICMP (Ping)
- **Commande :** `ping 10.2.1.4`
- **Résultat :** Communication établie avec **0% de perte de paquets**.
- **Analyse TTL :** Le TTL de réponse est de **63** (au lieu de 64 par défaut sur Linux), ce qui confirme le passage des paquets par un routeur intermédiaire (*1 hop*).

### 2. Traçage de route (Tracepath)
- **Commande :** `tracepath 10.2.1.4`
- **Résultat :** 
  1. `10.0.1.4` (NVA / Hub A)
  2. `10.2.1.4` (`vm-C` atteinte)
- **Conclusion :** Le premier saut s'effectue bien sur la VM Hub (`10.0.1.4`), prouvant que le trafic est correctement intercepté et routé par la NVA au lieu d'emprunter un chemin direct.

<img width="821" height="344" alt="ping-tracep" src="https://github.com/user-attachments/assets/c2514ddd-0535-4bb6-a748-0a935344ed8a" />

---

## 9. Configuration de la Zone DNS Privée (Private DNS Zone)

Pour permettre la résolution de noms de domaine internes (FQDN) sans passer par des adresses IP statiques hardcodées, une **Zone DNS Privée Azure** a été mise en place.

### 1. Déploiement de la zone DNS
- **Nom de la zone :** `tp.internal`
- **Groupe de ressources :** `grp_tpaz104_05`

### 2. Liaisons de Réseau Virtuel (Virtual Network Links)
La zone DNS a été associée aux 3 réseaux virtuels de l'architecture. L'option **Inscription automatique** (*Auto-registration*) a été activée pour permettre à Azure de créer dynamiquement les enregistrements A correspondant aux cartes réseau des machines virtuelles :

- **`hubA-dns`** → Réseau virtuel `hubA` *(Auto-registration : Activé)*
- **`spokeB-dns`** → Réseau virtuel `spokeB` *(Auto-registration : Activé)*
- **`spokeC-dns`** → Réseau virtuel `spokeC` *(Auto-registration : Activé)*

<img width="1059" height="225" alt="liensDNS" src="https://github.com/user-attachments/assets/d9b82558-6356-4593-99fa-f705c6d7e0ca" />

### 3. Validation de la résolution et connectivité FQDN
Depuis la VM **`vm-B`**, la résolution DNS ainsi que la joignabilité via le nom de domaine complet (FQDN) ont été testées avec succès :

- **Commande :** `nslookup vm-C.tp.internal`  
  - *Résultat :* Traduction exacte du nom FQDN vers l'adresse IP `10.2.1.4`.
- **Commande :** `ping vm-C.tp.internal`  
  - *Résultat :* Paquets transmis avec **0% de perte** et un TTL de **63**, prouvant que la résolution DNS fonctionne et que le trafic continue de transiter de manière sécurisée par la NVA (`10.0.1.4`).

<img width="701" height="386" alt="testDNS" src="https://github.com/user-attachments/assets/f3a509bf-28e9-4445-bb44-ec1f39725ffe" />

---

## 10. Déploiement automatisé (Infrastructure as Code - Bicep)

L'intégralité de cette architecture (VNets, Peerings, UDR, NVA Linux préconfigurée, VMs et Zone DNS Privée) est déployable automatiquement via le code **Bicep** fourni dans le dossier `/infra`.

### 📋 Prérequis
* Un abonnement Azure actif.
* [Azure CLI](https://learn.microsoft.com/fr-fr/cli/azure/install-azure-cli) installé localement (ou via le Azure Cloud Shell).

### ⚙️ Options de personnalisation (Paramètres)

Avant de lancer le déploiement, vous pouvez personnaliser l'infrastructure en modifiant le fichier `infra/parameters.bicepparam` ou via la ligne de commande :

| Paramètre | Description | Valeur par défaut |
| :--- | :--- | :--- |
| **`location`** | Région Azure où déployer les ressources | `'francecentral'` |
| **`adminUsername`** | Nom de l'utilisateur administrateur des VMs | `'ubuadmin'` |
| **`dnsZoneName`** | Nom de la Zone DNS Privée Azure | `'tp.internal'` |
| **`adminPassword`** | Mot de passe administrateur sécurisé | *(Demandé au déploiement)* |


### 🚀 Étapes de déploiement

#### 1. Cloner le dépôt et se connecter à Azure

```bash
git clone [https://github.com/NicolasBouty/Azure-HubAndSpoke-PrivateDNS-Routing.git](https://github.com/NicolasBouty/Azure-HubAndSpoke-PrivateDNS-Routing.git)
cd Azure-HubAndSpoke-PrivateDNS-Routing
az login
