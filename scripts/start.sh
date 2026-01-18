#!/bin/bash
# =============================================================================
# Hackazon Container Startup Script
# =============================================================================

echo "=========================================="
echo "Starting Hackazon Container"
echo "=========================================="

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
HACKAZON_DB="hackazon"
HACKAZON_USER="hackazon"

# Generate secure random passwords
generate_password() {
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16
}

MYSQL_PASSWORD=$(generate_password)
HACKAZON_PASSWORD=$(generate_password)

echo "[INFO] Generated secure passwords"

# -----------------------------------------------------------------------------
# Start MySQL
# -----------------------------------------------------------------------------
echo "[INFO] Starting MySQL..."
# Touch files to overcome overlay filesystem issues on Mac/Windows
find /var/lib/mysql -type f -exec touch {} \; 2>/dev/null || true
/usr/bin/mysqld_safe &
sleep 10

# Wait for MySQL to be ready
echo "[INFO] Waiting for MySQL to start..."
for i in {1..30}; do
    if mysqladmin ping -h localhost --silent 2>/dev/null; then
        echo "[INFO] MySQL is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "[ERROR] MySQL failed to start"
        exit 1
    fi
    sleep 1
done

# -----------------------------------------------------------------------------
# Configure MySQL
# -----------------------------------------------------------------------------
echo "[INFO] Configuring MySQL..."

# Set root password
mysqladmin -u root password "${MYSQL_PASSWORD}"

# Create database and user
mysql -uroot -p${MYSQL_PASSWORD} -e "
CREATE DATABASE IF NOT EXISTS ${HACKAZON_DB};
GRANT ALL PRIVILEGES ON ${HACKAZON_DB}.* TO '${HACKAZON_USER}'@'localhost' IDENTIFIED BY '${HACKAZON_PASSWORD}';
FLUSH PRIVILEGES;
"

echo "[INFO] MySQL configured"

# -----------------------------------------------------------------------------
# Import Database Schema
# -----------------------------------------------------------------------------
echo "[INFO] Importing database schema..."
mysql -uroot -p${MYSQL_PASSWORD} ${HACKAZON_DB} < "/var/www/hackazon/database/createdb.sql"

# -----------------------------------------------------------------------------
# Update Application Configuration
# -----------------------------------------------------------------------------
echo "[INFO] Updating application configuration..."

# Update database password in config
sed -i "s/yourdbpass/${HACKAZON_PASSWORD}/" /var/www/hackazon/assets/config/db.php
sed -i "s/youradminpass/${HACKAZON_PASSWORD}/" /var/www/hackazon/assets/config/parameters.php

# Hash password for admin user
HASHED_PASSWORD=$(php /passwordHash.php "${HACKAZON_PASSWORD}")
mysql -uroot -p${MYSQL_PASSWORD} -e \
    "UPDATE ${HACKAZON_DB}.tbl_users SET password='${HASHED_PASSWORD}' WHERE username='admin';"

# -----------------------------------------------------------------------------
# Save Credentials
# -----------------------------------------------------------------------------
echo "[INFO] Saving credentials..."
cat > /credentials.txt <<CREDS
==========================================
Hackazon Credentials
==========================================
MySQL Root Password: ${MYSQL_PASSWORD}
Hackazon DB Password: ${HACKAZON_PASSWORD}
Hackazon Admin User: admin
Hackazon Admin Password: ${HACKAZON_PASSWORD}
==========================================
CREDS
chmod 600 /credentials.txt

# Backwards compatibility
echo "${MYSQL_PASSWORD}" > /mysql-root-pw.txt
echo "${HACKAZON_PASSWORD}" > /hackazon-db-pw.txt
chmod 600 /mysql-root-pw.txt /hackazon-db-pw.txt

# -----------------------------------------------------------------------------
# Display Credentials
# -----------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "Hackazon is starting up!"
echo "=========================================="
echo ""
echo "Admin Credentials:"
echo "  Username: admin"
echo "  Password: ${HACKAZON_PASSWORD}"
echo ""
echo "Credentials saved in /credentials.txt"
echo "=========================================="
echo ""

# -----------------------------------------------------------------------------
# Stop MySQL (Supervisor will restart it)
# -----------------------------------------------------------------------------
echo "[INFO] Stopping MySQL for Supervisor takeover..."
killall mysqld 2>/dev/null || true
sleep 5

# -----------------------------------------------------------------------------
# Start Supervisor
# -----------------------------------------------------------------------------
echo "[INFO] Starting Supervisor..."
exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
