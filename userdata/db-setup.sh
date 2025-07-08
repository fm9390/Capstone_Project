#!/bin/bash

# Update system
yum update -y

# Install MariaDB
amazon-linux-extras enable mariadb10.5
yum install -y mariadb-server

# Enable and start MariaDB service
systemctl enable mariadb
systemctl start mariadb

# Create database and user
mysql <<EOF
CREATE DATABASE wordpress;
CREATE USER 'wordpress'@'%' IDENTIFIED BY 'StrongPassword123!';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'%';
FLUSH PRIVILEGES;
EOF

