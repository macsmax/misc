#!/bin/bash
# Config
SOURCE="" #Source Path
REMOTEHOST="" #Destination user and host eg. backup@myhost.com
REMOTEPATH="" #Remote destination
ENCPP="" #Random encryption password
REMOTEPROTO="rsync://" #Default duplicity protocol
# End Config


PIDFILE=/var/run/backup.pid
ARGS=1
BAD_ARGS=65
REMOTEDEST=${REMOTEPROTO}${REMOTEHOST}/${REMOTEPATH}
SCWD=$( dirname ${BASH_SOURCE[0]} )

if [ $# -lt "$ARGS" ]
then
  echo "USAGE: ./`basename $0` [backup|listtags|list|restore] [backup tag] [source|destination]"
  echo ""
  echo "backup: perform a backup, the third argument is the backup source"
  echo "listtags: list backup tags"
  echo "list: list duplicity backups"
  echo "restore: restore backuped up data, the second argument is the restore destination"
  exit $BAD_ARGS
fi
ACTION=$1
TAG=$2
[[ -z "$3" ]] && SRCDST=$SOURCE || SRCDST=$3

if [ "$ACTION" = "backup" ]; then
  if [ -f $PIDFILE ]; then
    echo "$(date): backup already running, remove pid file to rerun"
    exit
  else
    touch $PIDFILE;
    #Check that the target tag directory is there
    docker run --rm --user root \
    	-v $SCWD/.ssh:/.ssh:ro \
    	-v $SCWD/.ssh/known_hosts:/etc/ssh/ssh_known_hosts:ro \
    	wernight/duplicity \
    	ssh -i /.ssh/id_rsa \
    	${REMOTEHOST} "test -d ${REMOTEPATH}${TAG}/ || mkdir -p ${REMOTEPATH}${TAG}/"

    docker run --rm --user root \
        -e PASSPHRASE=$ENCPP \
        -v $SCWD/.cache:/home/duplicity/.cache/duplicity \
        -v $SCWD/.gnupg:/home/duplicity/.gnupg \
        -v $SCWD/.ssh:/.ssh:ro \
        -v $SCWD/.ssh/known_hosts:/etc/ssh/ssh_known_hosts:ro \
        -v $SRCDST:/data:ro \
        wernight/duplicity \
        duplicity --full-if-older-than=6M --allow-source-mismatch \
        --rsync-options='-e "ssh -i /.ssh/id_rsa"' \
        /data ${REMOTEDEST}${TAG}/

    if [ $? -ne 0 ]; then
    	echo "FAILED Daily backup of ${HOSTNAME} - ${NOW}"
    else
    	echo "Completed Daily backup of ${HOSTNAME} - ${NOW}"
    fi
    rm $PIDFILE;
  fi
fi

if [ "$ACTION" = "restore" ]; then
  echo "You are attempting to restore ${REMOTEDEST}${TAG}/ to $SRCDST, is that correct? y|n [n]"
  read Keypress
  case "$Keypress" in
    y | Y )
      :
    ;;
    * | n | N )
      echo "aborted..."
      exit 1;
    ;;
  esac
  if [ -f $PIDFILE ]; then
    echo "$(date): backup already running, remove pid file to rerun"
    exit
  else
    touch $PIDFILE;
    docker run --rm --user root \
        -e PASSPHRASE=$ENCPP \
        -v $SCWD/.cache:/home/duplicity/.cache/duplicity \
        -v $SCWD/.gnupg:/home/duplicity/.gnupg \
        -v $SCWD/.ssh:/.ssh:ro \
        -v $SCWD/.ssh/known_hosts:/etc/ssh/ssh_known_hosts:ro \
        -v $SRCDST:/data \
        wernight/duplicity \
        duplicity -v 3 restore \
        --rsync-options='-e "ssh -i /.ssh/id_rsa"' \
	${REMOTEDEST}${TAG}/ /data/

    if [ $? -ne 0 ]; then
    	echo "FAILED restore of ${HOSTNAME} - ${NOW}"
    else
    	echo "Completed restore of ${HOSTNAME} - ${NOW}"
    fi
    rm $PIDFILE;
  fi
fi
if [ "$ACTION" = "list" ]; then
    docker run --rm --user root \
        -e PASSPHRASE=$ENCPP \
        -v $SCWD/.cache:/home/duplicity/.cache/duplicity \
        -v $SCWD/.gnupg:/home/duplicity/.gnupg \
        -v $SCWD/.ssh:/.ssh:ro \
        -v $SCWD/.ssh/known_hosts:/etc/ssh/ssh_known_hosts:ro \
        -v $SOURCE:/data:ro \
        wernight/duplicity \
        duplicity list-current-files \
        --rsync-options='-e "ssh -i /.ssh/id_rsa"' \
        ${REMOTEDEST}${TAG}/
fi

if [ "$ACTION" = "listtags" ]; then
    docker run --rm --user root \
        -e PASSPHRASE=$ENCPP \
        -v $SCWD/.ssh:/.ssh:ro \
        -v $SCWD/.ssh/known_hosts:/etc/ssh/ssh_known_hosts:ro \
        wernight/duplicity \
        ssh -i /.ssh/id_rsa \
        ${REMOTEHOST} ls -a ${REMOTEPATH} | egrep -v -e '^\.'
fi
