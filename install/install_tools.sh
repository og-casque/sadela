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
        apt-get install -y "$tool" >> "$LOG_DIR/apt_install.log" 2>&1 || echo "[!] Failed to install $tool via apt"
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

apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /var/cache/apt/archives/*
apt-get update

echo "Installing metasploit"

# Télécharger le script d'installation
curl -s https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb -o msfinstall

# Installer Metasploit Framework
if [ -f msfinstall ]; then
    chmod +x msfinstall
    ./msfinstall
    rm msfinstall
else   
    echo "Failed installing metasploit"
fi

#cpan install Encoding::BER

echo "Installing jdk11"
wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public \
  | gpg --dearmor -o /usr/share/keyrings/adoptium.gpg
echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb bookworm main" \
  > /etc/apt/sources.list.d/adoptium.list
apt-get update
apt-get install -y temurin-11-jdk

echo "Installing neo4j"
wget -O - https://debian.neo4j.com/neotechnology.gpg.key | apt-key add -
echo 'deb https://debian.neo4j.com stable 4.4' | tee /etc/apt/sources.list.d/neo4j.list
apt-get update
apt-get install -y neo4j

echo "Setting up neo4j APOC for gpohound"
cp /var/lib/neo4j/labs/apoc-* /var/lib/neo4j/plugins/

# Installing rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

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

echo "Installing chameleon"
git clone --depth 1 https://github.com/klezVirus/chameleon.git /opt/chameleon
if [ ! -f /opt/chameleon/chameleon.py ]; then
    echo "Failed installing chameleon"
else
    /opt/tools-env/bin/pip install -r /opt/chameleon/requirements.txt
fi

echo "Installing routersploit"
git clone --depth 1 https://github.com/threat9/routersploit.git /opt/routersploit
if [ ! -f /opt/routersploit/rsf.py ]; then
    echo "Failed installing routersploit"
else
    /opt/tools-env/bin/pip install -r /opt/routersploit/requirements.txt
fi

echo "Installing ATEAM"
git clone --depth 1 https://github.com/NetSPI/ATEAM.git /opt/ATEAM
if [ ! -f /opt/ATEAM/ateam.py ]; then
    echo "Failed installing ATEAM"
else
    /opt/tools-env/bin/pip install -r /opt/ATEAM/requirements.txt
fi

echo "Installing NetworkHound"
git clone --depth 1 https://github.com/MorDavid/NetworkHound.git /opt/NetworkHound
if [ ! -f /opt/NetworkHound/NetworkHound.py ]; then
    echo "Failed installing NetworkHound"
else
    /opt/tools-env/bin/pip install -r /opt/NetworkHound/requirements.txt
fi

echo "Installing username_generator"
git clone --depth 1 https://github.com/shroudri/username_generator.git /opt/username_generator
if [ ! -f /opt/username_generator/username_generator.py ]; then
    echo "Failed installing username_generator !"
else
    chmod +x /opt/username_generator/username_generator.py
    ln -s /opt/username_generator/username_generator.py /usr/local/bin/username_generator
fi

echo "Installing ntlm_theft"
git clone --depth 1 https://github.com/Greenwolf/ntlm_theft.git /opt/ntlm_theft
if [ ! -f /opt/ntlm_theft/ntlm_theft.py ]; then
    echo "Failed installing ntlm_theft !"
fi

echo "Installing aced"
git clone --depth 1 https://github.com/garrettfoster13/aced.git /opt/aced
if [ ! -f /opt/aced/aced.py ]; then
    echo "Failed installing aced !"
else
    python3 -m venv /opt/aced/venv
    /opt/aced/venv/bin/pip install -r /opt/aced/requirements.txt
    /opt/aced/venv/bin/pip install setuptools
fi

echo "Installing sccmhunter"
git clone --depth 1 https://github.com/garrettfoster13/sccmhunter.git /opt/sccmhunter
if [ ! -f /opt/sccmhunter/sccmhunter.py ]; then
    echo "Failed installing sccmhunter !"
else
    python3 -m venv /opt/sccmhunter/venv
    /opt/sccmhunter/venv/bin/pip install -r /opt/sccmhunter/requirements.txt
fi

echo "Installing viewgen"
git clone --depth 1 https://github.com/0xacb/viewgen.git /opt/viewgen
if [ ! -f /opt/viewgen/viewgen ]; then
    echo "Failed installing viewgen !"
else
    python3 -m venv /opt/viewgen/venv
    /opt/viewgen/venv/bin/pip install -r /opt/viewgen/requirements.txt
fi

echo "Installing RelayKng"
git clone --depth 1 https://github.com/depthsecurity/RelayKing-Depth.git /opt/RelayKing-Depth
if [ ! -f /opt/RelayKing-Depth/relayking.py ]; then
    echo "Failed installing RelayKing !"
else
    python3 -m venv /opt/RelayKing-Depth/venv
    /opt/RelayKing-Depth/venv/bin/pip install -r /opt/RelayKing-Depth/requirements.txt
fi

echo "Installing searchsploit"
git clone --depth 1 https://gitlab.com/exploit-database/exploitdb.git /opt/exploitdb
if [ ! -f /opt/exploitdb/searchsploit ]; then
    echo "Failed installing searchsploit !"
else
    ln -sf /opt/exploitdb/searchsploit /usr/local/bin/searchsploit
fi

echo "Installing cmloot"
git clone --depth 1 https://github.com/shelltrail/cmloot.git /opt/cmloot
if [ ! -f /opt/cmloot/cmloot.py ]; then
    echo "Failed installing cmloot !"
else
    python3 -m venv /opt/cmloot/venv
    /opt/cmloot/venv/bin/pip install -r /opt/cmloot/requirements.txt
fi

echo "Installing keycred (and pfxtool)"
git clone --depth 1 https://github.com/RedTeamPentesting/keycred.git /opt/keycred
if [ ! -f /opt/keycred/LICENSE ]; then
    echo "Failed installing keycred !"
else
    go build -C /opt/keycred/cmd/keycred
    go build -C /opt/keycred/cmd/pfxtool
fi

echo "Installing pre2k"
git clone --depth 1 https://github.com/garrettfoster13/pre2k.git /opt/pre2k
if [ ! -f /opt/pre2k/poetry.lock ]; then
    echo "Failed installing pre2k !"
else
    poetry install --directory /opt/pre2k
fi

echo "Installing john the ripper (and its binaries), may take some time"
git clone --depth 1 https://github.com/openwall/john.git /opt/john
if [ ! -f /opt/john/src/configure ]; then
    echo "Failed installing john :/"
else
    cd /opt/john/src
    ./configure && make -s clean && make -sj8
    cd /
    ln -s /opt/john/run/*2john* /usr/local/bin/
fi

echo "Installing odat"
mkdir /opt/odat
curl -sSL https://github.com/quentinhardy/odat/releases/download/5.1.1/odat-linux-libc2.17-x86_64.tar.gz -o /opt/odat/odat.tar.gz
if [ ! -f /opt/odat/odat.tar.gz ]; then
    echo "Failed downloading odat"
else
    tar -xf /opt/odat/odat.tar.gz -C /opt/odat
    if [ ! -f /opt/odat/odat-libc2.17-x86_64/odat-libc2.17-x86_64 ]; then
        echo "Failed installing odat"
    fi
fi

echo "Installing klist2ccache"
git clone --depth 1 https://github.com/jakeotte/klist2ccache.git /opt/klist2ccache
if [ ! -f /opt/klist2ccache/requirements.txt ]; then
    echo "Failed installing klist2ccache"
else
    python3 -m venv /opt/klist2ccache/venv
    /opt/klist2ccache/venv/bin/pip install -r /opt/klist2ccache/requirements.txt
fi