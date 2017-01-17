#!/bin/bash

CURDIR=$(dirname "$(readlink -f "$0")")
if [ ! -e "$CURDIR"/config.cfg ]; then echo "Missing config.cfg file. Edit and rename config.cfg.sample"; exit 1; fi
source "$CURDIR"/config.cfg

if [ ! -e "$HOSTS" ]; then echo "Missing hosts file. Please set a correct value of HOSTS= in your config file. Current value: $HOSTS"; exit 1; fi

# Get current date
DATE=$(date +"%Y-%m-%d_%H-%M")

function trim {
  sed -r -e 's/^\s*//g' -e 's/\s*$//g'
}

while read line; do
  if $(echo "$line" | grep -qE "^\s*#"); then continue; fi

  RHOST=$(echo "$line" | cut -d";" -f1 | trim)
  RUSER=$(echo "$RHOST" | cut -d"@" -f1)
  ALLRDIR=$(echo "$line" | cut -d";" -f2 | trim)
  
  NORDIR=$(echo $ALLRDIR | grep -o "|" | wc -l)
  NORDIR=$[$NORDIR + 1]
    
  for ((i = 1; i <= $NORDIR; i++)); do
    RDIR=$(echo "$ALLRDIR" | cut -d"|" -f${i} | trim)
    
    if [ "${RDIR}" == "%virtual" ]; then
      RDIR=/var/www/virtual/${RUSER}
      DEST="$BACKUPDIR/$RHOST/$DATE/virtual"
    elif [ "${RDIR}" == "%mysql" ]; then
      RDIR=mysql
      DEST="$BACKUPDIR/$RHOST/$DATE/$(basename "${RDIR}")"
    elif [ "${RDIR}" == "%mails" ]; then
      RDIR=/home/${RUSER}/users
      DEST="$BACKUPDIR/$RHOST/$DATE/mails"
    else
      DEST="$BACKUPDIR/$RHOST/$DATE/$(basename "${RDIR}")"
    fi
    
    # Set Source directory, and make exception for %mysql
    SOURCE="${RDIR}"
    if [ "${RDIR}" == "mysql" ]; then SOURCE=/mysqlbackup/latest/${RUSER}; fi
        
    # Create backup destination if necessary
    if [ ! -e "${DEST}" ]; then mkdir -p "${DEST}"; fi
    
    # RSYNC
    echo rsync -avz -e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" --progress ${RHOST}:${SOURCE}/ "${DEST}"/
        
    # Pack backup directory, and delete uncompressed one
    tar cf ${DEST}.tar ${DEST}   # TODO: avoid absolute paths
    rm -rf ${DEST}
    
    # Encrypt archive with GPG (it compresses at the same time)
    gpg --output ${DEST}.tar.gpg --encrypt --recipient ${GPG} ${DEST}.tar
    rm ${DEST}.tar
    
    # Delete all old directories except the $MAXBAK most recent
    MAXBAK=$[$MAXBAK + 1]
    ls -tpd "${BACKUPDIR}"/"${RHOST}"/* | grep '/$' | tail -n +$MAXBAK | xargs -d '\n' rm -rv --
  done

done < "$HOSTS"
