#!/bin/bash

# --- Configuration ---
# IMPORTANT: These paths assume a standard Bitnami WordPress installation on Lightsail.
# Adjust if your setup is different.
WP_DIR="/opt/bitnami/wordpress"
WP_CONFIG_PATH="/opt/bitnami/wordpress/wp-config.php"
BACKUP_DIR="/opt/bitnami/backups/wordpress_files"
LOG_FILE="/var/log/backup_fullsite.log" # Ensure this file is writable by the user running the script
RETENTION_DAYS=90 # Keep 90 days of weekly backups locally

# Extract database credentials from wp-config.php
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
if [ ! -d "$WP_DIR" ]; then
  log_message "ERROR: WordPress directory $WP_DIR does not exist. Please check your installation path."
  exit 1
fi
if [ ! -d "$BACKUP_DIR" ]; then
  log_message "ERROR: Backup directory $BACKUP_DIR does not exist. Please run the setup script."
  exit 1
fi


# --- Perform Full Site Backup ---
log_message "Starting weekly full site backup..."

# First, dump the database for the full site backup package
DB_BACKUP_FILE="$BACKUP_DIR/$DB_NAME-$DATE.sql" # Temporarily store DB dump
log_message "Dumping database for full site backup: $DB_BACKUP_FILE"
mysqldump -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" > "$DB_BACKUP_FILE"

if [ $? -ne 0 ]; then
  log_message "ERROR: Database dump for full site backup failed. Exiting."
  exit 1
fi

# Create archive of WordPress files and the database dump
ARCHIVE_FILE="$BACKUP_DIR/wordpress-fullsite-$DATE.tar.gz"
log_message "Archiving WordPress files and database dump to $ARCHIVE_FILE..."
# Ensure you are archiving the parent directory of wordpress to get the 'wordpress' folder itself
# The --exclude is important if you store the temp DB dump in the same parent as WP backups.
# Make sure to exclude any other existing backups to prevent recursive archiving.
tar -czpf "$ARCHIVE_FILE" -C "$(dirname "$WP_DIR")" "$(basename "$WP_DIR")" --exclude='*/backups/*' --exclude='*.sql'

if [ $? -eq 0 ]; then
  log_message "Full site archive created successfully."
else
  log_message "ERROR: Full site archiving failed. Exiting."
  exit 1
fi

# Remove the temporary database dump after archiving
log_message "Removing temporary database dump: $DB_BACKUP_FILE"
rm "$DB_BACKUP_FILE"

# --- Clean Old Local Backups ---
log_message "Cleaning old local full site backups (retaining $RETENTION_DAYS days)..."
find "$BACKUP_DIR" -type f -name "wordpress-fullsite-*.tar.gz" -mtime +$RETENTION_DAYS -delete

if [ $? -eq 0 ]; then
  log_message "Old local full site backups cleaned."
else
  log_message "ERROR: Failed to clean old local full site backups."
fi

log_message "Weekly full site backup script finished."
