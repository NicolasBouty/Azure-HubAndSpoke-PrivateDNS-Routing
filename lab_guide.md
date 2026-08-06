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
