-- Run as MariaDB root (OrbStack sdp-mariadb shell) if ./scripts/dev-mariadb-prod-sim.sh cannot authenticate:
--   mariadb -uroot -p < scripts/sql/prod-sim-manual-root.sql

CREATE DATABASE IF NOT EXISTS db093 CHARACTER SET utf8 COLLATE utf8_general_ci;
CREATE DATABASE IF NOT EXISTS db001 CHARACTER SET utf8 COLLATE utf8_general_ci;
CREATE DATABASE IF NOT EXISTS sdp_pusat CHARACTER SET utf8 COLLATE utf8_general_ci;

GRANT ALL PRIVILEGES ON db093.* TO 'sdp'@'%';
GRANT ALL PRIVILEGES ON db001.* TO 'sdp'@'%';
GRANT ALL PRIVILEGES ON sdp_pusat.* TO 'sdp'@'%';
FLUSH PRIVILEGES;
