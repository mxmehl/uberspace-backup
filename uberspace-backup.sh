#!/bin/bash
########################################################################
#  Copyright (C) 2017 Max Mehl <mail [at] mehl [dot] mx>
########################################################################
#  
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#  
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

if [ ! -e "$HOSTS" ]; then echo "Missing hosts file. Please set a correct value of HOSTS= in your config file. Current value: $HOSTS"; exit 1; fi

# Get current date
DATE=$(date +"%Y-%m-%d_%H-%M")
LOG="$CURDIR"/backup.log

function trim {
  sed -r -e 's/^\s*//g' -e 's/\s*$//g'
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
  if $(echo "$line" | grep -qE "^\s*#"); then continue; fi

  RHOST=$(echo "$line" | cut -d";" -f1 | trim)
  RUSER=$(echo "$RHOST" | cut -d"@" -f1)
  ALLRDIR=$(echo "$line" | cut -d";" -f2 | trim)
  
  logecho "${RHOST}: Starting backups"
  
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
    rsync -az -e "ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" ${RHOST}:${SOURCE}/ "${DEST}"/
        
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
