#!/bin/bash

echo "=== Actualizando sistema ==="
sudo apt update -y
sudo apt upgrade -y

echo "=== Instalando MariaDB y Galera ==="
sudo apt install mariadb-server galera-4 -y

echo "=== Creando base de datos y usuario remoto para Laravel ==="
mysql -u root <<EO_SQL
CREATE DATABASE laravel_db;
CREATE USER 'laravel_user'@'%' IDENTIFIED BY 'pass';
GRANT ALL PRIVILEGES ON laravel_db.* TO 'laravel_user'@'%';
FLUSH PRIVILEGES;
EO_SQL

echo "=== Configurando Galera (60-galera.cnf) ==="
cat <<EOF | sudo tee /etc/mysql/mariadb.conf.d/60-galera.cnf
[galera]
wsrep_on = ON
wsrep_cluster_name = "galera-cluster"
wsrep_cluster_address = gcomm://10.211.20.150,10.211.20.151,10.211.20.152
wsrep_node_name = galera-node1
wsrep_node_address = 10.211.20.150
wsrep_provider = /usr/lib/galera/libgalera_smm.so
wsrep_sst_method = rsync
binlog_format    = row
default_storage_engine   = InnoDB
innodb_autoinc_lock_mode     = 2
bind-address = 0.0.0.0
wsrep_slave_threads = 1
innodb_flush_log_at_trx_commit = 0
EOF

echo "=== Abriendo puertos necesarios ==="
sudo ufw allow 3306/tcp
sudo ufw allow 4567/tcp
sudo ufw allow 4568/tcp
sudo ufw allow 4444/tcp

echo "=== Deteniendo MariaDB para iniciar el cluster ==="
sudo systemctl stop mariadb

echo "=== Inicializando el clúster Galera ==="
sudo galera_new_cluster

echo "=== Verificando el estado del clúster ==="
mysql -u root -p -e "SHOW STATUS LIKE 'wsrep_cluster_size';"

echo "=== Configurando MariaDB para aceptar conexiones remotas ==="
sudo sed -i "s/^bind-address\s*=.*/bind-address = 0.0.0.0/" /etc/mysql/mariadb.conf.d/50-server.cnf

echo "=== Setup completado. Verifica el clúster con: ==="
echo "mysql -u root -p -e \"SHOW STATUS LIKE 'wsrep_cluster_size';\""
