#!/bin/zsh
# Recharge l'historique
fc -R /root/.zsh_history

neo4j start > /tmp/neo4j_start.logs

if [ ! -f /opt/change_neo4j_pw.exp ]; then
    echo "[*] Started neo4j, you might have to wait a bit for it to be accessible"
else
    echo "[*] First time runing the container, waiting for neo4j to be accessible to set the password..."
    until curl -s http://localhost:7474 >/dev/null 2>&1; do
        sleep 1
    done

    echo "[+] Setting Neo4j password to 'casque'..."
    expect /opt/change_neo4j_pw.exp > /dev/null
    rm /opt/change_neo4j_pw.exp
fi

exec zsh

