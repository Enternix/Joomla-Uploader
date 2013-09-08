# Joomla Uploader

WARNING: Don't use the script. It is only a test. It works for me, but I think the script is not well written. Helps are welcome!

*joomla-uploader.sh* should upload the whole locale Joomla!-installation including the MySQL-database to the remote server via FTP (I have no SSH...). To save time, the files are packaged into a ZIP-file and will be extracted on the remote server using a PHP-script. The script should upload the whole Joomla!-installation only the first time. After this, only the changes will be send. Therefore, the script is only useful, if you will edit your website from **one** computer. And you cannot use the Joomla!-backend of the remote server, because the database will be overwritten, the next time *joomla-uploader.sh* is used.

## Why Joomla Uploader

*joomla-uploader* could be useful for static "one-person"-websites: One person has a website as a local joomla-installation. He wants to upload the installation to a remote server. And when changing the local website, the remote server should be updated, without long synchronizing operations. But this means, that the website will be static: visitors could publish comments, but after running *joomla-uploader* all comments will be lost, because the database will be completely removed and substituded by the local database. 
