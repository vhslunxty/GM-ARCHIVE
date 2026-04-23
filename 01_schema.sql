SET FOREIGN_KEY_CHECKS = 0;
SET SQL_MODE = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

CREATE DATABASE IF NOT EXISTS `gmod_db`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE `gmod_db`;

CREATE TABLE IF NOT EXISTS `servers` (
  `id`           TINYINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `name`         VARCHAR(64)       NOT NULL,
  `gamemode`     VARCHAR(32)       NOT NULL DEFAULT 'sandbox',
  `map`          VARCHAR(64)       NOT NULL DEFAULT 'gm_construct',
  `max_players`  TINYINT UNSIGNED  NOT NULL DEFAULT 16,
  `ip`           VARCHAR(45)       NOT NULL,           -- IPv4 ou IPv6
  `port`         SMALLINT UNSIGNED NOT NULL DEFAULT 27015,
  `is_active`    TINYINT(1)        NOT NULL DEFAULT 1,
  `created_at`   DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_server_ip_port` (`ip`, `port`),
  INDEX `idx_gamemode` (`gamemode`)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Référentiel des serveurs GMod';


CREATE TABLE IF NOT EXISTS `players` (
  `id`             BIGINT UNSIGNED   NOT NULL AUTO_INCREMENT,
  `steamid64`      BIGINT UNSIGNED   NOT NULL,             -- ex: 76561198000000000
  `steamid`        VARCHAR(24)       NOT NULL,             -- ex: STEAM_0:1:123456
  `name`           VARCHAR(64)       NOT NULL,
  `avatar_url`     VARCHAR(512)      NULL,
  `country_code`   CHAR(2)           NULL,
  `is_banned`      TINYINT(1)        NOT NULL DEFAULT 0,
  `first_join`     DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_seen`      DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `total_playtime` INT UNSIGNED      NOT NULL DEFAULT 0    COMMENT 'Secondes cumulées',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_steamid64`  (`steamid64`),
  UNIQUE KEY `uq_steamid`    (`steamid`),
  INDEX `idx_name`            (`name`),
  INDEX `idx_is_banned`       (`is_banned`),
  INDEX `idx_last_seen`       (`last_seen`)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Profils Steam des joueurs';

CREATE TABLE IF NOT EXISTS `groups` (
  `id`            TINYINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `name`          VARCHAR(32)       NOT NULL,
  `display_name`  VARCHAR(64)       NOT NULL,
  `color_hex`     CHAR(7)           NOT NULL DEFAULT '#FFFFFF' COMMENT 'Couleur HEX #RRGGBB',
  `is_default`    TINYINT(1)        NOT NULL DEFAULT 0,
  `priority`      TINYINT UNSIGNED  NOT NULL DEFAULT 0    COMMENT 'Plus élevé = plus de droits',
  `can_kick`      TINYINT(1)        NOT NULL DEFAULT 0,
  `can_ban`       TINYINT(1)        NOT NULL DEFAULT 0,
  `can_spawn`     TINYINT(1)        NOT NULL DEFAULT 1,
  `can_noclip`    TINYINT(1)        NOT NULL DEFAULT 0,
  `can_slay`      TINYINT(1)        NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_group_name` (`name`),
  INDEX `idx_priority`        (`priority`)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Groupes et permissions GMOD';

CREATE TABLE IF NOT EXISTS `player_groups` (
  `player_id`    BIGINT UNSIGNED   NOT NULL,
  `server_id`    TINYINT UNSIGNED  NOT NULL,
  `group_id`     TINYINT UNSIGNED  NOT NULL,
  `granted_by`   BIGINT UNSIGNED   NULL      COMMENT 'player.id de l\'admin',
  `granted_at`   DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `expires_at`   DATETIME          NULL      COMMENT 'NULL = permanent',
  PRIMARY KEY (`player_id`, `server_id`),
  CONSTRAINT `fk_pg_player`    FOREIGN KEY (`player_id`)  REFERENCES `players` (`id`)  ON DELETE CASCADE  ON UPDATE CASCADE,
  CONSTRAINT `fk_pg_server`    FOREIGN KEY (`server_id`)  REFERENCES `servers` (`id`)  ON DELETE CASCADE  ON UPDATE CASCADE,
  CONSTRAINT `fk_pg_group`     FOREIGN KEY (`group_id`)   REFERENCES `groups`  (`id`)  ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_pg_granter`   FOREIGN KEY (`granted_by`) REFERENCES `players` (`id`)  ON DELETE SET NULL ON UPDATE CASCADE,
  INDEX `idx_pg_group`   (`group_id`),
  INDEX `idx_pg_expires` (`expires_at`)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Affectation rang/groupe par serveur';

CREATE TABLE IF NOT EXISTS `sessions` (
  `id`           BIGINT UNSIGNED   NOT NULL AUTO_INCREMENT,
  `player_id`    BIGINT UNSIGNED   NOT NULL,
  `server_id`    TINYINT UNSIGNED  NOT NULL,
  `ip_address`   VARCHAR(45)       NOT NULL,
  `joined_at`    DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `left_at`      DATETIME          NULL,
  `duration`     INT UNSIGNED      GENERATED ALWAYS AS (
                    TIMESTAMPDIFF(SECOND, `joined_at`, IFNULL(`left_at`, NOW()))
                  ) VIRTUAL          COMMENT 'Durée calculée en secondes',
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_sess_player`  FOREIGN KEY (`player_id`) REFERENCES `players` (`id`) ON DELETE CASCADE  ON UPDATE CASCADE,
  CONSTRAINT `fk_sess_server`  FOREIGN KEY (`server_id`) REFERENCES `servers` (`id`) ON DELETE CASCADE  ON UPDATE CASCADE,
  INDEX `idx_sess_player`   (`player_id`),
  INDEX `idx_sess_server`   (`server_id`),
  INDEX `idx_sess_joined`   (`joined_at`),
  INDEX `idx_sess_active`   (`left_at`)              -- NULL = joueur encore connecté
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Historique des connexions/sessions';

CREATE TABLE IF NOT EXISTS `bans` (
  `id`           INT UNSIGNED      NOT NULL AUTO_INCREMENT,
  `player_id`    BIGINT UNSIGNED   NOT NULL,
  `server_id`    TINYINT UNSIGNED  NULL      COMMENT 'NULL = ban global tous serveurs',
  `banned_by`    BIGINT UNSIGNED   NULL,
  `reason`       VARCHAR(512)      NOT NULL DEFAULT 'Aucune raison fournie',
  `duration`     INT UNSIGNED      NULL      COMMENT 'Secondes, NULL = permanent',
  `banned_at`    DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `expires_at`   DATETIME          GENERATED ALWAYS AS (
                    IF(`duration` IS NULL, NULL, DATE_ADD(`banned_at`, INTERVAL `duration` SECOND))
                  ) STORED,
  `unbanned_at`  DATETIME          NULL,
  `unbanned_by`  BIGINT UNSIGNED   NULL,
  `is_active`    TINYINT(1)        NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_ban_player`     FOREIGN KEY (`player_id`)  REFERENCES `players` (`id`) ON DELETE CASCADE  ON UPDATE CASCADE,
  CONSTRAINT `fk_ban_server`     FOREIGN KEY (`server_id`)  REFERENCES `servers` (`id`) ON DELETE CASCADE  ON UPDATE CASCADE,
  CONSTRAINT `fk_ban_admin`      FOREIGN KEY (`banned_by`)  REFERENCES `players` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_ban_unadmin`    FOREIGN KEY (`unbanned_by`)REFERENCES `players` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  INDEX `idx_ban_player`      (`player_id`),
  INDEX `idx_ban_active`      (`is_active`),
  INDEX `idx_ban_expires`     (`expires_at`)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Bans temporaires et permanents';

CREATE TABLE IF NOT EXISTS `admin_logs` (
  `id`           BIGINT UNSIGNED   NOT NULL AUTO_INCREMENT,
  `server_id`    TINYINT UNSIGNED  NOT NULL,
  `admin_id`     BIGINT UNSIGNED   NULL,
  `target_id`    BIGINT UNSIGNED   NULL,
  `action`       ENUM(
                    'kick','ban','unban','slay','noclip',
                    'promote','demote','warn','spawn',
                    'map_change','server_restart','other'
                  ) NOT NULL,
  `detail`       TEXT              NULL,
  `logged_at`    DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_al_server`  FOREIGN KEY (`server_id`) REFERENCES `servers` (`id`) ON DELETE CASCADE  ON UPDATE CASCADE,
  CONSTRAINT `fk_al_admin`   FOREIGN KEY (`admin_id`)  REFERENCES `players` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_al_target`  FOREIGN KEY (`target_id`) REFERENCES `players` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  INDEX `idx_al_server`    (`server_id`),
  INDEX `idx_al_admin`     (`admin_id`),
  INDEX `idx_al_action`    (`action`),
  INDEX `idx_al_logged`    (`logged_at`)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Audit complet des actions admin';

CREATE TABLE IF NOT EXISTS `warns` (
  `id`           INT UNSIGNED      NOT NULL AUTO_INCREMENT,
  `player_id`    BIGINT UNSIGNED   NOT NULL,
  `server_id`    TINYINT UNSIGNED  NOT NULL,
  `issued_by`    BIGINT UNSIGNED   NULL,
  `reason`       VARCHAR(512)      NOT NULL,
  `issued_at`    DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `is_active`    TINYINT(1)        NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_warn_player`  FOREIGN KEY (`player_id`) REFERENCES `players` (`id`) ON DELETE CASCADE  ON UPDATE CASCADE,
  CONSTRAINT `fk_warn_server`  FOREIGN KEY (`server_id`) REFERENCES `servers` (`id`) ON DELETE CASCADE  ON UPDATE CASCADE,
  CONSTRAINT `fk_warn_admin`   FOREIGN KEY (`issued_by`) REFERENCES `players` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  INDEX `idx_warn_player`  (`player_id`),
  INDEX `idx_warn_active`  (`is_active`)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Avertissements joueurs';

CREATE TABLE IF NOT EXISTS `prop_saves` (
  `id`           INT UNSIGNED      NOT NULL AUTO_INCREMENT,
  `player_id`    BIGINT UNSIGNED   NOT NULL,
  `server_id`    TINYINT UNSIGNED  NOT NULL,
  `name`         VARCHAR(128)      NOT NULL,
  `map`          VARCHAR(64)       NOT NULL,
  `data`         MEDIUMTEXT        NOT NULL COMMENT 'JSON sérialisé du duplication',
  `prop_count`   SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `saved_at`     DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`   DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_ps_player`  FOREIGN KEY (`player_id`) REFERENCES `players` (`id`) ON DELETE CASCADE  ON UPDATE CASCADE,
  CONSTRAINT `fk_ps_server`  FOREIGN KEY (`server_id`) REFERENCES `servers` (`id`) ON DELETE CASCADE  ON UPDATE CASCADE,
  INDEX `idx_ps_player`  (`player_id`),
  INDEX `idx_ps_map`     (`map`),
  FULLTEXT INDEX `ft_ps_name` (`name`)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Sauvegardes de props (Duplicator/Advanced Duplicator)';

CREATE TABLE IF NOT EXISTS `chat_logs` (
  `id`           BIGINT UNSIGNED   NOT NULL AUTO_INCREMENT,
  `player_id`    BIGINT UNSIGNED   NULL,
  `server_id`    TINYINT UNSIGNED  NOT NULL,
  `channel`      ENUM('global','team','admin','ooc','pm') NOT NULL DEFAULT 'global',
  `message`      TEXT              NOT NULL,
  `logged_at`    DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_cl_player`  FOREIGN KEY (`player_id`) REFERENCES `players` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_cl_server`  FOREIGN KEY (`server_id`) REFERENCES `servers` (`id`) ON DELETE CASCADE  ON UPDATE CASCADE,
  INDEX `idx_cl_player`   (`player_id`),
  INDEX `idx_cl_server`   (`server_id`),
  INDEX `idx_cl_logged`   (`logged_at`),
  FULLTEXT INDEX `ft_cl_message` (`message`)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Historique complet du chat';

CREATE TABLE IF NOT EXISTS `player_stats` (
  `player_id`        BIGINT UNSIGNED   NOT NULL,
  `server_id`        TINYINT UNSIGNED  NOT NULL,
  `kills`            INT UNSIGNED      NOT NULL DEFAULT 0,
  `deaths`           INT UNSIGNED      NOT NULL DEFAULT 0,
  `props_spawned`    INT UNSIGNED      NOT NULL DEFAULT 0,
  `props_deleted`    INT UNSIGNED      NOT NULL DEFAULT 0,
  `playtime`         INT UNSIGNED      NOT NULL DEFAULT 0  COMMENT 'Secondes sur ce serveur',
  `score`            INT               NOT NULL DEFAULT 0,
  `last_updated`     DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`player_id`, `server_id`),
  CONSTRAINT `fk_pst_player`  FOREIGN KEY (`player_id`) REFERENCES `players` (`id`) ON DELETE CASCADE  ON UPDATE CASCADE,
  CONSTRAINT `fk_pst_server`  FOREIGN KEY (`server_id`) REFERENCES `servers` (`id`) ON DELETE CASCADE  ON UPDATE CASCADE,
  INDEX `idx_pst_score`   (`score`),
  INDEX `idx_pst_kills`   (`kills`)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Stats agrégées par joueur et par serveur';

CREATE TABLE IF NOT EXISTS `server_settings` (
  `server_id`    TINYINT UNSIGNED  NOT NULL,
  `setting_key`  VARCHAR(64)       NOT NULL,
  `value`        TEXT              NULL,
  `updated_at`   DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`server_id`, `setting_key`),
  CONSTRAINT `fk_ss_server`  FOREIGN KEY (`server_id`) REFERENCES `servers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Configuration flexible par serveur';

SET FOREIGN_KEY_CHECKS = 1;