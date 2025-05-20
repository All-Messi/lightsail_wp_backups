#!/bin/bash

# --- Configuration ---
# IMPORTANT: These paths assume a standard Bitnami WordPress installation on Lightsail.
# Adjust if your setup is different.
WP_CONFIG_PATH="/opt/bitnami/wordpress/wp-config.php"
BACKUP_DIR="/opt/bitnami/backups/database"
LOG_FILE="/var/log/backup_db.log" # Ensure this file is writable by the user running the script
RETENTION_DAYS=90 # Keep 90 days of daily backups

# Extract database credentials from wp-config.php
# Using sed for robust extraction
DB_NAME=$(grep "DB_NAME" "$WP_CONFIG_PATH" | sed -n "s/define('DB_NAME', '\([^']*\)');/\1/p")
DB_USER=$(grep "DB_USER" "$WP_CONFIG_PATH" | sed -n "s/define('DB_USER', '\([^']*\)');/\1/p")
DB_PASSWORD=$(grep "DB_PASSWORD" "$WP_CONFIG_PATH" | sed -n "s/define('DB_PASSWORD', '\([^']*\)');/\1/p")

DATE=$(date +%Y-%m-%d_%H-%M-%S)

# --- Logging Function ---
log_message() {
  echo "$(date +%Y-%m-%d_%H-%M-%S) - $1" | sudo tee -a "$LOG_FILE" > /dev/null
}

# --- Pre-checks ---
if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
  log_message "ERROR: Could not extract database credentials from $WP_CONFIG_PATH. Please check the path and file content."
  exit 1
fi
if [ ! -d "$BACKUP_DIR" ]; then
  log_message "ERROR: Backup directory $BACKUP_DIR does not exist. Please run the setup script."
  exit 1
fi

# --- Perform Database Backup ---
log_message "Starting daily database backup for $DB_NAME..."
mysqldump -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" | gzip > "$BACKUP_DIR/$DB_NAME-$DATE.sql.gz"

if [ $? -eq 0 ]; then
  log_message "Database backup completed successfully: $BACKUP_DIR/$DB_NAME-$DATE.sql.gz"
else
  log_message "ERROR: Database backup failed."
fi

# --- Clean Old Backups ---
log_message "Cleaning old database backups (retaining $RETENTION_DAYS days)..."
find "$BACKUP_DIR" -type f -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete

if [ $? -eq 0 ]; then
  log_message "Old database backups cleaned."
else
  log_message "ERROR: Failed to clean old database backups."
fi

log_message "Daily database backup script finished."
