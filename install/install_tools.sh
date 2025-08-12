#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
LOG_DIR="/opt/install_logs"
mkdir -p "$LOG_DIR"

# Fonction pour installer via apt
install_apt() {
    local file="$1"
    cat "$file" | while read -r tool || [[ -n "$tool" ]]; do
        [[ -z "$tool" ]] && continue
        case "$tool" in \#*) continue ;; esac
        echo "[APT] Installing $tool"
        apt install -y "$tool" >> "$LOG_DIR/apt_install.log" 2>&1 || echo "[!] Failed to install $tool via apt"
    done
}


# Fonction pour installer via pipx
install_pipx() {
    local file="$1"
    cat "$file" | while read -r tool || [[ -n "$tool" ]]; do
        [[ -z "$tool" ]] && continue
        case "$tool" in \#*) continue ;; esac
	    echo "[PIPX] Installing $tool"
        pipx install "$tool" >> "$LOG_DIR/pipx_install.log" 2>&1 || echo "[!] Failed to install $tool via pipx"
    done
}

# Fonction pour installer via pip
install_pip() {
    local file="$1"
    cat "$file" | while read -r tool || [[ -n "$tool" ]]; do
        [[ -z "$tool" ]] && continue
        case "$tool" in \#*) continue ;; esac
	    echo "[PIP] Installing $tool"
        /opt/tools-env/bin/pip install "$tool" >> "$LOG_DIR/pip_install.log" 2>&1 || echo "[!] Failed to install $tool via pip"
    done
}

# Fonction pour installer via gem
install_gem() {
    local file="$1"
    cat "$file" | while read -r tool || [[ -n "$tool" ]]; do
        [[ -z "$tool" ]] && continue
        case "$tool" in \#*) continue ;; esac
	    echo "[GEM] Installing $tool"
        gem install "$tool" >> "$LOG_DIR/gem_install.log" 2>&1 || echo "[!] Failed to install $tool via gem"
    done
}

install_go() {
    local file="$1"
    cat "$file" | while read -r tool || [[ -n "$tool" ]]; do
        [[ -z "$tool" ]] && continue
        case "$tool" in \#*) continue ;; esac
	    echo "[GO] Installing $tool"
        go install "$tool" >> "$LOG_DIR/go_install.log" 2>&1 || echo "[!] Failed to install $tool via go"
    done
}

# Fonction pour installer via cargo
install_cargo() {
    local file="$1"
    cat "$file" | while read -r tool || [[ -n "$tool" ]]; do
        [[ -z "$tool" ]] && continue
        case "$tool" in \#*) continue ;; esac
        echo "[CARGO] Installing $tool"
        cargo install "$tool" >> "$LOG_DIR/cargo_install.log" 2>&1 || echo "[!] Failed to install $tool via cargo"
    done
}

apt clean
rm -rf /var/lib/apt/lists/*
rm -rf /var/cache/apt/archives/*
apt update

echo "Installing metasploit"

# Télécharger le script d'installation
curl -s https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb -o msfinstall

# Ajouter la clé GPG manuellement
curl -fsSL https://apt.metasploit.com/metasploit-framework.gpg.key | gpg --dearmor | tee /usr/share/keyrings/metasploit.gpg > /dev/null
# Créer le fichier de sources APT avec association de la clé
echo "deb [signed-by=/usr/share/keyrings/metasploit.gpg] https://downloads.metasploit.com/data/releases/metasploit-framework/apt lucid main" | tee /etc/apt/sources.list.d/metasploit-framework.list

# Mise à jour du cache APT
apt update

# Installer Metasploit Framework
if [ -f msfinstall ]; then
    chmod +x msfinstall
    ./msfinstall
    rm msfinstall
else   
    echo "Failed installing metasploit"
fi

echo "Installing jdk11"
echo "deb http://deb.debian.org/debian unstable main non-free contrib" >> /etc/apt/sources.list
echo "Package: *\nPin: release a=stable\nPin-Priority: 900\n\nPackage: *\nPin: release a=unstable\nPin-Priority: 50" >> /etc/apt/preferences
apt update 
apt install -y openjdk-11-jdk

echo "Installing neo4j"
wget -O - https://debian.neo4j.com/neotechnology.gpg.key | apt-key add -
echo 'deb https://debian.neo4j.com stable 4.4' | tee /etc/apt/sources.list.d/neo4j.list
apt update -y
apt install -y apt-transport-https
apt install -y neo4j

echo "Setting up neo4j APOC for gpohound"
cp /var/lib/neo4j/labs/apoc-* /var/lib/neo4j/plugins/

# installation des paquets via apt
if [ -f /opt/apt.txt ]; then
    install_apt /opt/apt.txt
else
    echo "[!] /opt/apt.txt not found"
fi

# installation des paquets via pipx
if [ -f /opt/pipx.txt ]; then
    install_pipx /opt/pipx.txt
else
    echo "[!] /opt/pipx.txt not found"
fi

echo "Installing pwncat with python 3.11.9"
pipx install pwncat-cs --python /root/.pyenv/versions/3.11.9/bin/python

echo "Setting default password to 'casque' for gpohound"
cp -f /opt/neo4j.yaml /root/.local/share/pipx/venvs/gpohound/lib/python3.12/site-packages/config/neo4j.yaml

echo "Getting customqueries.json for gpohound"
curl -sSL https://raw.githubusercontent.com/cogiceo/GPOHound/refs/heads/main/customqueries.json -o /opt/customqueries.json
if [ ! -f /opt/customqueries.json ]; then
    echo "Failed getting customqueries.json"
fi

#installation de dépendances globales avec pip pour certains binaires *2john
pip install asn1crypto

#création du venv pour les install via pip
echo "Creating venv for pip in /opt/tools-env"
python3 -m venv /opt/tools-env
/opt/tools-env/bin/pip install --upgrade pip

# installation des paquets via pip
if [ -f /opt/pip.txt ]; then
    install_pip /opt/pip.txt
else
    echo "[!] /opt/pip.txt not found"
fi

# it's not pretty but i'm forced to do this since impacket is broken (unsuported hash type MD4)
# pip install pycryptodome
# removing it for now since modifying openssl.conf seems to work

# installation des paquets via gem
if [ -f /opt/gem.txt ]; then
    install_gem /opt/gem.txt
else
    echo "[!] /opt/gem.txt not found"
fi

# installation des paquets via go
if [ -f /opt/go.txt ]; then
    install_go /opt/go.txt
else
    echo "[!] /opt/go.txt not found"
fi

# installation des paquets via cargo
if [ -f /opt/cargo.txt ]; then
    install_cargo /opt/cargo.txt
else
    echo "[!] /opt/cargo.txt not found"
fi

echo "Installing bloodhound legacy"
curl -sSL https://github.com/SpecterOps/BloodHound-Legacy/releases/download/v4.3.1/BloodHound-linux-x64.zip -o BloodHound-linux-x64.zip
mkdir /opt/bloodhound
if [ -f BloodHound-linux-x64.zip ]; then
    unzip BloodHound-linux-x64.zip -d /opt/bloodhound > /dev/null
    rm BloodHound-linux-x64.zip
    if [ -f /opt/bloodhound/BloodHound-linux-x64/BloodHound ]; then
        ln -s /opt/bloodhound/BloodHound-linux-x64/BloodHound /usr/local/bin/bloodhound
    else
        echo "Failed to unzip bloodhound ?"
    fi
else   
    echo "Failed installing bloodhound legacy"
fi

echo "Installing sqlmap"
git clone --depth 1 https://github.com/sqlmapproject/sqlmap.git /opt/sqlmap
if [ -f /opt/sqlmap/sqlmap.py ]; then
    ln -s /opt/sqlmap/sqlmap.py /usr/local/bin/sqlmap
else
    echo "Failed installing sqlmap"
fi

echo "Installing dnschef"
git clone --depth 1 https://github.com/iphelix/dnschef.git /opt/dnschef
if [ ! -f /opt/dnschef/dnschef.py ]; then
    echo "Failed installing dnschef"
fi

echo "Installing responder"
git clone --depth 1 https://github.com/lgandx/Responder.git /opt/responder
if [ ! -f /opt/responder/Responder.py ]; then
    echo "Failed installing responder"
fi

echo "Installing commix"
git clone --depth 1 https://github.com/commixproject/commix.git /opt/commix
if [ -f /opt/commix/commix.py ]; then
    ln -s /opt/commix/commix.py /usr/local/bin/commix 
else
    echo "Failed installing commix"
fi

echo "Installing gpp-decrypt"
git clone --depth 1 https://github.com/t0thkr1s/gpp-decrypt.git /opt/gpp-decrypt
if [ ! -f /opt/gpp-decrypt/gpp-decrypt.py ]; then
    echo "Failed installing gpp-decrypt"
fi

echo "Installing enum4linux"
git clone --depth 1 https://github.com/CiscoCXSecurity/enum4linux.git /opt/enum4linux    
if [ -f /opt/enum4linux/enum4linux.pl ]; then
    ln -s /opt/enum4linux/enum4linux.pl /usr/local/bin/enum4linux
else
    echo "Failed installing enum4linux"
fi

echo "Installing enum4linux-ng"
git clone --depth 1 https://github.com/cddmp/enum4linux-ng.git /opt/enum4linux-ng
if [ ! -f /opt/enum4linux-ng/enum4linux-ng.py ]; then
    echo "Failed installing enum4linux-ng"
fi

echo "Installing krbrelayx"
git clone --depth 1 https://github.com/dirkjanm/krbrelayx.git /opt/krbrelayx
if [ ! -f /opt/krbrelayx/addspn.py ]; then
    echo "Failed installing krbrelayx"
fi

echo "Installing ghostspn"
git clone --depth 1 https://github.com/p0dalirius/GhostSPN.git /opt/ghostspn
if [ ! -f /opt/ghostspn/GhostSPN.py ]; then
    echo "Failed installing ghostspn"
fi

echo "Installing noPac.py"
git clone --depth 1 https://github.com/Ridter/noPac.git /opt/noPac
if [ ! -f /opt/noPac/noPac.py ]; then
    echo "Failed installing noPac.py"
fi

echo "Installing pyLAPS.py"
git clone --depth 1 https://github.com/p0dalirius/pyLAPS.git /opt/pyLAPS
if [ ! -f /opt/pyLAPS/pyLAPS.py ]; then
    echo "Failed installing pyLAPS.py"
fi

echo "Installing pyGPOAbuse"
git clone https://github.com/Hackndo/pyGPOAbuse.git /opt/pyGPOAbuse
if [ ! -f /opt/pyGPOAbuse/pygpoabuse.py ]; then
    echo "Failed installing pyGPOAbuse"
fi

echo "Getting targetedKerberoast.py"
git clone --depth 1 https://github.com/ShutdownRepo/targetedKerberoast.git /opt/targetedKerberoast
if [ ! -f /opt/targetedKerberoast/targetedKerberoast.py ]; then
    echo "Failed installing targetedKerberoast.py"
fi

echo "Getting gMSADumper.py"
git clone --depth 1 https://github.com/micahvandeusen/gMSADumper.git /opt/gMSADumper
if [ ! -f /opt/gMSADumper/gMSADumper.py ]; then
    echo "Failed installing gMSADumper.py"
fi

echo "Getting timeroast.py"
git clone --depth 1 https://github.com/SecuraBV/Timeroast.git /opt/timeroast
if [ ! -f /opt/timeroast/timeroast.py ]; then
    echo "Failed installing timeroast.py"
fi

echo "Installing nikto"
git clone --depth 1 https://github.com/sullo/nikto.git /opt/nikto
if [ ! -f /opt/nikto/program/nikto.pl ]; then
    echo "Failed installing nikto"
else
    ln -s /opt/nikto/program/nikto.pl /usr/local/bin/nikto
fi

echo "Installing jwt_tool"
git clone --depth 1 https://github.com/ticarpi/jwt_tool.git /opt/jwt_tool
if [ ! -f /opt/jwt_tool/jwt_tool.py ]; then
    echo "Failed installing jwt_tool"
else
    /opt/tools-env/bin/pip install -r /opt/jwt_tool/requirements.txt
fi

echo "Installing username_generator"
git clone --depth 1 https://github.com/shroudri/username_generator.git /opt/username_generator
if [ ! -f /opt/username_generator/username_generator.py ]; then
    echo "Failed installing username_generator !"
else
    chmod +x /opt/username_generator/username_generator.py
    ln -s /opt/username_generator/username_generator.py /usr/local/bin/username_generator
fi

echo "Installing john the ripper (and its binaries), may take some time"
git clone --depth 1 https://github.com/openwall/john.git /opt/john
if [ ! f /opt/john/src/configure ]; then
    echo "Failed installing john :/"
else
    cd /opt/john/src
    ./configure && make -s clean && make -sj8
    cd /
    ln -s /opt/john/run/*2john* /usr/local/bin/
fi
