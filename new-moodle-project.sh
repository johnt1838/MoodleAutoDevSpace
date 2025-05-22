#!/bin/bash

echo "Enter project name (no spaces):"
read PROJECT
SAFE_PROJECT=$(echo "$PROJECT" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

# Find 3 consecutive free ports using ss
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
MAILHOG_PORT=$((BASE_PORT + 2))

# Copy template
cp -rv TEMPLATES/MOODLE-DEV-TEMPLATE "$SAFE_PROJECT"
cd "$SAFE_PROJECT" || exit

# Create .env file
cat > .env <<EOF
PROJECT_NAME=${SAFE_PROJECT}
MOODLE_PORT=${MOODLE_PORT}
PHPMYADMIN_PORT=${PHPMYADMIN_PORT}
DB_NAME=moodle
DB_USER=moodle
DB_PASSWORD=moodle
DB_ROOT_PASSWORD=root
EOF

# Run docker-compose
docker-compose -p "$SAFE_PROJECT" up -d --build

# Output
echo "✅ Project '$PROJECT' created at $SAFE_PROJECT"
echo "🌐 Moodle: http://localhost:$MOODLE_PORT"
echo "🛠️  phpMyAdmin: http://localhost:$PHPMYADMIN_PORT"
