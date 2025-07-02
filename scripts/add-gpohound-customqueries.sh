#!/bin/bash

if [ ! -f /root/.config/bloodhound/customqueries.json ]; then
    echo "You must first start bloodhound at least once"
else
    mv /root/.config/bloodhound/customqueries.json /root/.config/bloodhound/customqueries.json.backup
    cp /opt/customqueries.json /root/.config/bloodhound/customqueries.json
    echo "Custom queries added to bloodhound ! (made a backup of previous customqeries file in case it wasnt empty)"
fi