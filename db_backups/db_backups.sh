#!/bin/bash
set -e

# Load .env file
[ -f ./config/.env ] && source ./config/.env || { echo ".env file missing in ./config/"; exit 1; }

# Make sure LOG_DIR and BACKUP_DIR exist
mkdir -p "$BACKUP_DIR"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/backup.json"
DATE_NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Initialize arrays for success/failure
success_list=()
failure_list=()

# Create log file if not exist
[ ! -f "$LOG_FILE" ] && echo "[]" > "$LOG_FILE"

for DB in "${DATABASES[@]}"; do
  BACKUP_FILE="${BACKUP_DIR}/${DB}_dump_$(date +%F).sql.gz"
  echo "Backing up database: $DB"
  
  if mysqldump -u "$MYSQL_USER" -p"$MYSQL_PASS" -h "$MYSQL_HOST" "$DB" | gzip > "$BACKUP_FILE"; then
    echo "Backup successful: $BACKUP_FILE"
    success_list+=("$DB")
    LOG_ENTRY="{\"createdAt\": \"$DATE_NOW\", \"status\": \"success\", \"database\": \"$DB\", \"backupFile\": \"$BACKUP_FILE\"}"
  else
    echo "Backup FAILED for database: $DB" | tee -a "$LOG_DIR/backup_errors.log"
    failure_list+=("$DB")
    LOG_ENTRY="{\"createdAt\": \"$DATE_NOW\", \"status\": \"failed\", \"database\": \"$DB\"}"
  fi

  # Append to log
  TMP_FILE=$(mktemp)
  jq ". += [$LOG_ENTRY]" "$LOG_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$LOG_FILE"

  # Cleanup old backups older than 7 days
  find "$BACKUP_DIR" -type f -name "${DB}_dump_*.sql.gz" -mtime +7 -exec rm {} \;
done

# Prepare summary text
SUMMARY_BODY="Database Backup Summary - $(date +'%Y-%m-%d %H:%M:%S')\n\n"

if [ ${#success_list[@]} -gt 0 ]; then
  SUMMARY_BODY+="✅ Successful backups (${#success_list[@]}):\n"
  for db in "${success_list[@]}"; do
    SUMMARY_BODY+=" • $db\n"
  done
  SUMMARY_BODY+="\n"
fi

if [ ${#failure_list[@]} -gt 0 ]; then
  SUMMARY_BODY+="❌ Failed backups (${#failure_list[@]}):\n"
  for db in "${failure_list[@]}"; do
    SUMMARY_BODY+=" • $db\n"
  done
else
  SUMMARY_BODY+="All backups completed successfully.\n"
fi

export STATUS="summary"
export DB_NAME="All Databases"
export SUMMARY_TEXT="$SUMMARY_BODY"

# Call mailer script
/bin/bash ./mailer.sh
