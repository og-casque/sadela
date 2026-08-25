#!/bin/bash

set -euo pipefail

download() {
  local url="$1"
  local dest="$2"
  echo "Downloading ${dest##*/}..."
  curl -sSL "$url" -o "$dest" || echo "❌ Failed to download $url"
  [ -f "$dest" ] || echo "⚠️  ${dest##*/} missing!"
}

mkdir -p /privilege_escalation/linux /privilege_escalation/windows /seclists /code-analysis

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

# seclists
echo "Cloning seclists..."
git clone --depth 1 https://github.com/danielmiessler/SecLists.git /seclists 
