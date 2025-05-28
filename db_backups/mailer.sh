#!/bin/bash
set -e

# Load .env config
[ -f ./config/.env ] && source ./config/.env || { echo ".env file missing in ./config/"; exit 1; }

if [ "$STATUS" = "summary" ]; then
  SUBJECT="Database Backup Summary Report - $(date +'%Y-%m-%d')"
  
  HTML_BODY=$(cat <<EOF
<html>
  <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
    <h2 style="color: #2E86C1;">Database Backup Summary</h2>
    <p>Report generated on: $(date +'%Y-%m-%d %H:%M:%S')</p>
    <hr>
    <pre style="background: #f7f7f7; padding: 15px; border-radius: 5px; font-family: monospace; font-size: 14px;">
$(echo "$SUMMARY_TEXT" | sed 's/✅/<span style="color:green;">&#10004;<\/span>/; s/❌/<span style="color:red;">&#10008;<\/span>/; s/•/&bull;/g' | sed 's/^  /&nbsp;&nbsp;/g')
    </pre>
    <hr>
    <p style="font-size: 12px; color: #777;">This is an automated message. Please do not reply.</p>
  </body>
</html>
EOF
  )

  RAW_EMAIL=$(printf "To: %s\r\nFrom: %s\r\nSubject: %s\r\nMIME-Version: 1.0\r\nContent-Type: text/html; charset=UTF-8\r\n\r\n%s" \
    "$TO_EMAIL" "$FROM_EMAIL" "$SUBJECT" "$HTML_BODY")

else
  SUBJECT="Backup $STATUS: $DB_NAME"
  if [ "$STATUS" = "success" ]; then
    BODY_TEXT="Backup for database '$DB_NAME' was successful.\nBackup file: $BACKUP_PATH"
  else
    BODY_TEXT="Backup for database '$DB_NAME' FAILED."
  fi
  
  RAW_EMAIL=$(printf "To: %s\r\nFrom: %s\r\nSubject: %s\r\nMIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\n%s" \
    "$TO_EMAIL" "$FROM_EMAIL" "$SUBJECT" "$BODY_TEXT")
fi

ACCESS_TOKEN=$(curl -s -X POST "https://oauth2.googleapis.com/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "refresh_token=${REFRESH_TOKEN}" \
  -d "grant_type=refresh_token" | jq -r .access_token)

ENCODED_RAW_EMAIL=$(echo -n "$RAW_EMAIL" | base64 | tr '+/' '-_' | tr -d '=' | tr -d '\n')

RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"raw\": \"${ENCODED_RAW_EMAIL}\"}" \
  "https://gmail.googleapis.com/gmail/v1/users/me/messages/send")

if [[ $RESPONSE == *"id"* ]]; then
  echo "Email sent successfully!"
  STATUS_LOG="success"
else
  echo "Failed to send email. Response: $RESPONSE"
  STATUS_LOG="failed"
fi

TIMESTAMP=$(date -Iseconds)
jq --arg timestamp "$TIMESTAMP" --arg status "$STATUS_LOG" --arg response "$RESPONSE" \
  '. += [{"createdAt": $timestamp, "status": $status, "response": $response}]' \
  "$LOG_DIR/email.json" > "$LOG_DIR/email.tmp" && mv "$LOG_DIR/email.tmp" "$LOG_DIR/email.json"
