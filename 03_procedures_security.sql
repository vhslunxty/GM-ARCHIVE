USE `gmod_db`;

DELIMITER //

CREATE OR REPLACE VIEW `v_online_players` AS
SELECT
    p.id,
    p.steamid64,
    p.name,
    s.server_id,
    srv.name        AS server_name,
    srv.gamemode,
    s.joined_at,
    TIMESTAMPDIFF(MINUTE, s.joined_at, NOW()) AS minutes_online,
    g.display_name  AS `rank`,
    g.color_hex     AS rank_color
FROM `sessions` s
JOIN `players`  p   ON p.id        = s.player_id
JOIN `servers`  srv ON srv.id      = s.server_id
LEFT JOIN `player_groups` pg ON pg.player_id = p.id AND pg.server_id = s.server_id
LEFT JOIN `groups`        g  ON g.id         = pg.group_id
WHERE s.left_at IS NULL
//

CREATE OR REPLACE VIEW `v_active_bans` AS
SELECT
    b.id,
    p.steamid64,
    p.name          AS player_name,
    b.reason,
    b.banned_at,
    b.expires_at,
    b.duration,
    adm.name        AS banned_by_name,
    srv.name        AS server_name
FROM `bans` b
JOIN  `players` p   ON p.id   = b.player_id
LEFT JOIN `players`  adm ON adm.id  = b.banned_by
LEFT JOIN `servers`  srv ON srv.id  = b.server_id
WHERE b.is_active = 1
  AND (b.expires_at IS NULL OR b.expires_at > NOW())
//

CREATE OR REPLACE VIEW `v_leaderboard_kills` AS
SELECT
    p.id,
    p.name,
    SUM(ps.kills)   AS total_kills,
    SUM(ps.deaths)  AS total_deaths,
    ROUND(
      SUM(ps.kills) / NULLIF(SUM(ps.deaths), 0), 2
    )               AS kd_ratio,
    SUM(ps.playtime)AS total_playtime_seconds
FROM `player_stats` ps
JOIN `players` p ON p.id = ps.player_id
GROUP BY p.id, p.name
ORDER BY total_kills DESC
//

CREATE OR REPLACE VIEW `v_player_warns` AS
SELECT
    p.id         AS player_id,
    p.name,
    srv.name     AS server_name,
    COUNT(w.id)  AS warn_count,
    MAX(w.issued_at) AS last_warn
FROM `warns` w
JOIN `players` p   ON p.id   = w.player_id
JOIN `servers`  srv ON srv.id = w.server_id
WHERE w.is_active = 1
GROUP BY p.id, p.name, srv.id, srv.name
//

CREATE PROCEDURE `sp_player_join`(
    IN  p_steamid64   BIGINT UNSIGNED,
    IN  p_steamid     VARCHAR(24),
    IN  p_name        VARCHAR(64),
    IN  p_server_id   TINYINT UNSIGNED,
    IN  p_ip          VARCHAR(45),
    OUT p_session_id  BIGINT UNSIGNED
)
BEGIN
    DECLARE v_player_id BIGINT UNSIGNED;
    DECLARE v_is_banned TINYINT(1);

    INSERT INTO `players` (`steamid64`, `steamid`, `name`)
    VALUES (p_steamid64, p_steamid, p_name)
    ON DUPLICATE KEY UPDATE
        `name`      = p_name,
        `last_seen` = CURRENT_TIMESTAMP;

    SET v_player_id = (SELECT `id` FROM `players` WHERE `steamid64` = p_steamid64);

    -- Vérification ban actif
    SELECT COUNT(*) INTO v_is_banned
    FROM `bans`
    WHERE player_id = v_player_id
      AND is_active  = 1
      AND (server_id IS NULL OR server_id = p_server_id)
      AND (expires_at IS NULL OR expires_at > NOW());

    IF v_is_banned > 0 THEN
        SET p_session_id = -1;
    ELSE
        INSERT INTO `sessions` (`player_id`, `server_id`, `ip_address`)
        VALUES (v_player_id, p_server_id, p_ip);

        SET p_session_id = LAST_INSERT_ID();

        INSERT IGNORE INTO `player_groups` (`player_id`, `server_id`, `group_id`)
        SELECT v_player_id, p_server_id, id
        FROM `groups`
        WHERE is_default = 1
        LIMIT 1;
    END IF;
END //

CREATE PROCEDURE `sp_player_leave`(
    IN p_session_id BIGINT UNSIGNED
)
BEGIN
    DECLARE v_player_id  BIGINT UNSIGNED;
    DECLARE v_server_id  TINYINT UNSIGNED;
    DECLARE v_duration   INT UNSIGNED;

    SELECT player_id, server_id,
           TIMESTAMPDIFF(SECOND, joined_at, NOW())
    INTO   v_player_id, v_server_id, v_duration
    FROM   `sessions`
    WHERE  id = p_session_id AND left_at IS NULL;

    IF v_player_id IS NOT NULL THEN
        UPDATE `sessions` SET left_at = NOW() WHERE id = p_session_id;

        UPDATE `players`
        SET total_playtime = total_playtime + v_duration
        WHERE id = v_player_id;

        INSERT INTO `player_stats` (`player_id`, `server_id`, `playtime`)
        VALUES (v_player_id, v_server_id, v_duration)
        ON DUPLICATE KEY UPDATE playtime = playtime + v_duration;
    END IF;
END //

CREATE PROCEDURE `sp_ban_player`(
    IN p_steamid64  BIGINT UNSIGNED,
    IN p_server_id  TINYINT UNSIGNED,
    IN p_admin_id   BIGINT UNSIGNED,
    IN p_reason     VARCHAR(512),
    IN p_duration   INT UNSIGNED 
)
BEGIN
    DECLARE v_player_id BIGINT UNSIGNED;

    SELECT id INTO v_player_id FROM `players` WHERE steamid64 = p_steamid64;

    IF v_player_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Joueur introuvable.';
    END IF;

    UPDATE `bans`
    SET is_active = 0
    WHERE player_id = v_player_id
      AND (p_server_id IS NULL OR server_id = p_server_id OR server_id IS NULL)
      AND is_active = 1;

    INSERT INTO `bans` (`player_id`, `server_id`, `banned_by`, `reason`, `duration`)
    VALUES (v_player_id, p_server_id, p_admin_id, p_reason, p_duration);

    UPDATE `players` SET is_banned = 1 WHERE id = v_player_id;

    INSERT INTO `admin_logs` (`server_id`, `admin_id`, `target_id`, `action`, `detail`)
    VALUES (IFNULL(p_server_id, 1), p_admin_id, v_player_id, 'ban', p_reason);
END //


CREATE PROCEDURE `sp_unban_player`(
    IN p_steamid64  BIGINT UNSIGNED,
    IN p_admin_id   BIGINT UNSIGNED
)
BEGIN
    DECLARE v_player_id BIGINT UNSIGNED;

    SELECT id INTO v_player_id FROM `players` WHERE steamid64 = p_steamid64;

    IF v_player_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Joueur introuvable.';
    END IF;

    UPDATE `bans`
    SET is_active   = 0,
        unbanned_at = NOW(),
        unbanned_by = p_admin_id
    WHERE player_id = v_player_id AND is_active = 1;

    UPDATE `players` SET is_banned = 0 WHERE id = v_player_id;

    INSERT INTO `admin_logs` (`server_id`, `admin_id`, `target_id`, `action`, `detail`)
    VALUES (1, p_admin_id, v_player_id, 'unban', 'Unban manuel');
END //

CREATE PROCEDURE `sp_update_combat_stats`(
    IN p_player_id  BIGINT UNSIGNED,
    IN p_server_id  TINYINT UNSIGNED,
    IN p_kills      INT,
    IN p_deaths     INT,
    IN p_score      INT
)
BEGIN
    INSERT INTO `player_stats`
        (`player_id`, `server_id`, `kills`, `deaths`, `score`)
    VALUES
        (p_player_id, p_server_id,
         GREATEST(0, p_kills),
         GREATEST(0, p_deaths),
         p_score)
    ON DUPLICATE KEY UPDATE
        kills  = kills  + GREATEST(0, p_kills),
        deaths = deaths + GREATEST(0, p_deaths),
        score  = score  + p_score;
END //

CREATE TRIGGER `trg_ban_protect_superadmin`
BEFORE INSERT ON `bans`
FOR EACH ROW
BEGIN
    DECLARE v_group_priority TINYINT UNSIGNED;

    SELECT g.priority INTO v_group_priority
    FROM `player_groups` pg
    JOIN `groups` g ON g.id = pg.group_id
    WHERE pg.player_id = NEW.player_id
    ORDER BY g.priority DESC
    LIMIT 1;

    IF v_group_priority >= 100 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Impossible de bannir un Super Admin.';
    END IF;
END //

CREATE TRIGGER `trg_log_warn`
AFTER INSERT ON `warns`
FOR EACH ROW
BEGIN
    INSERT INTO `admin_logs`
        (`server_id`, `admin_id`, `target_id`, `action`, `detail`)
    VALUES
        (NEW.server_id, NEW.issued_by, NEW.player_id, 'warn', NEW.reason);
END //

CREATE TRIGGER `trg_expire_bans_on_check`
BEFORE INSERT ON `sessions`
FOR EACH ROW
BEGIN
    UPDATE `bans`
    SET is_active = 0
    WHERE player_id = NEW.player_id
      AND is_active  = 1
      AND expires_at IS NOT NULL
      AND expires_at <= NOW();
END //

DELIMITER ;

CREATE USER IF NOT EXISTS 'gmod_app'@'127.0.0.1'
  IDENTIFIED BY 'ChangeMeStrong!App2024';

GRANT SELECT, INSERT, UPDATE, DELETE
    ON `gmod_db`.*
    TO 'gmod_app'@'127.0.0.1';

GRANT EXECUTE
    ON `gmod_db`.*
    TO 'gmod_app'@'127.0.0.1';

CREATE USER IF NOT EXISTS 'gmod_readonly'@'%'
  IDENTIFIED BY 'ChangeMeStrong!Read2024';

GRANT SELECT
    ON `gmod_db`.*
    TO 'gmod_readonly'@'%';

CREATE USER IF NOT EXISTS 'gmod_admin'@'localhost'
  IDENTIFIED BY 'ChangeMeStrong!Admin2024';

GRANT ALL PRIVILEGES
    ON `gmod_db`.*
    TO 'gmod_admin'@'localhost';

FLUSH PRIVILEGES;

ANALYZE TABLE `players`, `sessions`, `bans`, `player_stats`, `admin_logs`;