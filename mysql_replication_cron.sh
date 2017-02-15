#!/bin/bash

#
# CopyLeft Mathieu Moulin <lemathou@free.fr>
# GNU GPL v2
# 
# Mysql Replication Verification Script
# Usage : send an email when the replication process is stopped or too slow
# to prevent desynchronization problems
#

#
# You need to create a Mysql User replication_cron
# with "replication client" global administration privilege
#

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

. ./params.inc

if [ -f $tmp_replication_slave_reason_filepath ]; then
        rm -rf $tmp_replication_slave_reason_filepath
fi

echo "show slave status\G;" |mysql $cmd_slave_username $cmd_slave_hostname $cmd_slave_userpass > $tmp_replication_slave_log_filepath

grep "Access denied" $tmp_replication_slave_log_filepath
if [ "$?" -ne "1" ]; then
        msg="Access denied to MySQL slave user"
	echo $msg
        echo $msg >> $tmp_replication_slave_reason_filepath
fi

if [ ! -s $tmp_replication_slave_log_filepath ]; then
        msg="Slave status empty => Slave not running ?"
	echo $msg
        echo $msg >> $tmp_replication_slave_reason_filepath
fi

grep "Slave_IO_Running: No" $tmp_replication_slave_log_filepath
if [ "$?" -ne "1" ]; then
        msg="Slave IO not Running"
	echo $msg
        echo $msg >> $tmp_replication_slave_reason_filepath
fi

grep "Slave_SQL_Running: No" $tmp_replication_slave_log_filepath
if [ "$?" -ne "1" ]; then
        msg="Slave SQL not Running"
        echo $msg
        echo $msg >> $tmp_replication_slave_reason_filepath
fi

regex="Seconds_Behind_Master: \(\d+\)"
seconds=`grep "Seconds_Behind_Master" $tmp_replication_slave_log_filepath | tr -dc '0-9'`
if [ $seconds="" ]; then
	seconds=0
fi
if (( $seconds > $slave_verif_seconds_min )); then
	seconds_orig=$seconds
	minutes=$(( $seconds/60 ))
	hours=$(( $minutes/60 ))
	days=$(( $hours/24 ))
	hours=$(( $hours - 24*$days ))
	minutes=$(( $minutes - 60*(24*$days + $hours) ))
	seconds=$(( $seconds - 60*(60*(24*$days + $hours) + $minutes) ))
        msg="Seconds behind master : $seconds_orig => $days days, $hours hours, $minutes minutes, $seconds seconds"
        echo $msg
        echo $msg >> $tmp_replication_slave_reason_filepath
fi


if [ -f $tmp_replication_slave_reason_filepath ]; then
        mail -r $slave_verif_email_from -s "$slave_verif_email_subject" $slave_verif_email_to < $tmp_replication_slave_reason_filepath
        echo $tmp_replication_slave_reason_filepath
fi

