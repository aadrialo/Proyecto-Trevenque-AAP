#!/bin/bash
set -e

echo "=== Actualizando sistema ==="
sudo apt update -y && sudo apt upgrade -y

echo "=== Instalando NGINX ==="
sudo apt install nginx -y

echo "=== Configurando NGINX como balanceador de carga para Laravel ==="
sudo tee /etc/nginx/sites-available/laravel-lb > /dev/null <<EOF
upstream laravel_cluster {
    server 10.211.20.100;
    server 10.211.20.101;
}

server {
    listen 80;

    location / {
        proxy_pass http://laravel_cluster;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

    }
}
EOF

echo "=== Activando configuración de balanceo ==="
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -s /etc/nginx/sites-available/laravel-lb /etc/nginx/sites-enabled/

echo "=== Verificando configuración de NGINX ==="
sudo nginx -t

echo "=== Reiniciando NGINX ==="
sudo systemctl reload nginx




