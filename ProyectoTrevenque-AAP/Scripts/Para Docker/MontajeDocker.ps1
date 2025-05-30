# Ir al directorio C:\Users\<usuario_actual>
Set-Location -Path "C:\Users\$env:USERNAME"

# Crear la estructura de carpetas
New-Item -Path "proyecto-dockerizado" -ItemType Directory -Force
New-Item -Path "proyecto-dockerizado\laravel-app" -ItemType Directory -Force
New-Item -Path "proyecto-dockerizado\nginx" -ItemType Directory -Force
New-Item -Path "proyecto-dockerizado\mariadb-config" -ItemType Directory -Force
New-Item -Path "proyecto-dockerizado\gitea\data" -ItemType Directory -Force


# Crear archivos mariadb-config/galera-db1.cnf
Set-Content -Path "proyecto-dockerizado\mariadb-config\galera-db1.cnf" -Value @'
[mysqld]
binlog_format=ROW
default_storage_engine=InnoDB
innodb_autoinc_lock_mode=2
bind-address=0.0.0.0

wsrep_on=ON
wsrep_provider=/usr/lib/galera/libgalera_smm.so
wsrep_cluster_name="galera_cluster"
wsrep_cluster_address="gcomm://db1,db2,db3"
wsrep_node_address="db1"
wsrep_node_name="db1"

wsrep_sst_method=rsync
'@

# mariadb-config/galera-db2.cnf
Set-Content -Path "proyecto-dockerizado\mariadb-config\galera-db2.cnf" -Value @'
[mysqld]
binlog_format=ROW
default_storage_engine=InnoDB
innodb_autoinc_lock_mode=2
bind-address=0.0.0.0

wsrep_on=ON
wsrep_provider=/usr/lib/galera/libgalera_smm.so
wsrep_cluster_name="galera_cluster"
wsrep_cluster_address="gcomm://db1,db2,db3"
wsrep_node_address="db2"
wsrep_node_name="db2"

wsrep_sst_method=rsync
'@

# mariadb-config/galera-db3.cnf
Set-Content -Path "proyecto-dockerizado\mariadb-config\galera-db3.cnf" -Value @'
[mysqld]
binlog_format=ROW
default_storage_engine=InnoDB
innodb_autoinc_lock_mode=2
bind-address=0.0.0.0

wsrep_on=ON
wsrep_provider=/usr/lib/galera/libgalera_smm.so
wsrep_cluster_name="galera_cluster"
wsrep_cluster_address="gcomm://db1,db2,db3"
wsrep_node_address="db3"
wsrep_node_name="db3"

wsrep_sst_method=rsync
'@

# mariadb-config/galera.cnf
Set-Content -Path "proyecto-dockerizado\mariadb-config\galera.cnf" -Value @'
[mysqld]
binlog_format=ROW
default_storage_engine=InnoDB
innodb_autoinc_lock_mode=2
bind-address=0.0.0.0

wsrep_on=ON
wsrep_provider=/usr/lib/galera/libgalera_smm.so
wsrep_cluster_name="galera_cluster"
wsrep_cluster_address="gcomm://db1,db2,db3"
wsrep_node_address="AUTO_REPLACE"
wsrep_node_name="AUTO_REPLACE"

wsrep_sst_method=rsync
'@

# mariadb-config/init.sql
Set-Content -Path "proyecto-dockerizado\mariadb-config\init.sql" -Value @'
CREATE DATABASE IF NOT EXISTS laravel;
GRANT ALL ON laravel.* TO 'laravel'@'%' IDENTIFIED BY 'secret';
FLUSH PRIVILEGES;
'@

# nginx/default.conf
Set-Content -Path "proyecto-dockerizado\nginx\default.conf" -Value @'
upstream laravel {
    server web1:80;
    server web2:80;
}

server {
    listen 80;

    location / {
        proxy_pass http://laravel;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
'@

# docker-compose.yml
Set-Content -Path "proyecto-dockerizado\docker-compose.yml" -Value @'
version: "3.8"

services:

  db1:
    image: mariadb:10.5
    container_name: db1
    volumes:
      - ./mariadb-config/galera-db1.cnf:/etc/mysql/conf.d/galera.cnf
      - ./mariadb-config/init.sql:/docker-entrypoint-initdb.d/init.sql
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: laravel
      MYSQL_USER: laravel
      MYSQL_PASSWORD: secret
      CLUSTER_NAME: galera_cluster
    networks:
      - backend

  db2:
    image: mariadb:10.5
    container_name: db2
    volumes:
      - ./mariadb-config/galera-db2.cnf:/etc/mysql/conf.d/galera.cnf
    environment:
      MYSQL_ROOT_PASSWORD: root
      CLUSTER_NAME: galera_cluster
    networks:
      - backend

  db3:
    image: mariadb:10.5
    container_name: db3
    volumes:
      - ./mariadb-config/galera-db3.cnf:/etc/mysql/conf.d/galera.cnf
    environment:
      MYSQL_ROOT_PASSWORD: root
      CLUSTER_NAME: galera_cluster
    networks:
      - backend

  web1:
    build:
      context: ./laravel-app
      dockerfile: ../Dockerfile
    container_name: web1
    volumes:
      - ./laravel-app:/var/www/html
    depends_on:
      - db1
    networks:
      - backend
      - frontend

  web2:
    build:
      context: ./laravel-app
      dockerfile: ../Dockerfile
    container_name: web2
    volumes:
      - ./laravel-app:/var/www/html
    depends_on:
      - db1
    networks:
      - backend
      - frontend

  nginx:
    image: nginx:latest
    container_name: nginx-balancer
    ports:
      - "80:80"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - web1
      - web2
    networks:
      - frontend

  gitea:
    image: gitea/gitea:latest
    container_name: gitea
    restart: unless-stopped
    environment:
      USER_UID: 1000
      USER_GID: 1000
      GITEA__APP_NAME: "Servidor GIT Interno"
      GITEA__server__DOMAIN: localhost
      GITEA__server__ROOT_URL: http://localhost:3000/
      GITEA__server__HTTP_PORT: 3000
      GITEA__database__DB_TYPE: sqlite3
    volumes:
      - ./gitea/data:/data
    ports:
      - "3000:3000"
    networks:
      - frontend
      - backend

networks:
  backend:
  frontend:
'@

# Dockerfile
Set-Content -Path "proyecto-dockerizado\Dockerfile" -Value @'
FROM php:8.3-apache

RUN apt-get update && apt-get install -y \
    git unzip zip libzip-dev libpng-dev libonig-dev libxml2-dev \
    && docker-php-ext-install pdo_mysql zip

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

RUN a2enmod rewrite

RUN sed -i 's|/var/www/html|/var/www/html/public|g' /etc/apache2/sites-available/000-default.conf

CMD bash -c "composer install && php artisan key:generate && apache2-foreground"

EXPOSE 80

'@

# Crear proyecto Laravel con Composer en laravel-app
Set-Location -Path "proyecto-dockerizado\laravel-app"
composer create-project laravel/laravel . --quiet

# Sobrescribir el archivo .env con la configuración dada
$envContent = @'
APP_NAME=Laravel
APP_ENV=local
APP_KEY=base64:dgnxf3Yt1x00j3QgiFiBrvOZu1XfFY7TVTDDaJYBN+w=
APP_DEBUG=true
APP_URL=http://localhost

APP_LOCALE=en
APP_FALLBACK_LOCALE=en
APP_FAKER_LOCALE=en_US

APP_MAINTENANCE_DRIVER=file
# APP_MAINTENANCE_STORE=database

PHP_CLI_SERVER_WORKERS=4

BCRYPT_ROUNDS=12

LOG_CHANNEL=stack
LOG_STACK=single
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=debug

DB_CONNECTION=mysql
DB_HOST=db1
DB_PORT=3306
DB_DATABASE=laravel
DB_USERNAME=laravel
DB_PASSWORD=secret

BROADCAST_DRIVER=log
CACHE_DRIVER=file
SESSION_DRIVER=file
SESSION_LIFETIME=120
SESSION_ENCRYPT=false
SESSION_PATH=/
SESSION_DOMAIN=null

BROADCAST_CONNECTION=log
FILESYSTEM_DISK=local
QUEUE_CONNECTION=sync

CACHE_STORE=database
# CACHE_PREFIX=

MEMCACHED_HOST=127.0.0.1

REDIS_CLIENT=phpredis
REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_MAILER=log
MAIL_SCHEME=null
MAIL_HOST=127.0.0.1
MAIL_PORT=2525
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_FROM_ADDRESS="hello@example.com"
MAIL_FROM_NAME="${APP_NAME}"

AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_DEFAULT_REGION=us-east-1
AWS_BUCKET=
AWS_USE_PATH_STYLE_ENDPOINT=false

VITE_APP_NAME="${APP_NAME}"
'@

Set-Content -Path ".\.env" -Value $envContent -Encoding UTF8

# Volver a la raíz del proyecto
Set-Location -Path ".."

# Lanzar el proyecto Docker
docker-compose up -d --build
