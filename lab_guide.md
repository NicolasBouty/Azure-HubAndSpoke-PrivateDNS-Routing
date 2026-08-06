# 📖 Guide d'implémentation pas-à-pas (Lab)

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
