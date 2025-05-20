# wp_backup
Backup WP (Lightsail Bitnami)

# Lightsail WordPress Automated Backups

This repository contains scripts to automate daily database backups and weekly full WordPress site backups for your Lightsail instance, with local retention for 90 days.

## Features

* **Daily Database Backups**: Dumps your WordPress database, compresses it, and stores it locally.
* **Weekly Full Site Backups**: Archives your entire WordPress installation (files + database dump), compresses it, and stores it locally.
* **90-Day Retention**: Automatically prunes old backups to save disk space.
* **Automated Scheduling**: Uses cron jobs to run backups automatically.

## Prerequisites

* A Lightsail instance running WordPress (Bitnami stack assumed).
* SSH access to your Lightsail instance.
* `mysqldump` and `tar` utilities (usually pre-installed).

## Deployment Steps

Follow these steps to deploy the backup solution to your Lightsail instance:

1.  **SSH into your Lightsail instance.**
    ```bash
    ssh -i /path/to/your/key.pem bitnami@YOUR_LIGHTSAIL_IP
    ```

2.  **Clone this repository to your Lightsail instance.**
    It's recommended to clone it to a temporary location, e.g., in the `bitnami` user's home directory.

    ```bash
    cd ~
    git clone [https://github.com/YOUR_USERNAME/lightsail-wp-backups.git](https://github.com/YOUR_USERNAME/lightsail-wp-backups.git)
    cd lightsail-wp-backups
    ```
    **Remember to replace `YOUR_USERNAME` with your actual GitHub username.**

3.  **Run the setup script.**
    This script will:
    * Create necessary backup directories (`/opt/bitnami/backups/database`, `/opt/bitnami/backups/wordpress_files`).
    * Copy the backup scripts to `/opt/bitnami/scripts`.
    * Make the scripts executable.
    * Set appropriate file permissions.
    * Add cron jobs for the `bitnami` user to schedule the backups.
    * Create and set permissions for log files (`/var/log/backup_db.log`, `/var/log/backup_fullsite.log`).

    ```bash
    sudo ./setup.sh
    ```
    You might be prompted for your `sudo` password.

4.  **Verify the cron jobs.**
    After the `setup.sh` script completes, you can check that the cron jobs have been added correctly for the `bitnami` user:

    ```bash
    sudo crontab -l -u bitnami
    ```
    You should see entries similar to:
    ```
    # Lightsail WordPress Daily DB Backup (run daily at 2 AM)
    0 2 * * * /opt/bitnami/scripts/backup_db_daily.sh
    # Lightsail WordPress Weekly Full Site Backup (run weekly on Sunday at 3 AM)
    0 3 * * 0 /opt/bitnami/scripts/backup_fullsite_weekly.sh
    ```

5.  **Test the scripts manually (optional but recommended).**
    To ensure everything is working, you can manually run the scripts as the `bitnami` user:

    ```bash
    sudo -u bitnami /opt/bitnami/scripts/backup_db_daily.sh
    sudo -u bitnami /opt/bitnami/scripts/backup_fullsite_weekly.sh
    ```
    Check the backup directories (`/opt/bitnami/backups/database` and `/opt/bitnami/backups/wordpress_files`) for newly created backup files.
    Also, check the log files:
    ```bash
    sudo tail -f /var/log/backup_db.log
    sudo tail -f /var/log/backup_fullsite.log
    ```

## Backup Locations and Retention

* **Daily Database Backups**: Stored in `/opt/bitnami/backups/database` for 90 days.
* **Weekly Full Site Backups**: Stored in `/opt/bitnami/backups/wordpress_files` for 90 days.

## Reverting Changes / Uninstalling

If you need to remove the backup solution:

1.  **Remove cron jobs:**
    ```bash
    sudo crontab -e -u bitnami
    # Delete the lines related to the backup scripts
    ```
2.  **Delete script files:**
    ```bash
    sudo rm /opt/bitnami/scripts/backup_db_daily.sh
    sudo rm /opt/bitnami/scripts/backup_fullsite_weekly.sh
    ```
3.  **Delete backup directories and logs (optional):**
    ```bash
    sudo rm -rf /opt/bitnami/backups
    sudo rm /var/log/backup_db.log
    sudo rm /var/log/backup_fullsite.log
    ```

## Troubleshooting

* **Permissions issues:** Ensure the `bitnami` user has read access to `wp-config.php` and write access to the backup directories and log files. The `setup.sh` script attempts to set these, but manual checks may be needed.
* **`mysqldump` errors:** Check your `wp-config.php` for correct database credentials.
* **Cron not running:** Check `/var/log/syslog` for cron-related messages, or try running the scripts manually as the `bitnami` user to see any direct errors.
