#!/bin/bash
set -e

dnf update -y
dnf install -y httpd php php-mysqlnd php-fpm php-json php-mbstring php-cli php-common php-opcache php-gd wget unzip mariadb105

systemctl enable httpd
systemctl start httpd

wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
mv wordpress/* /var/www/html/
chown -R apache:apache /var/www/html/
chmod -R 755 /var/www/html/

cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php

# Setze Konfigurationswerte direkt
sed -i "s/database_name_here/${DB_NAME}/" /var/www/html/wp-config.php
sed -i "s/username_here/${DB_USER}/" /var/www/html/wp-config.php
sed -i "s/password_here/${DB_PASSWORD}/" /var/www/html/wp-config.php
sed -i "s/localhost/${DB_HOST}/" /var/www/html/wp-config.php
