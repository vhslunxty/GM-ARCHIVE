# 🛠️ GM-ARCHIVE ( v1.0 )

Infrastructure SQL robuste et optimisée pour Garry's Mod, conçue pour gérer plusieurs serveurs sur une base de données unique avec une sécurité renforcée par triggers.

## ✨ Fonctionnalités clés

* **Multi-Serveur** : Gérez tous vos serveurs (Sandbox, DarkRP, TTT) via une structure centralisée.
* **Sécurité Native** : Triggers SQL pour empêcher le ban automatique des SuperAdmins.
* **Performance** : Utilisation de procédures stockées pour réduire la charge côté Lua.
* **Audit Complet** : Logs automatiques des actions administratives et du chat.
* **Analyses** : Vues SQL pré-configurées pour les leaderboards et les joueurs en ligne.

## 📂 Contenu du Projet

1.  `01_schema.sql` : Création des tables, index et relations (InnoDB/utf8mb4).
2.  `02_seed.sql` : Données initiales (Rangs par défaut, serveurs d'exemples).
3.  `03_procedures_security.sql` : Intelligence du système (Fonctions de join/leave, bans, sécurité).

## 🚀 Installation Rapide

1. Importer les fichiers dans l'ordre numérique dans votre gestionnaire MySQL (HeidiSQL, phpMyAdmin).
2. Configurez vos accès dans `03_procedures_security.sql`.
3. Connectez votre serveur GMod via le module **MySQLOO**.

## 📊 Statistiques Suivies
* Temps de jeu (Global et par serveur).
* Combat (Kills/Deaths/Ratio).
* Sandbox (Props spawnés/sauvegardés).
