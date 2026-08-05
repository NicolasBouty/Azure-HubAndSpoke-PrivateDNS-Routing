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
