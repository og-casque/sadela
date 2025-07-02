#!/bin/bash

# Vérification des arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <REALM> <KDC_IP_OR_HOSTNAME>"
    exit 1
fi

REALM=$(echo "$1" | tr '[:lower:]' '[:upper:]')
KDC_IP="$2"

# Création du fichier /etc/krb5.conf
cat <<EOF > /etc/krb5.conf
[libdefaults]
    default_realm = $REALM
    dns_lookup_realm = false
    dns_lookup_kdc = false

[realms]
    $REALM = {
        kdc = $KDC_IP
        admin_server = $KDC_IP
    }

[domain_realm]
    .$REALM = $REALM
    $REALM = $REALM
EOF

echo "[+] Fichier /etc/krb5.conf généré pour le realm $REALM avec le KDC à $KDC_IP"
