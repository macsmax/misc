# Misc
Scripts and hopefully useful stuff

## Utilities

### Duplicity backup and restore script
This script is a wrapper around duplicity and aims at automating backups. It uses the [wernight/duplicity](https://hub.docker.com/r/wernight/duplicity/) docker container in interactive mode.

Requirements:

* Have a remote host to use with duplicity. eg. a synology server with rsync enabled.
* Setup ssh keys in a .ssh directory placed in the script directory base path 
* Configure the following variables inside the script:
```
SOURCE="" #Source Path
REMOTEHOST="" #Destination user and host eg. backup@myhost.com
REMOTEPATH="" #Remote destination
ENCPP="" #Random encryption password
```

Usage:
```
USAGE: ./backup.sh [backup|listtags|list|restore] [backup tag] [source|destination]

backup: perform a backup, the third argument is the backup source
listtags: list backup tags
list: list duplicity backups
restore: restore backuped up data, the second argument is the restore destination
```

Running the script in cron:
```
0 3 * * * /data01/maxinet/docker/maxibackup/backup.sh backup docker-data /data01/maxinet/docker-data >> /var/log/backup.log 2>&1
```

Restoring data:
```
./backup.sh restore mailu2 /data01/maxinet/mailu-restore/
```


### jira.pl jira cli
This perl script will allow you to query, comment, close and export Jira tickets.

Perl requirements:

JIRA::Client::Automated;
Class::CSV;
Term::ANSIColor;

How to use:
Create a .jira.rc in your home directory with the following information:
```
jiraurl = <your jira url>
juser = <username>
jpass = <password>
```

Help:
```
usage: jira.pl
        -u query tickets in open and in progress state for the comma separated list of users
        -C Close the given ticket (requires -m)
        -c output in csv format
        -m add a comment to the given ticket
        -j search ticket via JQL
        -t ticket number
        -v print ticket details and comments
        -d set debug on (default: off)
        -h Print This help message
```
