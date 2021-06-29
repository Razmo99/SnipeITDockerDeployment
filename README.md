# Snipe-IT Docker Deployment
## Synopsis
Host multiple instances of Snipe-IT behind a nginx reverse proxy.

## Installation

Setup Your prefered Distro of Linux.\
_CentOS 7 was used when creating this deployment._

Install Docker, Docker-Composer. Include openssl & mod_ssl if you are making self signed certificates. 

_If you do use CentOS 7 its worth adding `setroubleshoot` & `setools` for easier digestion of SELinux logs._

Copy this repo into a directory on the Linux OS.

### Snipe-IT Instance Setup
#### Naming
Rename `my_assets` folder to a desired name IE `NSW-Service`\
_final domain name being `nsw-service.assets.contoso.local` or the like._

#### App Key
You need to generate an app key for your snipe-it instance. run the below command it should return an app key for you to use.

```shell
docker run --rm snipe/snipe-it
```
_You need a unique app key for each snipe-it instance you create._

#### Docker Network
A Docker network needs to be made for all the containers to use.
```shell
docker network create reverse_proxy
```
_You can chang the name but, it needs to be reflected in the compose files for the `nginx` proxy and `snipe-it app`_

General network Traffic flow is like below.\
user <--> nginx <--> Snipe-it --> MariaDB

#### Environment Variables
Edit the `.env` file and enter in your secrets and instance specific information. Such as your `APP_KEY`

#### SSL Certificates

Under the `certificates` folder edit `openssl_commands.txt` and change the details to match your deployment I.E change `my_assets.contoso.local.csr` to `nsw-service.assets.contoso.local.csr`. Modify the `csr_details.txt` & `extra_params.txt` to match your deployment aswell.

#### Starting an instance

`cd` into the instance's folder and run.

```shell
docker-compose up -d
```
#### Stopping an instance

`cd` into the instance's folder and run.

```shell
docker-compose stop
```

#### Remove an instance's containers

`cd` into the instance's folder and run.

```shell
docker-compose down
```

#### Remove an instance along with persistant storage

`cd` into the instance's folder and run.

```shell
docker-compose down --volumes --remove-orphans
```

### Nginx Setup

_The default config assumes you are using SSL for the reverse proxy._
#### SSL
Any certificates that will be references in the config will need to be placed under the `ssl` folder which is bound to `/etc/ssl` within the Nginx container. copy any `.keys` under `private` and any `.crt` under `certs`
#### Container Name
Each server block needs to point to the internal containers name. Use the below command to list all containers on the host.
```shell
docker ps
```

Copy the name of the desired container and update the below sections in the server block

```nginx
set $my_assets_server my_assets_snipeit_1;

proxy_pass http://$my_assets_server;
```


The Server block is what you would primarily edit/duplicate when modifying the config. Tweak the server block as needed.

~~~nginx
	server {
        # Ports to listen on
		listen 443 ssl;
        # DNS Address required for this server block to match
        # You can add multiple entries seperated by a space
		server_name my_assets.contoso.local;

		#Set a variable pointing to the name of the docker container to resolve.
		set $my_assets_server my_assets_snipeit_1;		

        # SSL Certificates to present to clients
        # Make these using the commands under certificates folder under my_assets
		ssl_certificate /etc/ssl/certs/my_assets.contoso.local.crt;
		ssl_certificate_key /etc/ssl/private/my_assets.contoso.local.key;

		location / {
			proxy_set_header HOST $host;
			proxy_set_header X-Forwarded-Proto $scheme;
			proxy_set_header X-Real-IP $remote_addr;
			proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            # This is the address to forward clients to
            # It should be the IP & Port of the Snipe-IT Instance.
            # You can find the port in the docker-compose.yml for the instance in question.
			proxy_pass http://$my_assets_server;
		}
	}	
~~~

### Cron Snipe Backups

Three bash scripts are used to create and maintain snipe backups within the containers. These scripts are triggered by cron jobs within the host OS.



Below is just an example that could be used for one Snipe-IT instance.

```c
# From Crontab.txt #
0 10 * * * bash /home/dockercaptain/snipe_backups_daily.sh snipeit_container_name # Backup 10am
0 14 * * * bash /home/dockercaptain/snipe_backups_daily.sh snipeit_container_name # Backup 10pm
0 0 1 * * bash /home/dockercaptain/snipe_backups_monthy.sh snipeit_container_name ...Path.../my_assets/backups/monthly/ # Backup monthly
0 0 1 1 * bash /home/dockercaptain/snipe_backups_yearly.sh snipeit_container_name ...Path.../my_assets/backups/yearly/ # Backup yearly

```
Daily backups are stored on persistant volumes on the docker containers older backups are copied onto the host.

The **daily backups** keep a default `MAX_BACKUPS` of `56`.
 * This will kick off a backup task when executed.

The **Monthly backups** keep a default `MAX_BACKUPS` of `12`.\
 * This Grabs the latest backup within the container and sticks it the the specified folder.

The **Yearly backups** keep a default `MAX_BACKUPS` of `100`.\
 * This Grabs the latest backup within the container and sticks it the the    specified folder.

_The above can all be adjusted to suit your environment. Snipe-IT's scheduler by default will run an auto backup weekly._

### Snipe-IT Backup Restore

`snipe_restore_backup.sh` can be used to restore a snipe-it instance from a backup.
```bash
bash snipe_restore_backup.sh container_name path/to_your_backup
```
#### What it does?
1. Unzips the backup in to a new directory.
2. Checks it can find all the required files in the  unzip directory
3. Sets the snipe-it app to maintenance mode
4. removes the contents of the uploads & private_uploads folder in the docker container
5. Makes a directory to store the SQL Dump within the docker container
6. Copies over the oauth keys, SQL Dump, uploads & private_uploads to the docker container
7. Restores the SQL Database
8. Cleansup any created directories
9. Bring the snipe-it app out of maintenance mode





