#!/bin/bash

set -e

# Prompt for project name
read -rp "Enter project name (no spaces): " PROJECT
SAFE_PROJECT=$(echo "$PROJECT" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

# Find 3 consecutive free ports
get_free_port_range() {
  while true; do
    BASE_PORT=$(shuf -i 8000-8997 -n 1)
    if ! lsof -i :"$BASE_PORT" >/dev/null 2>&1 &&
       ! lsof -i :"$((BASE_PORT + 1))" >/dev/null 2>&1 &&
       ! lsof -i :"$((BASE_PORT + 2))" >/dev/null 2>&1; then
      echo "$BASE_PORT"
      return
    fi
  done
}

BASE_PORT=$(get_free_port_range)
MOODLE_PORT=$BASE_PORT
PHPMYADMIN_PORT=$((BASE_PORT + 1))
# Copy template folder
cp -rv TEMPLATES/MOODLE-DEV-TEMPLATE "$SAFE_PROJECT"
cd "$SAFE_PROJECT" || exit 1

# Clone Moodle into ./moodle
git clone https://github.com/moodle/moodle.git -b MOODLE_405_STABLE moodle

# Create .env file
cat > .env <<EOF
PROJECT_NAME=${SAFE_PROJECT}
MOODLE_PORT=${MOODLE_PORT}
PHPMYADMIN_PORT=${PHPMYADMIN_PORT}MYSQL_ROOT_PASSWORD=root
MYSQL_DATABASE=moodle
MYSQL_USER=moodle
MYSQL_PASSWORD=moodle
EOF

# Create config.php (no BOM, no blank lines!)
CONFIG_FILE="moodle/config.php"

cat > "$CONFIG_FILE" <<EOF
<?php

unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

\$CFG->dbtype    = 'mariadb';
\$CFG->dblibrary = 'native';
\$CFG->dbhost    = 'mariadb';
\$CFG->dbname    = 'moodle';
\$CFG->dbuser    = 'moodle';
\$CFG->dbpass    = 'moodle';
\$CFG->prefix    = 'mdl_';
\$CFG->dboptions = array (
  'dbpersist' => 0,
  'dbport' => 3306,
  'dbsocket' => '',
  'dbcollation' => 'utf8mb4_general_ci',
);

\$CFG->wwwroot   = 'http://localhost:${MOODLE_PORT}';
\$CFG->dataroot  = '/var/www/moodledata';
\$CFG->admin     = 'admin';

\$CFG->directorypermissions = 0777;

\$CFG->debug = (E_ALL | E_STRICT);
\$CFG->debugdisplay = 1;

require_once(__DIR__ . '/lib/setup.php');
EOF

# Run docker-compose
docker-compose -p "$SAFE_PROJECT" up -d --build

# Output info
echo "1. Project '$PROJECT' created in folder: $SAFE_PROJECT"
echo "2. Moodle:      http://localhost:$MOODLE_PORT"
echo "3. phpMyAdmin: http://localhost:$PHPMYADMIN_PORT"