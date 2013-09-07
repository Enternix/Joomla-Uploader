#!/bin/bash
# You need to install these packages:
# sudo apt-get install curl mawk mysql-client sed unzip zip zipmerge
# You have to choose the same password for the remote database and the locale!

# Customize the next lines:
homepage='xxxxx.bplaced.net'
ftp_user='xxxxx'
ftp_server='ftp://xxxxx.bplaced.net'
local_root='/var/www/joomlaville/'
remote_root='joomlaville/'
mysql_username_remote='xxxxx'
mysql_database_remote='xxxxx'

################################################################################
################################################################################

# Get some more global values. Extract them from configuration.php.
function getValue {
    # $1: existing key

    value=$(sed -ne "s/^\s*public\s*\$$1\s*=\s*'\(.*\)'.*/\1/p" \
        $local_root/configuration.php)
    echo $value
}

mysql_host=$(getValue host)
mysql_username_local=$(getValue user)
mysql_database_local=$(getValue db)
password_mysql=$(getValue password)
# password_ftp= [do not edit: user-input]
backup_dir="$HOME/.webup"
zip_file="$backup_dir/${mysql_database_local}.zip"


# Write php-script into temporary file. The script can extract all entries of
# a zip-file on the server.
function createExtractionScript {
    # $1: Name of zip-file without path
    
    scriptFileName=$(mktemp "$backup_dir/extract_XXXXXXXX.php") || {
        return 1
    }
    echo "<?php
          \$root_path = getcwd();
          \$zip = new ZipArchive;
          if (\$zip->open('$1') === TRUE) {
              \$zip->extractTo(\$root_path);
              \$zip->close();
              echo 'ok';
          } else {
              echo 'failed';
          }
          ?>" > "$scriptFileName"
    echo "$scriptFileName"
}

# Created php-file should delete all tables from the remote database and
# executes all lines from the local database (mysqldump with 'compact'-option):
function createSqlScript {

    local sqlScript=$(basename $(mktemp "$backup_dir/sql_XXXXXXXX.php")) || {
        return 1
    }
    echo "<?php

    mysql_connect \
        (\"$mysql_host\", \"$mysql_username_remote\", \"$password_mysql\") \
        or die(mysql_error());
    mysql_select_db(\"$mysql_database_remote\") or die(mysql_error());
    mysql_set_charset('utf8');

    if (\$tables = mysql_query(\"SHOW TABLES\")) {
        while (\$row = mysql_fetch_row(\$tables)) {
            mysql_query(\"DROP TABLE \$row[0]\");
        }
    }
    else {
        die(mysql_error());
    }

    \$command = '';
    \$lines = file(\"$sqlBackup\");
    foreach (\$lines as \$line)
    {
        \$command .= \$line;
        if (substr(trim(\$line), -1, 1) == ';')
        {
            mysql_query(\$command) or print(mysql_error());
            \$command = '';
        }
    }
    ?>" > "$sqlScript"
    echo "$sqlScript"
}

function removeRemoteFile {
    # $1: filename

    curl --user "$ftp_user:$password_ftp" --silent --quote "DELE $1" \
        "$ftp_server" > /dev/null
}

function removeRemoteDirectory {
    # $1: name of directory
    
    curl --user "$ftp_user:$password_ftp" --silent --quote "RMD $1" \
        "$ftp_server" > /dev/null
}

# For curl we need '.' as decimal point
export LC_NUMERIC="en_US.UTF-8"

function uploadFile {
    # $1: name of local file with or without path (current directory)
    echo "Uploading $(basename $1)"
    
    curl --upload-file "$1" --ftp-create-dirs --user "$ftp_user:$password_ftp" \
        --keepalive-time 10 -# --write-out \
        "%{time_total}\n%{size_upload}\n%{speed_upload}" \
        "$ftp_server/$remote_root/" | {
            if [ $? != 0 ]; then
                echo "Uploading $1 failed"
                return 1
            fi
            
            # This stuff is for displaying upload-information after the upload
            read time_total
            local minutes=$(echo "$time_total" |\
                awk '{ printf "%i", int($1 / 60)}')
            local seconds=$(echo "$time_total" |\
                awk '{ printf "%.2f", $1 % 60}')
            time_total="${minutes}m${seconds}s"

            read size_upload
            size_upload=${size_upload%%.*}
            if [ $size_upload -lt 1024 ]; then
                size_upload="$size_upload Bytes"
            elif [ $size_upload -lt 1048576 ]; then
                size_upload=$(echo "$size_upload" |\
                    awk '{ printf "%.1f", $1 / 1024 }')
                size_upload="$size_upload kBytes"
            else
                size_upload=$(echo "$size_upload" |\
                    awk '{ printf "%.1f", $1 / 1048576}')
                size_upload="$size_upload MBytes" 
            fi

            read speed_upload 
            speed_upload=${speed_upload%%.*}
            if [ $speed_upload -lt 1024 ]; then
                speed_upload="$speed_upload Bytes/sec"
            elif [ $speed_upload -lt 1048576 ]; then
                speed_upload=$(echo "$speed_upload" |\
                    awk '{ printf "%.1f", $1 / 1024}')
                speed_upload="$speed_upload kBytes/sec"
            else
                speed_upload=$(echo "$speed_upload" |\
                    awk '{ printf "%.1f", $1 / 1048576}')
                speed_upload="$speed_upload MBytes/sec"
            fi

            echo
            echo "Uploaded: $size_upload, time: $time_total, average speed:"\
                "$speed_upload."
        }
}
    
function sendArchiveAndExtract {
    # $1: zip-file to extract
    
    # Send ZIP-file to remote server
    local zip_dir=$(dirname "$1")
    local zip_name=$(basename "$1")
    uploadFile "$1" || {
        return 1
    }
         
    # Write temoprary file (php-Script to extract zip) and send it to remote
    # server
    local FILE=$(createExtractionScript "$zip_name") || {
        removeRemoteFile "$remote_root/$zip_name"
        return 1
    }
    local script_dir=$(dirname "$FILE")
    local script_name=$(basename "$FILE")
    uploadFile "$FILE" || {
        removeRemoteFile "$remote_root/$zip_name"
        rm "$FILE"
        return 1
    }
    rm "$FILE"
    
    curl --silent "$homepage/$remote_root/$script_name" || {
        removeRemoteFile "$remote_root/$zip_name"
        removeRemoteFile "$remote_root/$script_name"
        return 1
    }
    removeRemoteFile "$remote_root/$zip_name"
    removeRemoteFile "$remote_root/$script_name"
    return 0
}

function createDirScript {
    local scriptFileName=$(mktemp "$backup_dir/dir_XXXXXXXX.php") || {
        return 1
    }

    echo "<?php
          echo getcwd();
          ?>" > "$scriptFileName"
    echo "$scriptFileName"
} 

function changeValue {
    # $1: existing key
    # $2: new value

    sed -i "s<^\(\s*public\s*\$$1\s*=\s*\).*$<\1\'$2\';<" \
        "$backup_dir/configuration.php"
}

function changeConfiguration {
    cp "$local_root/configuration.php" "$backup_dir"

    dirScript=$(basename $(createDirScript))
    cd "$backup_dir"
    echo "created $dirScript"
    uploadFile "$dirScript" || {
        echo "Could not upload $dirScript"
        rm "$dirScript"
        exit 1
    }
    mydir=$(curl --silent "$homepage/$remote_root/$dirScript") || {
        echo "Could not get directory with curl"
        rm "$dirScript"
        removeRemoteFile "$remote_root/$dirScript"
        exit 1
    }

    rm "$dirScript"
    removeRemoteFile "$remote_root/$dirScript"

    changeValue 'host' "$mysql_host"
    changeValue 'user' "$mysql_username_remote"
    changeValue 'password' "$password_mysql"
    changeValue 'db' "$mysql_database_remote"
    changeValue 'log_path' "$mydir/logs"
    changeValue 'tmp_path' "$mydir/tmp"

    uploadFile "$backup_dir/configuration.php" || {
        echo "Could not upload $backup_dir/configuration.php"
        exit 1
    }
}

################################################################################
################################################################################

read -s -p "Password of $ftp_user at $ftp_server: " password_ftp; echo

timeScriptStart="$(date +%Y_%m_%d_%H%M%S)"

# Check if connection is possible
echo "Try to login..."
curl --quote "NOOP" --user "$ftp_user:$password_ftp" --silent "$ftp_server" \
    > /dev/null || {
    echo "Login failed"
    exit 1
}
echo "OK."

if [ ! -d "$backup_dir" ]; then
    mkdir --parents "$backup_dir"
fi

# Upload the Database first:

## Get local sql-database
sqlBackup=$(basename $(mktemp "$backup_dir/sql_XXXXXXXX.sql"))
cd "$backup_dir"
echo "Try to extract database..."
mysqldump --opt --compact -u "$mysql_username_local" \
    --password="$password_mysql" "$mysql_database_local" > "$sqlBackup" || {
        echo "Could not extract database"
        exit 1
}
echo "OK."

echo "Try to write on remote database..."
sqlScript=$(basename $(createSqlScript)) || {
    echo "Could not create Script $sqlScript"
    exit 1
}

uploadFile "$sqlBackup" || {
    echo "Could not upload file $sqlBackup"
    rm "$sqlBackup"
    rm "$sqlScript"
    exit 1
}
uploadFile "$sqlScript" || {
    echo "Could not upload file $sqlScript"
    rm "$sqlBackup"
    rm "$sqlScript"
    removeRemoteFile "$remote_root/$sqlBackup"
    exit 1
}

curl --silent "$homepage/$remote_root/$sqlScript" || {
    echo "Could not execute $sqlScript"
    rm "$sqlBackup"
    rm "$sqlScript"
    removeRemoteFile "$remote_root/$sqlBackup"
    removeRemoteFile "$remote_root/$sqlScript"
    exit 1
}
echo "OK."

cp "$sqlBackup" "${mysql_database_local}_$timeScriptStart.sql"
removeRemoteFile "$remote_root/$sqlBackup"
removeRemoteFile "$remote_root/$sqlScript"
rm "$sqlBackup"
rm "$sqlScript"

################################################################################

# Upload directories and files

# If $zip_file not exists, create it. Otherwise, make a "difference"-zip
if [ ! -f "$zip_file" ]; then

    cd "$local_root"

    echo "First creation of $zip_file..."
    zip -r --quiet "$zip_file" . || {
        echo "Could not create $zip_file."
        exit 1
    }
    echo "OK."
    
    echo "Upload and Extract $zip_file on remote server..."
    sendArchiveAndExtract "$zip_file" || {
        echo "Could not send/extract $zip_file."
        rm "$zip_file"
        exit 1
    }

    changeConfiguration || {
        rm "$zip_file"
        exit 1
    }
    echo "OK."
else
    # Create zip-file from difference between $local_root and $zip_file
    cd "$local_root"

    echo "Looking for changed files..."
    difzip=$(mktemp "$backup_dir/diff_XXXXXXXX.zip")
    zip -r --quiet "$zip_file" . --difference-archive --out "$difzip" || {
        echo "Could not create $difzip."
        exit 1
    }
    
    if zipinfo "$difzip" > /dev/null; then
        sendArchiveAndExtract "$difzip" || {
            echo "Could not send/extract $difzip."
            exit 1
        }

        if zipinfo -1 "$difzip" | grep ^configuration.php$; then
            changeConfiguration || {
                echo "Could not upload configuration.php"
            }
        fi
        
        # Merge the two zip-files after making backup
        cp "$zip_file" "${zip_file%.*}_$timeScriptStart.zip"
        zipmerge "$zip_file" "$difzip"
    fi
    echo "OK."
    rm "$difzip"
    
    # Remove entries in $zip_file and files on server, which were deleted on 
    # $local_root
    diff_file=$(mktemp "$backup_dir/diff_XXXXXXXX")
    dirs_file=$(mktemp "$backup_dir/dirs_XXXXXXXX")

    cd "$local_root"
    echo "Remove remote files if deletet local..."
    zip -r --filesync "$zip_file" . > "$diff_file"
    while read CMD; do
        if [[ "$CMD" == "deleting: "* ]]; then
            del_line=${CMD:10}
            if [ ${CMD:(-1)} == '/' ]; then
                echo "$del_line" >> "$dirs_file"
            else
                removeRemoteFile "$remote_root/$del_line"
            fi
        fi
    done < "$diff_file"
    
    # Sort the file from long lines to short lines to remove empty dirs first
    awk '{ print length($0) " " $0; }' $dirs_file | sort -r -n | \
        cut -d ' ' -f 2- | while read CMD; do
            removeRemoteDirectory "$remote_root/$CMD"
    done
    echo "OK."
    rm "$diff_file"
    rm "$dirs_file"
fi
echo "Finished."
exit 0

