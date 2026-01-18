# =============================================================================
# Hackazon - Vulnerable E-commerce Application for Security Training
# =============================================================================
# This is a deliberately vulnerable web application for security testing
# and training purposes. DO NOT deploy in production environments.
#
# Note: Uses Ubuntu 14.04 and PHP 5 as Hackazon was designed for these versions.
# Modern PHP versions (7.2+) have breaking changes that prevent Hackazon from
# running. This is acceptable for a security training tool used in isolated
# environments.
# =============================================================================

FROM ubuntu:14.04

LABEL maintainer="v0rt3x"
LABEL description="All-in-one Hackazon container for security testing and training"
LABEL version="2.0"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get -y upgrade && \
    apt-get -y install \
    mysql-client \
    mysql-server \
    apache2 \
    libapache2-mod-php5 \
    php5-mysql \
    php5-ldap \
    php5-curl \
    php5-gd \
    pwgen \
    supervisor \
    vim-tiny \
    unzip \
    curl \
    && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create necessary directories
RUN mkdir -p /var/log/supervisor /var/run/mysqld && \
    chown mysql:mysql /var/run/mysqld

# Copy configuration files
COPY ./scripts/start.sh /start.sh
COPY ./scripts/passwordHash.php /passwordHash.php
COPY ./scripts/foreground.sh /etc/apache2/foreground.sh
COPY ./configs/supervisord.conf /etc/supervisor/supervisord.conf
COPY ./configs/000-default.conf /etc/apache2/sites-available/000-default.conf

# Make scripts executable
RUN chmod +x /start.sh /etc/apache2/foreground.sh

# Download and setup Hackazon
RUN rm -rf /var/www/ && \
    curl -L -o /hackazon-master.zip https://github.com/rapid7/hackazon/archive/master.zip && \
    unzip /hackazon-master.zip -d /tmp && \
    mkdir -p /var/www && \
    mv /tmp/hackazon-master /var/www/hackazon && \
    rm /hackazon-master.zip && \
    # Setup config files from samples
    cp /var/www/hackazon/assets/config/db.sample.php /var/www/hackazon/assets/config/db.php && \
    cp /var/www/hackazon/assets/config/email.sample.php /var/www/hackazon/assets/config/email.php

# Copy application configuration files
COPY ./configs/parameters.php /var/www/hackazon/assets/config/parameters.php
COPY ./configs/rest.php /var/www/hackazon/assets/config/rest.php
COPY ./configs/createdb.sql /var/www/hackazon/database/createdb.sql

# Set proper ownership and permissions
RUN chown -R www-data:www-data /var/www/hackazon && \
    chmod -R 755 /var/www/hackazon && \
    chmod -R 775 /var/www/hackazon/web/products_pictures \
                 /var/www/hackazon/web/upload \
                 /var/www/hackazon/assets/config

# Enable Apache modules
RUN a2enmod rewrite

# Expose HTTP port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -sf http://localhost/ || exit 1

# Start services
CMD ["/bin/bash", "/start.sh"]
