USE `gmod_db`;

START TRANSACTION;

INSERT INTO `groups`
  (`name`, `display_name`, `color_hex`, `is_default`, `priority`, `can_kick`, `can_ban`, `can_spawn`, `can_noclip`, `can_slay`)
VALUES
  ('user',       'Joueur',        '#AAAAAA', 1, 0,  0, 0, 1, 0, 0),
  ('vip',        'VIP',           '#FFD700', 0, 10, 0, 0, 1, 0, 0),
  ('moderator',  'Modérateur',    '#00AAFF', 0, 50, 1, 0, 1, 1, 1),
  ('admin',      'Administrateur','#FF6600', 0, 80, 1, 1, 1, 1, 1),
  ('superadmin', 'Super Admin',   '#FF0000', 0, 100,1, 1, 1, 1, 1)
ON DUPLICATE KEY UPDATE
  `display_name` = VALUES(`display_name`),
  `color_hex`    = VALUES(`color_hex`),
  `priority`     = VALUES(`priority`);


INSERT INTO `servers`
  (`name`, `gamemode`, `map`, `max_players`, `ip`, `port`, `is_active`)
VALUES
  ('GMod Sandbox #1',  'sandbox', 'gm_construct',    32, '127.0.0.1', 27015, 1),
  ('GMod Sandbox #2',  'sandbox', 'gm_flatgrass',    32, '127.0.0.1', 27016, 1),
  ('DarkRP Server',    'darkrp',  'rp_downtown_v4c', 64, '127.0.0.1', 27017, 1),
  ('TTT Server',       'terrortown','ttt_rooftops',  32, '127.0.0.1', 27018, 1)
ON DUPLICATE KEY UPDATE
  `name`        = VALUES(`name`),
  `gamemode`    = VALUES(`gamemode`),
  `map`         = VALUES(`map`),
  `is_active`   = VALUES(`is_active`);

-- Sandbox #1
INSERT INTO `server_settings` (`server_id`, `setting_key`, `value`) VALUES
  (1, 'sbox_maxprops',    '200'),
  (1, 'sbox_maxragdolls', '10'),
  (1, 'sbox_maxvehicles', '4'),
  (1, 'sbox_maxeffects',  '50'),
  (1, 'sbox_godmode',     '0'),
  (1, 'sbox_noclip',      '1'),
  (1, 'welcome_message',  'Bienvenue sur le serveur Sandbox #1 !'),
  -- Sandbox #2
  (2, 'sbox_maxprops',    '150'),
  (2, 'sbox_maxvehicles', '2'),
  (2, 'welcome_message',  'Bienvenue sur le serveur Sandbox #2 !'),
  -- DarkRP
  (3, 'rp_startingmoney', '500'),
  (3, 'rp_moneylimit',    '999999'),
  (3, 'rp_voiceradius',   '700'),
  (3, 'welcome_message',  'Bienvenue sur le serveur DarkRP !'),
  -- TTT
  (4, 'ttt_preptime_seconds',  '30'),
  (4, 'ttt_round_limit',       '6'),
  (4, 'ttt_time_limit_minutes','10'),
  (4, 'ttt_traitor_pct',       '0.25'),
  (4, 'welcome_message',       'Bienvenue sur le serveur TTT !')
ON DUPLICATE KEY UPDATE
  `value` = VALUES(`value`);

INSERT INTO `players`
  (`steamid64`, `steamid`, `name`, `is_banned`)
VALUES
  (0, 'STEAM_0:0:0', '[CONSOLE]', 0)
ON DUPLICATE KEY UPDATE `name` = '[CONSOLE]';

COMMIT;