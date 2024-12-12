CREATE TABLE IF NOT EXISTS `plant_permissions` (
  `plant_id` varchar(50) NOT NULL,
  `player_identifier` varchar(255) NOT NULL,
  `steam_name` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`plant_id`,`player_identifier`),
  CONSTRAINT `plant_permissions_ibfk_1` FOREIGN KEY (`plant_id`) REFERENCES `player_plants` (`plant_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;


CREATE TABLE IF NOT EXISTS `player_plants` (
  `plant_id` varchar(50) NOT NULL,
  `player_identifier` varchar(50) NOT NULL DEFAULT '0',
  `interior_id` varchar(50) NOT NULL DEFAULT '',
  `buying_price` int(11) NOT NULL,
  `plant_name` varchar(50) NOT NULL,
  PRIMARY KEY (`plant_id`),
  KEY `idx_player_identifier` (`player_identifier`),
  KEY `idx_interior_id` (`interior_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
