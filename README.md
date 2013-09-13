# Joomla Uploader

WARNING: Don't use the script. It is only a test. It works for me, but I think the script is not well written. Helps are welcome!

```shell
~$ joomla-uploader
Password of Michael at ftp://michael.bplaced.net: 
Try to login...
OK.
Try to extract database...
OK.
Try to write to remote database...
Uploading sql_suoE8Dap.sql
######################################################################## 100.0%
######################################################################## 100.0%
Uploaded: 233.5 kBytes, time: 0m1.38s, average speed: 169.8 kBytes/sec.
Uploading sql_R8TKB1Yp.php
######################################################################## 100.0%
######################################################################## 100.0%
Uploaded: 681 Bytes, time: 0m0.53s, average speed: 1.3 kBytes/sec.
OK.
Looking for changed files...
OK.
Eventually remove remote files if missing in local folder...
OK.
Finished.
```

*joomla-uploader.sh* should upload the whole local Joomla!-installation, including the MySQL-database, to the remote server via FTP, without using SSH (my webhoster do not provide SSH...). To save time, the files are packaged into a ZIP-file and will be extracted on the remote server using a PHP-script. If you run the script for the first time, the whole Joomla!-installation will be uploaded. Subsequent calls will only upload the changes since last call. Therefore, the script is only useful, if you will edit your website from **one** computer. And you cannot use the Joomla!-backend of the remote server, because the database will be overwritten, the next time *joomla-uploader.sh* is used.

## Why Joomla Uploader

*joomla-uploader* could be useful for static "one-person"-websites: One person has a website as a local joomla-installation. He wants to upload the installation to a remote server. And when changing the local website, the remote server should be updated, without long synchronizing operations. But this means, that the website will be static: visitors could publish comments, but after running *joomla-uploader* all comments will be lost, because the database will be completely removed and substituded by the local database. 

## How to use

* *joomla-uploader.sh* is a bash-script for linux.

* Dependencies:

    * curl
    * mawk
    * mysql-client
    * sed
    * unzip
    * zip
    * zipmerge

* You have to choose the same password for both the remote and the local database!

* You have to edit the first lines of *joomla-uploader.sh*:

    * homepage: Your homepage-address without subdirectories.

    * ftp_user: Your username, which you are using for FTP-access.

    * ftp_server: The address of your FTP-server including *ftp://* .

    * local_root: The place of your local Joomla!-installation (usually */var/www/* ).

    * remote_root: The subdirectory on your homepage for your Joomla!-website (usually */* ).

    * mysql_username_remote: Your username, to access the database on the remote server.

    * mysql_database_remote: The name of your database on the remote server.
