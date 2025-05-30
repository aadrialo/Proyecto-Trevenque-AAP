#!/bin/bash
set -e

DB_HOST="10.211.20.150"
DB_NAME="laravel_db"
DB_USER="laravel_user"
DB_PASS="pass"

echo "=== Actualizando sistema ==="
sudo apt update && sudo apt upgrade -y

echo "=== Instalando PHP y extensiones necesarias ==="
sudo apt install php php-cli php-mbstring php-xml php-bcmath php-curl php-mysql php-zip unzip curl git -y

echo "=== Instalando Composer ==="
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

echo "=== Instalando Apache ==="
sudo apt install apache2 libapache2-mod-php -y

echo "=== Instalando Laravel ==="
cd /var/www
sudo composer create-project --prefer-dist laravel/laravel laravel

echo "=== Asignando permisos a Laravel ==="
sudo chown -R www-data:www-data laravel
sudo chmod -R 775 laravel/storage
sudo chmod -R 775 laravel/bootstrap/cache

echo "=== Creando VirtualHost para Laravel ==="
cat <<EOF | sudo tee /etc/apache2/sites-available/laravel.conf
<VirtualHost *:80>
    ServerName laravel.local
    DocumentRoot /var/www/laravel/public

    <Directory /var/www/laravel/public>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/laravel_error.log
    CustomLog \${APACHE_LOG_DIR}/laravel_access.log combined
</VirtualHost>
EOF

echo "=== Activando configuración de Apache ==="
sudo a2ensite laravel.conf
sudo a2enmod rewrite

# Asegurar que AllowOverride All esté habilitado en apache2.conf
sudo sed -i 's|<Directory /var/www/>|<Directory /var/www/>\n    AllowOverride All|' /etc/apache2/apache2.conf

echo "=== Desactivando sitio por defecto de Apache ==="
sudo a2dissite 000-default.conf

echo "=== Reiniciando Apache ==="
sudo systemctl restart apache2

echo "=== Configurando .env de Laravel ==="
cd /var/www/laravel
sudo cp .env.example .env

sudo sed -i "s|^\s*#\?\s*DB_CONNECTION=.*|DB_CONNECTION=mysql|" .env
sudo sed -i "s|^\s*#\?\s*DB_HOST=.*|DB_HOST=${DB_HOST}|" .env
sudo sed -i "s|^\s*#\?\s*DB_PORT=.*|DB_PORT=3306|" .env
sudo sed -i "s|^\s*#\?\s*DB_DATABASE=.*|DB_DATABASE=${DB_NAME}|" .env
sudo sed -i "s|^\s*#\?\s*DB_USERNAME=.*|DB_USERNAME=${DB_USER}|" .env
sudo sed -i "s|^\s*#\?\s*DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|" .env

echo "=== Generando clave de aplicación y migrando base de datos ==="
sudo -u www-data php artisan key:generate
sudo -u www-data php artisan migrate

echo "=== Laravel está instalado y configurado correctamente ==="
