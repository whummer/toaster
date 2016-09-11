#!/bin/bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
USER=$(whoami)

sudo chown -R $USER:$USER $DIR
#sudo find $DIR -type d -print0 | xargs -0 -n 100 chmod 755
#sudo find $DIR -type f ! -path "$DIR/restore-permissions.sh" -print0 | xargs -0 -n 100 chmod 644