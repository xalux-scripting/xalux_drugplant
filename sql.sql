CREATE TABLE `player_plants` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `player_identifier` VARCHAR(50) NOT NULL,
    `plant_id` INT UNIQUE NOT NULL,
    `plant_name` VARCHAR(50) NOT NULL,
    `interior_id` VARCHAR(50) NOT NULL
);
