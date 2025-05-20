#!/bin/bash

# --- Configuration ---
# Set strict mode: Exit immediately if a command exits with a non-zero status.
set -e

# Define directories and script names
BACKUP_BASE_DIR="/opt/bitnami/backups"
DB_BACKUP_DIR="$BACKUP_BASE_DIR/database"
WP_FILES_BACKUP_DIR="$BACKUP_BASE_DIR/wordpress_files"
SCRIPT_INSTALL_DIR="/opt/bitnami/scripts"
DAILY_DB_SCRIPT="backup_db_daily.sh"
WEEKLY_FULLSITE_SCRIPT="backup_fullsite_weekly.sh"
BITNAMI_USER="bitnami" # Common user for Bitnami instances

# Log file for the deployment script itself (optional, but good for debugging)
DEPLOY_LOG="/var/log/lightsail_wp_deploy.log"

# Function to log messages to stdout and the deployment log
log_message() {
    echo "$(date +%Y-%m-%d_%H-%M-%S) - $1" | sudo tee -a "$DEPLOY_LOG"
}

log_message "Starting Lightsail WordPress Backup Deployment..."

# --- Pre-flight Checks ---
if ! command -v git &> /dev/null; then
    log_message "ERROR: Git is not installed. Please install Git: sudo apt-get install git -y"
    exit 1
fi
if ! id -u "$BITNAMI_USER" &> /dev/null; then
    log_message "ERROR: User '$BITNAMI_USER' does not exist. This script is designed for Bitnami instances."
    exit 1
fi

# Ensure log file exists and is writable by root (for sudo tee)
sudo touch "$DEPLOY_LOG"
sudo chmod 644 "$DEPLOY_LOG" # Readable by others, writable by root

# --- 1. Create backup directories if they don't exist ---
log_message "Creating backup directories: $DB_BACKUP_DIR and $WP_FILES_BACKUP_DIR"
sudo mkdir -p "$DB_BACKUP_DIR" || { log_message "ERROR: Failed to create $DB_BACKUP_DIR"; exit 1; }
sudo mkdir -p "$WP_FILES_BACKUP_DIR" || { log_message "ERROR: Failed to create $WP_FILES_BACKUP_DIR"; exit 1; }

# --- 2. Set ownership for backup directories (bitnami user needs write access) ---
log_message "Setting ownership for backup directories to $BITNAMI_USER:daemon"
sudo chown -R "$BITNAMI_USER":daemon "$BACKUP_BASE_DIR" || { log_message "ERROR: Failed to set ownership for $BACKUP_BASE_DIR"; exit 1; }

# --- 3. Create script installation directory if it doesn't exist ---
log_message "Creating script installation directory: $SCRIPT_INSTALL_DIR"
sudo mkdir -p "$SCRIPT_INSTALL_DIR" || { log_message "ERROR: Failed to create $SCRIPT_INSTALL_DIR"; exit 1; }

# --- 4. Copy scripts to the installation directory ---
log_message "Copying backup scripts to $SCRIPT_INSTALL_DIR"
sudo cp "./scripts/$DAILY_DB_SCRIPT" "$SCRIPT_INSTALL_DIR/$DAILY_DB_SCRIPT" || { log_message "ERROR: Failed to copy $DAILY_DB_SCRIPT"; exit 1; }
sudo cp "./scripts/$WEEKLY_FULLSITE_SCRIPT" "$SCRIPT_INSTALL_DIR/$WEEKLY_FULLSITE_SCRIPT" || { log_message "ERROR: Failed to copy $WEEKLY_FULLSITE_SCRIPT"; exit 1; }

# --- 5. Make scripts executable ---
log_message "Making scripts executable"
sudo chmod +x "$SCRIPT_INSTALL_DIR/$DAILY_DB_SCRIPT" || { log_message "ERROR: Failed to set executable on $DAILY_DB_SCRIPT"; exit 1; }
sudo chmod +x "$SCRIPT_INSTALL_DIR/$WEEKLY_FULLSITE_SCRIPT" || { log_message "ERROR: Failed to set executable on $WEEKLY_FULLSITE_SCRIPT"; exit 1; }

# --- 6. Set ownership of scripts (bitnami user should own them to run them) ---
log_message "Setting ownership for scripts to $BITNAMI_USER:daemon"
sudo chown "$BITNAMI_USER":daemon "$SCRIPT_INSTALL_DIR/$DAILY_DB_SCRIPT" || { log_message "ERROR: Failed to set ownership on $DAILY_DB_SCRIPT"; exit 1; }
sudo chown "$BITNAMI_USER":daemon "$SCRIPT_INSTALL_DIR/$WEEKLY_FULLSITE_SCRIPT" || { log_message "ERROR: Failed to set ownership on $WEEKLY_FULLSITE_SCRIPT"; exit 1; }

# --- 7. Add cron jobs for the bitnami user ---
log_message "Adding cron jobs for user $BITNAMI_USER..."

# Remove existing entries to prevent duplicates (idempotence)
(sudo crontab -l -u "$BITNAMI_USER" 2>/dev/null | grep -v "$SCRIPT_INSTALL_DIR/$DAILY_DB_SCRIPT" | grep -v "$SCRIPT_INSTALL_DIR/$WEEKLY_FULLSITE_SCRIPT"; \
 echo "# Lightsail WordPress Daily DB Backup (run daily at 2 AM - Managed by deploy.sh)"; \
 echo "0 2 * * * $SCRIPT_INSTALL_DIR/$DAILY_DB_SCRIPT"; \
 echo "# Lightsail WordPress Weekly Full Site Backup (run weekly on Sunday at 3 AM - Managed by deploy.sh)"; \
 echo "0 3 * * 0 $SCRIPT_INSTALL_DIR/$WEEKLY_FULLSITE_SCRIPT" \
) | sudo crontab -u "$BITNAMI_USER" - || { log_message "ERROR: Failed to update crontab."; exit 1; }

log_message "Cron jobs added/updated for user $BITNAMI_USER."
log_message "You can verify them by running: sudo crontab -l -u $BITNAMI_USER"

# --- 8. Set up log files for backup scripts (ensure they are created and writable by bitnami user) ---
log_message "Ensuring backup log files are created and accessible."
sudo touch /var/log/backup_db.log || { log_message "ERROR: Failed to create /var/log/backup_db.log"; exit 1; }
sudo touch /var/log/backup_fullsite.log || { log_message "ERROR: Failed to create /var/log/backup_fullsite.log"; exit 1; }
sudo chown "$BITNAMI_USER":daemon /var/log/backup_db.log || { log_message "ERROR: Failed to set ownership for /var/log/backup_db.log"; exit 1; }
sudo chown "$BITNAMI_USER":daemon /var/log/backup_fullsite.log || { log_message "ERROR: Failed to set ownership for /var/log/backup_fullsite.log"; exit 1; }

log_message "Deployment complete! Backups will now run automatically as scheduled."
log_message "Please verify by checking cron jobs (sudo crontab -l -u $BITNAMI_USER)"
log_message "And by manually running a script to check for errors: sudo -u $BITNAMI_USER $SCRIPT_INSTALL_DIR/$DAILY_DB_SCRIPT"
log_message "Deployment log: $DEPLOY_LOG"
