#!/command/with-contenv /bin/bash

# Default runtime variables if none supplied
MINETESTSERVER_ARGS=${MINETESTSERVER_ARGS:='--gameid devtest'}

/usr/local/share/minetest/bin/minetestserver $MINETESTSERVER_ARGS
