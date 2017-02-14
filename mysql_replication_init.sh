#!/bin/sh

. ./params.inc

# Première synchro (pour gagner du temps après)
echo "MASTER : Première synchro locale (master=>backup)"
rsync -av $db_folder/ $db_folder_backup/
echo "SLAVE : Première synchro distante (backup=>recup)"
rsync -avz $db_folder_backup/ root@$slave_server:$db_folder_backup/

# Seconde synchro (pour gagner du temps après)
echo "MASTER : Seconde synchro locale (master=>backup)"
rsync -av $db_folder/ $db_folder_backup/
#echo "SLAVE : Seconde synchro distante (backup=>recup)"
#rsync -avz $db_folder_backup/ root@$slave_server:$db_folder_backup/

echo "MASTER : Recup master status (obsolète puisque reset master+slave)"
echo "--" >> master_status
echo `date` >> master_status
mysql -u root -p$db_password -e "SHOW MASTER STATUS;" >> master_status

# Flush and Lock tables
# Reset Master Replication
echo "MASTER : FLUSH, LOCK TABLES, RESET Replication"
mysql -u root -p$db_password -e "FLUSH TABLES WITH READ LOCK; RESET MASTER;"

# ATTENTION ! Bien noter l'�tat de la réplication maitre ! Dans master_status ;-)

# Stop Master MySQL
echo "MASTER : STOP Mysql"
/etc/init.d/mysql stop
# Obligatoire de facon a recuperer proprement les données en cache des tables innodb

# Stop et reinit replication slave 
echo "SLAVE : Reset Replication"
ssh root@$slave_server "mysql -u root -p$db_password -e \"STOP SLAVE;\""

# Resynchro et finalisation copie base Master
echo "MASTER : Synchro finale (vers backup/recup)"
rsync -av $db_folder/ $db_folder_backup/
# Suppression log binaire Master (pas forcement utile, normalement le reset master s'en est chargé)
echo "MASTER : Suppression binlog"
rm -f /var/log/mysql/mariadb-bin*

# Start Master MySQL
echo "MASTER : START Mysql"
/etc/init.d/mysql start
# Unlock tables
echo "MASTER : UNLOCK TABLES"
mysql -u root -p$db_password -e "UNLOCK TABLES;"

# Start Slave
echo "SLAVE : Synchro finale (backup=>recup)"
rsync -avz $db_folder_backup/ root@$slave_server:$db_folder_backup/
echo "SLAVE : Reset Replication"
ssh root@$slave_server "mysql -u root -p$db_password -e \"RESET SLAVE;\""
echo "SLAVE : STOP Mysql"
ssh root@$slave_server "/etc/init.d/mysql stop"
echo "SLAVE : Synchro finale (recup=>slave)"
ssh root@$slave_server "rsync -av $db_folder_backup/ $db_folder/"
echo "SLAVE : START Mysql"
ssh root@$slave_server "/etc/init.d/mysql start"
echo "SLAVE : Restart Replication"
ssh root@$slave_server "mysql -u root -p$db_password -e \"CHANGE MASTER TO MASTER_HOST='$master_server', MASTER_USER='$master_replication_user', MASTER_PASSWORD='$master_replication_password', MASTER_LOG_FILE='mariadb-bin.000001', MASTER_LOG_POS=0; START SLAVE;\""

