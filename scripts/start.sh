#!/bin/bash
# =============================================================================
# Hackazon Container Startup Script
# =============================================================================
set -e

echo "=========================================="
echo "Starting Hackazon Container"
echo "=========================================="

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
MYSQL_USER="root"
HACKAZON_DB="hackazon"
HACKAZON_USER="hackazon"

# Generate secure random passwords using /dev/urandom
generate_password() {
    tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c 16
}

MYSQL_PASSWORD=$(generate_password)
HACKAZON_PASSWORD=$(generate_password)

echo "[INFO] Generated secure passwords"

# -----------------------------------------------------------------------------
# Initialize MySQL data directory if needed
# -----------------------------------------------------------------------------
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "[INFO] Initializing MySQL data directory..."
    mysqld --initialize-insecure --user=mysql
fi

# -----------------------------------------------------------------------------
# Start MySQL
# -----------------------------------------------------------------------------
echo "[INFO] Starting MySQL..."
find /var/lib/mysql -type f -exec touch {} \; 2>/dev/null || true
chown -R mysql:mysql /var/lib/mysql /var/run/mysqld

# Start MySQL in the background
mysqld_safe --skip-grant-tables &
MYSQL_PID=$!

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
# Configure MySQL Security
# -----------------------------------------------------------------------------
echo "[INFO] Configuring MySQL security..."

# Set root password and create hackazon user
mysql -u root <<EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}';
CREATE DATABASE IF NOT EXISTS ${HACKAZON_DB};
CREATE USER IF NOT EXISTS '${HACKAZON_USER}'@'localhost' IDENTIFIED BY '${HACKAZON_PASSWORD}';
GRANT ALL PRIVILEGES ON ${HACKAZON_DB}.* TO '${HACKAZON_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

# -----------------------------------------------------------------------------
# Import Database Schema
# -----------------------------------------------------------------------------
echo "[INFO] Importing database schema..."
mysql -u${HACKAZON_USER} -p${HACKAZON_PASSWORD} ${HACKAZON_DB} < "/var/www/hackazon/database/createdb.sql"

# -----------------------------------------------------------------------------
# Update Application Configuration
# -----------------------------------------------------------------------------
echo "[INFO] Updating application configuration..."

# Update database password in config
sed -i "s/yourdbpass/${HACKAZON_PASSWORD}/" /var/www/hackazon/assets/config/db.php
sed -i "s/youradminpass/${HACKAZON_PASSWORD}/" /var/www/hackazon/assets/config/parameters.php

# Hash password for admin user
HASHED_PASSWORD=$(php /passwordHash.php "${HACKAZON_PASSWORD}")
mysql -u${HACKAZON_USER} -p${HACKAZON_PASSWORD} -e \
    "UPDATE ${HACKAZON_DB}.tbl_users SET password='${HASHED_PASSWORD}' WHERE username='admin';"

# -----------------------------------------------------------------------------
# Save Credentials (for reference)
# -----------------------------------------------------------------------------
echo "[INFO] Saving credentials..."
cat > /credentials.txt <<EOF
========================================
Hackazon Credentials
========================================
MySQL Root Password: ${MYSQL_PASSWORD}
Hackazon DB Password: ${HACKAZON_PASSWORD}
Hackazon Admin User: admin
Hackazon Admin Password: ${HACKAZON_PASSWORD}
========================================
EOF
chmod 600 /credentials.txt

# Also save individual files for backwards compatibility
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
echo "Credentials are also saved in /credentials.txt"
echo "=========================================="
echo ""

# -----------------------------------------------------------------------------
# Stop MySQL (Supervisor will restart it)
# -----------------------------------------------------------------------------
echo "[INFO] Stopping MySQL for Supervisor takeover..."
mysqladmin -u root -p${MYSQL_PASSWORD} shutdown 2>/dev/null || killall mysqld 2>/dev/null || true
sleep 3

# -----------------------------------------------------------------------------
# Start Supervisor
# -----------------------------------------------------------------------------
echo "[INFO] Starting Supervisor..."
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
