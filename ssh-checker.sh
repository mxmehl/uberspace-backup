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
#  Reads hosts file and checks SSH access. If not possible with public 
#  key, this script tries to place the system's public key on the host 
#  via a normal (password-based) SSH access attempt. 
#  
########################################################################

CURDIR=$(dirname "$(readlink -f "$0")")
if [ ! -e "$CURDIR"/config.cfg ]; then echo "Missing config.cfg file. Edit and rename config.cfg.sample"; exit 1; fi
source "$CURDIR"/config.cfg

if [ ! -e "$HOSTS" ]; then echo "Missing hosts file. Please set a correct value of HOSTS= in your config file. Current value: $HOSTS"; exit 1; fi

ARG1="$1"

function trim {
  sed -r -e 's/^\s*//g' -e 's/\s*$//g'
}

while read line; do
  # if line is a comment, go to next line
  if $(echo "$line" | grep -qE "^\s*#"); then continue; fi

  RHOST=$(echo "$line" | cut -d";" -f1 | trim)

  if [[ "${ARG1}" != "" ]] && [[ "${ARG1}" != "${RHOST}" ]]; then
    continue
  fi
  
  echo "[INFO] Trying ${RHOST}"
  
  STATUS=$(ssh -n -o BatchMode=yes -o ConnectTimeout=5 ${RHOST} "echo -n"; echo $?)

  if [ $STATUS != 0 ]; then
    echo -n "[ERROR] No SSH login possible for ${RHOST}. "
    if [[ "${ARG1}" != "" ]]; then
      echo "Aborting."
      exit 1
    else
      echo "Adding public key with password: "
      cat ~/.ssh/id_rsa.pub | ssh ${RHOST} 'cat >> ~/.ssh/authorized_keys'
    fi
  else
    echo "[SUCCESS] SSH login possible for ${RHOST}."
  fi
  
  echo

done < "$HOSTS"
