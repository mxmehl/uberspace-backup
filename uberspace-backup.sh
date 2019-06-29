#!/usr/bin/env bash
#  SPDX-Copyright: 2019 Max Mehl <mail [at] mehl [dot] mx>
#  SPDX-License-Identifier: GPL-3.0-or-later
########################################################################
#  
#  Saves specific files and directories from a remote server via SSH. 
#  Provides easy shortcuts for Uberspace.de hosts.
#  README.md provides more details.
#  
########################################################################

CURDIR=$(dirname "$(readlink -f "$0")")
if [ ! -e "$CURDIR"/config.cfg ]; then echo "Missing config.cfg file. Edit and rename config.cfg.sample"; exit 1; fi
source "$CURDIR"/config.cfg

if [ ! -e "${HOSTS}" ]; then echo "Missing hosts file. Please set a correct value of HOSTS= in your config file. Current value: ${HOSTS}"; exit 1; fi

if [ ! -z "${SSH_KEY}" ]; then
  SSH_KEY_ARG="-i ${SSH_KEY}"
else
  # defaults
  SSH_KEY_ARG=""
  SSH_KEY=~/.ssh/id_rsa
fi

# Get current date
DATE=$(date +"%Y-%m-%d_%H-%M")
LOG="$CURDIR"/backup.log

function trim {
  sed -r -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'
}
function pdate {
  DATE=$(date +%y-%m-%d_%H:%M:%S)
  echo "[$DATE]"
}
function logecho {
  # Echo string and copy it to log while attaching the current date
  echo "$(pdate) $@"
  echo "$(pdate) $@" >> "$LOG"
}

while read line; do
  # if line is a comment, go to next line
  if $(echo "$line" | grep -qE "^\s*#"); then continue; fi

  RHOST=$(echo "$line" | cut -d";" -f1 | trim)
  RUSER=$(echo "$RHOST" | cut -d"@" -f1)
  ALLRDIR=$(echo "$line" | cut -d";" -f2 | trim)
  
  logecho "${RHOST}: Starting backups"

  if ! "${CURDIR}"/ssh-checker.sh "${RHOST}"; then
    logecho "${RHOST}: ERROR when connecting via SSH. Please run ssh-checker.sh to debug."
    logecho "${RHOST}: Aborting backup after an error."
    continue
  fi
  
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
    elif [ "${RDIR}" == "%home" ]; then
      RDIR=/home/${RUSER}
      DEST="$BACKUPDIR/$RHOST/$DATE/home"
    else
      DEST="$BACKUPDIR/$RHOST/$DATE/$(basename "${RDIR}")"
    fi
    
    # Set Source directory, and make exception for %mysql
    SOURCE="${RDIR}"
    if [ "${RDIR}" == "mysql" ]; then SOURCE=/mysqlbackup/latest/${RUSER}; fi
    
    # Create backup destination if necessary
    if [ ! -e "${DEST}" ]; then mkdir -p "${DEST}"; fi
    
    # RSYNC
    logecho "${RHOST}: Downloading ${SOURCE} to ${DEST}"
    rsync -a -e "ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o Compression=no -T -x ${SSH_KEY_ARG}" ${RHOST}:${SOURCE}/ "${DEST}"/
        
    # Pack backup directory, and delete uncompressed one
    logecho "${RHOST}: Archiving $(basename ${DEST})"
    tar cf ${DEST}.tar -C $(echo ${DEST} | sed "s|$(basename ${DEST})$||") $(basename ${DEST}) # TODO: avoid absolute paths
    rm -rf ${DEST}
    
    # Encrypt archive with GPG (it compresses at the same time)
    logecho "${RHOST}: Encrypting and compressing $(basename ${DEST})"
    gpg --output ${DEST}.tar.gpg --encrypt --recipient ${GPG} ${DEST}.tar
    rm ${DEST}.tar
    
    # Delete all old directories except the $MAXBAK most recent
    if [ $(ls -tp "${BACKUPDIR}"/"${RHOST}"/ | grep '/$' | wc -l) -gt $MAXBAK ]; then
      logecho "${RHOST}: Removing older backups of $(basename ${DEST})"
      ls -tpd "${BACKUPDIR}"/"${RHOST}"/* | grep '/$' | tail -n +$[$MAXBAK + 1] | xargs -d '\n' rm -r --
    fi
  done

done < "$HOSTS"

logecho "Finished all operations."
