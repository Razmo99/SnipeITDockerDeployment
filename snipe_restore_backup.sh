#!/bin/bash

#
# Script to restore Snipe-IT backups into a Docker Container
#
# Intented for Manual Use to restore containers from backups
# 
# unzips the backup, copies the uploads & private uploads to correct directories
# copies sql dump and then restores the dump to the mysql database Collects credentials from .env variables in the container.
#

#Zip file containing the snipe-it backup
backup_zip="${1}"
backup_zip_name=$(basename $backup_zip .zip)
container_id="${2}"
#Dir to unzip the snipeit backup to
unzip_dir="${3:-./${backup_zip_name}/}"

# Check to see if the backup zip path is valid
if [[ -s $backup_zip ]]
then
	echo "Found $backup_zip"
else
	echo "$backup_zip does not exist or is not a file."
	exit 1
fi

#Make the unzip directory if it does not exist
if [[ -d $unzip_dir ]]
then
	echo "Found unzip dir: $unzip_dir"
else
	echo "Making dir: $unzip_dir"
	mkdir $unzip_dir
fi

# unzip the backup
unzip -oq $backup_zip -d $unzip_dir

#Check if the unzip operation failed and exit if it did
if [ $? != 0 ]
then
	exit 1
fi
# Find the uploads dir in the unzip direcotry
uploads_dir=$(find $unzip_dir -type d -name uploads)
# Find the private_uploads dir in the unzip direcotry
private_uploads_dir=$(find $unzip_dir -type d -name private_uploads)
# Find the SQL Dump dir in the unzip direcotry
sql_dump=$(find $unzip_dir -type f -name *.sql)
# Grab the name of the sql dump for later use
sql_dump_name=$(basename $sql_dump .sql)
# Find the oauth-private.key dir in the unzip direcotry
oauth_private=$(find $unzip_dir -type f -name oauth-private.key)
# Find the oauth-public.key dir in the unzip direcotry
oauth_public=$(find $unzip_dir -type f -name oauth-public.key)
# If the above can be found then proceed otherwise exit
if [[ -d $uploads_dir ]] && [[ -d $private_uploads_dir ]] && [[ -f $sql_dump ]] && [[ -f $oauth_private ]] && [[ -f $oauth_public ]]
then
	echo "Found Snipe Extracted Backup Files"
else
	echo "Failed to find Snipe Extracted Backup Files"
	exit 1
fi
# Put the site into maintenance mode
docker exec $container_id php /var/www/html/artisan down

# Remove any existing content in the containers uploads and private_uploads directories.
echo "Clearing Container Data Directories"
docker exec $container_id rm -rf /var/lib/snipeit/data/private_uploads/* /var/lib/snipeit/data/uploads/* 
restore_dir="/tmp/${backup_zip_name}/"
# Make a temp dir to store the sql dump
echo "Making Directory $restore_dir"
docker exec $container_id mkdir $restore_dir
# Copy over the private and public oauth keys, along with the uploads & private_uploads folder
echo "Copying backup data directories to $restore_dir"
docker cp $oauth_private $container_id:/var/lib/snipeit/keys/
docker cp $oauth_public $container_id:/var/lib/snipeit/keys/
docker cp "$uploads_dir/" $container_id:/var/lib/snipeit/data/
docker cp "$private_uploads_dir/" $container_id:/var/lib/snipeit/data/
# Copy over the sql dump
docker cp $sql_dump $container_id:$restore_dir
# Restore the sql database
# I dont like the below but it works. Hit me up if you have a better way
echo "Restoring MySQL DB: ${restore_dir}${sql_dump_name}.sql"
# Make some strings that will be combined and passed to the docker containter.
# The below string will be interprited by the container and should pull the env variables
mysql_conn='mysql -u $(echo $MYSQL_USER) -p$(echo $MYSQL_PASSWORD) -h $(echo $DB_HOST) $(echo $MYSQL_DATABASE)'
# Construct the directory path within the container to the sql dump
mysql_restore="< ${restore_dir}${sql_dump_name}.sql"
# Execute the sql restore from dump
docker exec $container_id bash -c "${mysql_conn} ${mysql_restore}"
#Remove any folders we made in the container and on the host running the script
echo "Cleaning up..."
docker exec $container_id rm -rf $restore_dir
rm -rf $unzip_dir
docker exec $container_id php /var/www/html/artisan up
exit
