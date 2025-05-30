#!/bin/bash

echo "=== Nodo 2: Actualizando sistema ==="
sudo apt update -y
sudo apt upgrade -y

echo "=== Nodo 2: Instalando MariaDB y Galera ==="
sudo apt install mariadb-server galera-4 -y

echo "=== Nodo 2: Configurando Galera (60-galera.cnf) ==="
cat <<EOF | sudo tee /etc/mysql/mariadb.conf.d/60-galera.cnf
[galera]
wsrep_on = ON
wsrep_cluster_name = "galera-cluster"
wsrep_cluster_address = gcomm://10.211.20.150,10.211.20.151,10.211.20.152
wsrep_node_name = galera-node2
wsrep_node_address = 10.211.20.152
wsrep_provider = /usr/lib/galera/libgalera_smm.so
wsrep_sst_method = rsync
binlog_format = row
default_storage_engine = InnoDB
innodb_autoinc_lock_mode = 2
bind-address = 0.0.0.0
wsrep_slave_threads = 1
innodb_flush_log_at_trx_commit = 0
EOF

echo "=== Nodo 2: Configurando MariaDB para aceptar conexiones remotas ==="
sudo sed -i "s/^bind-address\s*=.*/bind-address = 0.0.0.0/" /etc/mysql/mariadb.conf.d/50-server.cnf

echo "=== Nodo 2: Abriendo puertos necesarios ==="
sudo ufw allow 3306/tcp
sudo ufw allow 4567/tcp
sudo ufw allow 4568/tcp
sudo ufw allow 4444/tcp

echo "=== Nodo 2: Deteniendo MariaDB ==="
sudo systemctl stop mariadb

echo "=== Nodo 2: Iniciando MariaDB y uniéndose al clúster ==="
sudo systemctl start mariadb

echo "=== Nodo 2: Verificando el estado del clúster ==="
mysql -u root -p -e "SHOW STATUS LIKE 'wsrep_cluster_size';"

echo "=== Nodo 2: Setup completado. Verifica el clúster con: ==="
echo "mysql -u root -p -e \"SHOW STATUS LIKE 'wsrep_cluster_size';\""
