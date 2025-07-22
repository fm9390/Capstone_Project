#!/bin/bash
set -ex

dnf update -y
dnf install -y httpd php php-mysqlnd php-fpm php-json php-mbstring php-cli php-common php-opcache php-gd wget unzip mariadb105 bind-utils

systemctl enable httpd
systemctl start httpd

# Logging starten
echo "==== STARTE SETUP ====" > /tmp/debug.log

# DNS-Check
echo "Prüfe DNS-Auflösung für ${DB_HOST}..." >> /tmp/debug.log
nslookup "${DB_HOST}" >> /tmp/debug.log 2>&1 || echo "⚠️ DNS-Auflösung fehlgeschlagen" >> /tmp/debug.log

# Warten auf die Datenbank (max 10 Minuten)
echo "Warte auf Datenbank ${DB_HOST}..." | tee -a /tmp/debug.log
echo "${DB_HOST}" "${DB_USER}" "${DB_PASSWORD}"
for i in {1..60}; do
  if mysql -h "${DB_HOST}" -u "${DB_USER}" -p"${DB_PASSWORD}" -e "SELECT 1" > /dev/null 2>&1; then
    echo "✅ Datenbank ist erreichbar!" | tee -a /tmp/debug.log
    break
  fi
  echo "⏳ ($${i}/60) Noch nicht erreichbar, warte 10s..." | tee -a /tmp/debug.log
  sleep 10
done

# Letzter Versuch nach der Schleife
if ! mysql -h "${DB_HOST}" -u "${DB_USER}" -p"${DB_PASSWORD}" -e "SELECT 1" > /dev/null 2>&1; then
  echo "❌ Fehler: Datenbank nach 10 Minuten nicht erreichbar." | tee -a /tmp/debug.log
  exit 1
fi

# WordPress Setup
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
mv wordpress/* /var/www/html/
chown -R apache:apache /var/www/html/
chmod -R 755 /var/www/html/

cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php

# Setze Konfiguration
sed -i "s/database_name_here/${DB_NAME}/" /var/www/html/wp-config.php
sed -i "s/username_here/${DB_USER}/" /var/www/html/wp-config.php
sed -i "s/password_here/${DB_PASSWORD}/" /var/www/html/wp-config.php
sed -i "s/localhost/${DB_HOST}/" /var/www/html/wp-config.php

# Prüfung
if [ -f /var/www/html/wp-config.php ]; then
  echo "✅ wp-config.php erfolgreich erstellt." | tee -a /tmp/debug.log
else
  echo "❌ Fehler: wp-config.php wurde nicht erstellt!" | tee -a /tmp/debug.log
  exit 1
fi

echo "==== SETUP ABGESCHLOSSEN ====" >> /tmp/debug.log