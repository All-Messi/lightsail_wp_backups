#!/bin/bash

# Define directories and script names
BACKUP_BASE_DIR="/opt/bitnami/backups"
DB_BACKUP_DIR="$BACKUP_BASE_DIR/database"
WP_FILES_BACKUP_DIR="$BACKUP_BASE_DIR/wordpress_files"
SCRIPT_INSTALL_DIR="/opt/bitnami/scripts"
DAILY_DB_SCRIPT="backup_db_daily.sh"
WEEKLY_FULLSITE_SCRIPT="backup_fullsite_weekly.sh"
BITNAMI_USER="bitnami" # Common user for Bitnami instances

echo "Starting Lightsail WordPress Backup Setup..."

# 1. Create backup directories if they don't exist
echo "Creating backup directories: $DB_BACKUP_DIR and $WP_FILES_BACKUP_DIR"
sudo mkdir -p "$DB_BACKUP_DIR"
sudo mkdir -p "$WP_FILES_BACKUP_DIR"

# 2. Set ownership for backup directories (bitnami user needs write access)
echo "Setting ownership for backup directories to $BITNAMI_USER:daemon"
sudo chown -R "$BITNAMI_USER":daemon "$BACKUP_BASE_DIR"

# 3. Create script installation directory if it doesn't exist
echo "Creating script installation directory: $SCRIPT_INSTALL_DIR"
sudo mkdir -p "$SCRIPT_INSTALL_DIR"

# 4. Copy scripts to the installation directory
echo "Copying backup scripts to $SCRIPT_INSTALL_DIR"
sudo cp "./scripts/$DAILY_DB_SCRIPT" "$SCRIPT_INSTALL_DIR/$DAILY_DB_SCRIPT"
sudo cp "./scripts/$WEEKLY_FULLSITE_SCRIPT" "$SCRIPT_INSTALL_DIR/$WEEKLY_FULLSITE_SCRIPT"

# 5. Make scripts executable
echo "Making scripts executable"
sudo chmod +x "$SCRIPT_INSTALL_DIR/$DAILY_DB_SCRIPT"
sudo chmod +x "$SCRIPT_INSTALL_DIR/$WEEKLY_FULLSITE_SCRIPT"

# 6. Set ownership of scripts (bitnami user should own them to run them)
echo "Setting ownership for scripts to $BITNAMI_USER:daemon"
sudo chown "$BITNAMI_USER":daemon "$SCRIPT_INSTALL_DIR/$DAILY_DB_SCRIPT"
sudo chown "$BITNAMI_USER":daemon "$SCRIPT_INSTALL_DIR/$WEEKLY_FULLSITE_SCRIPT"

# 7. Add cron jobs for the bitnami user
echo "Adding cron jobs for user $BITNAMI_USER..."
(sudo crontab -l -u "$BITNAMI_USER" 2>/dev/null; \
 echo "# Lightsail WordPress Daily DB Backup (run daily at 2 AM)"; \
 echo "0 2 * * * $SCRIPT_INSTALL_DIR/$DAILY_DB_SCRIPT"; \
 echo "# Lightsail WordPress Weekly Full Site Backup (run weekly on Sunday at 3 AM)"; \
 echo "0 3 * * 0 $SCRIPT_INSTALL_DIR/$WEEKLY_FULLSITE_SCRIPT" \
) | sudo crontab -u "$BITNAMI_USER" -

echo "Cron jobs added/updated for user $BITNAMI_USER."
echo "You can verify them by running: sudo crontab -l -u $BITNAMI_USER"

# 8. Set up log files (ensure they are created and writable by bitnami user)
echo "Ensuring log files are created and accessible."
sudo touch /var/log/backup_db.log
sudo touch /var/log/backup_fullsite.log
sudo chown "$BITNAMI_USER":daemon /var/log/backup_db.log
sudo chown "$BITNAMI_USER":daemon /var/log/backup_fullsite.log

echo "Setup complete! Backups will now run automatically as scheduled."
echo "Please verify by checking cron jobs (sudo crontab -l -u $BITNAMI_USER)"
echo "And by manually running a script to check for errors: sudo -u $BITNAMI_USER $SCRIPT_INSTALL_DIR/$DAILY_DB_SCRIPT"
