#!/bin/bash

set -euo pipefail

download() {
  local url="$1"
  local dest="$2"
  echo "Downloading ${dest##*/}..."
  curl -sSL "$url" -o "$dest" || echo "❌ Failed to download $url"
  [ -f "$dest" ] || echo "⚠️  ${dest##*/} missing!"
}

mkdir -p /privilege_escalation/linux /privilege_escalation/windows /wordlists/rules /wordlists/passwords /wordlists/web /wordlists/others /seclists /code-analysis

echo "Getting code analysis ressources..."
git clone --depth 1 https://github.com/semgrep/semgrep-rules.git /code-analysis/semgrep-rules

echo "Getting privilege_escalation ressources..."
# linpeas
for variant in linpeas.sh linpeas_small.sh linpeas_fat.sh; do
  download "https://github.com/peass-ng/PEASS-ng/releases/latest/download/${variant}" "/privilege_escalation/linux/${variant}"
done

# LES
download https://raw.githubusercontent.com/mzet-/linux-exploit-suggester/master/linux-exploit-suggester.sh /privilege_escalation/linux/linux-exploit-suggester.sh

# pspy
for arch in 32 64 32s 64s; do
  download "https://github.com/DominicBreuker/pspy/releases/download/v1.2.1/pspy${arch}" "/privilege_escalation/linux/pspy${arch}"
done

# winenum
download https://raw.githubusercontent.com/EnginDemirbilek/WinEnum/refs/heads/master/winenum.ps1 /privilege_escalation/windows/winenum.ps1

# winpeas
for variant in any x64; do
  download "https://github.com/peass-ng/PEASS-ng/releases/latest/download/winPEAS${variant}.exe" "/privilege_escalation/windows/winPEAS${variant}.exe"
done

# netcat.exe
download "https://github.com/int0x33/nc.exe/raw/refs/heads/master/nc.exe" /privilege_escalation/windows/nc.exe
download "https://github.com/int0x33/nc.exe/raw/refs/heads/master/nc64.exe" /privilege_escalation/windows/nc64.exe

# SeBackupPrivilege Utils
download 'https://github.com/giuliano108/SeBackupPrivilege/blob/master/SeBackupPrivilegeCmdLets/bin/Debug/SeBackupPrivilegeUtils.dll?raw=true' /privilege_escalation/windows/SeBackupPrivilegeUtils.dll
download 'https://github.com/giuliano108/SeBackupPrivilege/blob/master/SeBackupPrivilegeCmdLets/bin/Debug/SeBackupPrivilegeCmdLets.dll?raw=true' /privilege_escalation/windows/SeBackupPrivilegeCmdLets.dll

echo "Getting wordlists ressources..."
# wordlists
# rules
echo "Gettings rules..."
download https://sources.debian.org/data/main/h/hashcat/5.1.0%2Bds1-1/rules/best64.rule /wordlists/rules/best64.rule
download https://raw.githubusercontent.com/Unic0rn28/hashcat-rules/refs/heads/main/unicorn%20rules/Unicorn1k.rule /wordlists/rules/Unicorn1k.rule
download https://raw.githubusercontent.com/Unic0rn28/hashcat-rules/refs/heads/main/unicorn%20rules/TheOneTrueUnicorn.rule /wordlists/rules/TheOneTrueUnicorn.rule
# wordlists
echo "Getting passwords wordlists..."
download https://raw.githubusercontent.com/tarraschk/richelieu/refs/heads/master/french_passwords_top20000.txt /wordlists/passwords/richelieu20k.txt
download https://weakpass.com/download/1987/hashmob.net.small.found.txt.7z /wordlists/passwords/hashmob.net.small.found.txt.7z 
7z x /wordlists/passwords/hashmob.net.small.found.txt.7z -o/wordlists/passwords/ 1> /dev/null
rm /wordlists/passwords/hashmob.net.small.found.txt.7z
download https://raw.githubusercontent.com/tThomasJolyY/Wordlists/refs/heads/main/10-million-password-list-top-10000.txt /wordlists/passwords/10-million-password-list-top-10000.txt
download https://github.com/tThomasJolyY/Wordlists/raw/refs/heads/main/milw0rm-dictionary.txt /wordlists/passwords/milw0rm-dictionary.txt

echo "Getting web wordlists..."
download https://raw.githubusercontent.com/tThomasJolyY/Wordlists/refs/heads/main/Common-PHP-Filenames.txt /wordlists/web/Common-PHP-Filenames.txt
download https://raw.githubusercontent.com/tThomasJolyY/Wordlists/refs/heads/main/actions-lowercase.txt /wordlists/web/actions-lowercase.txt
download https://raw.githubusercontent.com/tThomasJolyY/Wordlists/refs/heads/main/api.txt /wordlists/web/api.txt
download https://github.com/tThomasJolyY/Wordlists/raw/refs/heads/main/big.txt /wordlists/web/big.txt
download https://raw.githubusercontent.com/tThomasJolyY/Wordlists/refs/heads/main/html.txt /wordlists/web/html.txt
download https://github.com/tThomasJolyY/Wordlists/raw/refs/heads/main/js-25k.txt /wordlists/web/js-25k.txt
download https://github.com/tThomasJolyY/Wordlists/raw/refs/heads/main/js-3k.txt /wordlists/web/js-3k.txt
download https://github.com/tThomasJolyY/Wordlists/raw/refs/heads/main/parameters.txt /wordlists/web/parameters.txt
download https://github.com/tThomasJolyY/Wordlists/raw/refs/heads/main/subdomains-top1million-110000.txt /wordlists/web/subdomains-top1million-110000.txt
download https://github.com/tThomasJolyY/Wordlists/raw/refs/heads/main/subdomains-top1million-20000.txt /wordlists/web/subdomains-top1million-20000.txt
download https://github.com/tThomasJolyY/Wordlists/raw/refs/heads/main/subdomains-top1million-5000.txt /wordlists/web/subdomains-top1million-5000.txt
download https://github.com/tThomasJolyY/Wordlists/raw/refs/heads/main/subdomains.txt /wordlists/web/subdomains.txt
download https://github.com/tThomasJolyY/Wordlists/raw/refs/heads/main/web-common.txt /wordlists/web/web-common.txt

echo "Getting other wordlists..."
download https://github.com/tThomasJolyY/Wordlists/raw/refs/heads/main/snmp-community-strings.txt /wordlists/others/snmp-community-strings.txt
download https://github.com/tThomasJolyY/Wordlists/raw/refs/heads/main/top-usernames-shortlist.txt /wordlists/others/top-usernames-shortlist.txt
download https://github.com/tThomasJolyY/Wordlists/raw/refs/heads/main/usernames.txt /wordlists/others/usernames.txt
download https://github.com/tThomasJolyY/Wordlists/raw/refs/heads/main/xato-net-10-million-usernames-dup.txt /wordlists/others/xato-net-10-million-usernames-dup.txt

# seclists
echo "Cloning seclists..."
git clone --depth 1 https://github.com/danielmiessler/SecLists.git /seclists 
