#!/bin/bash

#
# Script for running automated backups for Snipe-IT Docker containers and removing old backups
#
# Mean to be used as part of a crontab
#
# Limits its search for backups to clean up to those in the 'BACKUP_DIR' folder, so
# you can create folders in this location to keep any manual backups for historical purposes
#
# Source: https://aporlebeke.wordpress.com/2019/06/04/configuring-automatic-snipe-it-backups-in-docker/
# Modified to clean up in the save dir

# Docker container name to backup
CONTAINER="${1}"
# Snipe-IT Docker container backup location
BACKUP_DIR="/var/www/html/storage/app/backups/"
# Location to save Backups to
SAVE_DIR="${2}"
# Number of backups to keep
MAX_BACKUPS="100"

# Verify a container name is supplied
if [ "$CONTAINER" = "" ]; then
	/bin/echo "No value supplied for 'CONTAINER'. Please run the script followed by the container name. ex. sh script.sh <container_name>"
	exit 1
fi


last_backup=$(docker exec $CONTAINER ls -t $BACKUP_DIR | head -n 1)
/bin/echo "Copying latest backup $last_backup from ${CONTAINER} …"
docker cp $CONTAINER:"$BACKUP_DIR$last_backup" $SAVE_DIR

# Process existing backups for cleanup
BACKUPS=$(/usr/bin/find "$SAVE_DIR" -maxdepth 1 -type f | /usr/bin/sort -r)
BACKUP_NUM=$((${MAX_BACKUPS} + 1))
OLD_BACKUPS=$(echo $BACKUPS | tail -n +${BACKUP_NUM})

# If old backups found, remove them
if [ "$OLD_BACKUPS" != "" ]; then
	echo "Cleaning up old backups …"
	for f in $OLD_BACKUPS; do
		echo "Removing old backup: ${f} …"
		rm $f
	done
else
	echo "No backups to clean. Done."
fi

exit