CREATE TABLE IF NOT EXISTS player_plants (
    id INT AUTO_INCREMENT PRIMARY KEY,
    owner_identifier VARCHAR(50) NOT NULL,
    plant_type VARCHAR(50) NOT NULL,
    plant_location JSON NOT NULL,
    permissions JSON DEFAULT NULL
);
