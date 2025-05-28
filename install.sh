#!/bin/bash
set -e

CONFIG_DIR="./config"
mkdir -p "$CONFIG_DIR"

ENV_FILE="$CONFIG_DIR/.env"

echo "Welcome to Safe Dump"

echo "Please enter your MySQL username:"
read MYSQL_USER

echo "Please enter your MySQL password:"
read -s MYSQL_PASS

echo "Please enter your MySQL host (default: localhost):"
read MYSQL_HOST
MYSQL_HOST=${MYSQL_HOST:-localhost}

echo "Enter backup directory (default: /root/db_backups):"
read BACKUP_DIR
BACKUP_DIR=${BACKUP_DIR:-/root/db_backups}

echo "Enter log directory (default: /root/logs):"
read LOG_DIR
LOG_DIR=${LOG_DIR:-/root/logs}

echo "Enter databases to backup (space-separated, e.g. db1 db2 db3):"
read -a DATABASES

echo "Enter Gmail Client ID:"
read CLIENT_ID

echo "Enter Gmail Client Secret:"
read CLIENT_SECRET

echo "Enter Gmail Refresh Token:"
read REFRESH_TOKEN

echo "Enter 'From' email (e.g. Database Backup <your-email@gmail.com>):"
read FROM_EMAIL

echo "Enter comma-separated 'To' emails (e.g. email1@gmail.com,email2@gmail.com):"
read TO_EMAIL

# Write to .env file
{
  echo "MYSQL_USER=$MYSQL_USER"
  echo "MYSQL_PASS=$MYSQL_PASS"
  echo "MYSQL_HOST=$MYSQL_HOST"
  echo "BACKUP_DIR=$BACKUP_DIR"
  echo "LOG_DIR=$LOG_DIR"
  
  # Format DATABASES array in .env (bash array syntax)
  echo -n "DATABASES=("
  for db in "${DATABASES[@]}"; do
    echo -n "\"$db\" "
  done
  echo ")"
  
  echo "CLIENT_ID=$CLIENT_ID"
  echo "CLIENT_SECRET=$CLIENT_SECRET"
  echo "REFRESH_TOKEN=$REFRESH_TOKEN"
  echo "FROM_EMAIL=\"$FROM_EMAIL\""
  echo "TO_EMAIL=\"$TO_EMAIL\""
} > "$ENV_FILE"

echo ".env configuration file created at $ENV_FILE"

# Create necessary directories
mkdir -p "$BACKUP_DIR" "$LOG_DIR" "./scripts"

# Copy backup and mailer scripts to ./scripts
cp ./db_backups.sh ./scripts/db_backups.sh
cp ./mailer.sh ./scripts/mailer.sh

# Make scripts executable
chmod +x ./scripts/db_backups.sh ./scripts/mailer.sh

echo "Setup completed! You can run your backup script via:"
echo "bash ./scripts/db_backups.sh"
