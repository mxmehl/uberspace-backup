# Uberspace Backup

This Bash script is able to backup directories from Uberspace users (and also other SSH resources). For Uberspace hosts it can also backup MySQL databases by copying the backups Uberspace cleverly created for you.

It is designed to work automatically on another server with enough harddisk space.

## Features

- Transfers files securely via rsync over SSH.
- Encrypts backups with GnuPG, using a public key only. Once a backup is encrypted it can only be decrypted with a private key. Make sure to delete the private key from the backupping server (after saving it on a more secure space of course) to keep your backups even safer.
- If desired, it can delete older backups and only retain a configurable amount of backups.
- Rather verbose logs will be written to backup.log.
- With the helper script `ssh-checker.sh` one can automatically test whether the hosts provided in the hosts file can be accessed. If not, the little helper is trying to put your public SSH key to the remote hosts' authorized_keys files by letting you type in the password manually once.

## Configuration

Configuration happens in two files: config.cfg and hosts.csv.

### config.cfg

Everything should be self-explanatory with the comments. Make sure to use the correct GPG fingerprint, and make sure to have its public key imported by the user executing the script. No private key has to be installed on the backupping system (but on the decrypting one of course).

### hosts.csv

This file contains the hosts and its directories that shall be saved. It consists of two rows separated by `;`. The first one contains a `username@hostname` combination that will be used to sync files via SSH, and also as the backup destination directory name. 

The latter one contains all source directories that shall be transferred. This can be absolute file paths, or – if it's a Uberspace host – some special shortcuts:

- `%virtual` backups the virtual folder of your uberspace host (`/var/www/virtual/username/`) where for example the `html` folder is located in.
- `%mysql` downloads the latest backup of your MySQL databases that have been created by Uberspace themselves (their backup system is quite sophisticated).
- `%mails` downloads the directory `users` in the home directory which contains all email files of virtual mail users.
- `%home` simply downloads the whole user's home directory. 

You can give multiple locations that shall be backed up. Just separate them by `|` characters. See the example file for more. 

## Automatic runs

In order to let the script run regularily, simply put the script's absolute path in a cron file. For example, run `crontab -e` and insert at the bottom:

```
10 3 * * * /home/archiver/uberspace-backup/uberspace-backup.sh
```

This will run the backups every night at 3:10.

## Known limitations

- Please note that paths like `~` or `$HOME` haven't been tested yet. Use absolute paths instead.
- At the moment, the backups don't follow symbolic links. That's why for example error logs aren't downloaded when using `%virtual`. Make sure to regularily check your backups to make sure all important files are saved.
