# sadela

A feature-rich pentesting Docker image based on Debian 12, bundled with a Python CLI wrapper to manage images and containers effortlessly.

The image ships with **100+ pre-installed offensive security tools**, wordlists, privilege-escalation resources, and a pre-configured environment (zsh, tmux, Neo4j, BloodHound…) so you can spin up a ready-to-go pentest lab in seconds.

---

## Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [CLI Reference](#cli-reference)
- [Volume Mounts](#volume-mounts)
- [Helper Scripts (inside container)](#helper-scripts-inside-container)
- [Warnings & Limitations](#warnings--limitations)

---

## Prerequisites

- **Linux** (tested on X11-based desktop environments)
- **Docker** (daemon running)
- **Python 3** with the following packages:

```
pip install docker rich
```

or:

```
pip install -r requirements.txt
```

- **xhost** (usually part of `xorg` or `x11-xserver-utils`) — required for GUI apps (BloodHound)

---

## Installation

Clone the repository:

```bash
git clone https://github.com/og-casque/sadela.git
cd sadela
pip install -r requirements.txt
```

---

## Quick Start

### 1. Pull the pre-built image

```bash
./sadela.py -p
```

> You can also specify a version: `./sadela.py -p -i v0.3`

### 2. Create and enter a container

```bash
./sadela.py -r -n mypentest
```

With a workspace and shared directory:

```bash
./sadela.py -r -n mypentest -w /path/to/project -s /path/to/shared/tools
```

### 3. Re-enter an existing (stopped) container

```bash
./sadela.py -r -n mypentest
```

The wrapper detects the container state and starts/attaches automatically.

### 4. List tracked containers and images

```bash
./sadela.py -l
```

### 5. Delete a container

```bash
./sadela.py -R -n mypentest
```

### 6. Build the image locally (optional)

```bash
./sadela.py -b          # standard build
./sadela.py -b -d       # debug/verbose build (--no-cache --progress=plain)
```

---

## CLI Reference

| Flag | Long | Description |
|------|------|-------------|
| `-p` | `--pull` | Pull the image from GHCR (use `-i` to specify a version) |
| `-b` | `--build` | Build the Docker image locally |
| `-d` | `--debug` | Verbose build output (implies `--no-cache --progress=plain`) |
| `-f` | `--dockerfile` | Path to Dockerfile (default: `BuildDir/Dockerfile.debian`) |
| `-r` | `--run` | Create, start, or resume a container |
| `-n` | `--name` | Container name (required for `-r`, `-R`) |
| `-w` | `--work-dir` | Host directory mounted at `/workspace` (read-write) |
| `-s` | `--shared-dir` | Host directory mounted at `/shared` (read-only) |
| `-i` | `--image` | Image tag (e.g. `v0.3` or full `ghcr.io/…` tag) |
| `-l` | `--list` | List all tracked containers and images |
| `-R` | `--rm` | Delete a container (Docker + DB record) |
| `-I` | `--rmi` | Remove an image (requires `-i`; refuses if containers reference it) |

---

## Volume Mounts

When creating a container, two optional host directories can be mapped:

| Host path | Container path | Mode | Flag |
|-----------|---------------|------|------|
| `--work-dir` | `/workspace` | read-write | `-w` |
| `--shared-dir` | `/shared` | read-only | `-s` |

> **Note:** `--work-dir` and `--shared-dir` cannot point to the same directory.

---

---

## Warnings & Limitations

- **Linux only** — tested on X11-based desktop environments. GUI applications (BloodHound) require X11.
- **Wayland** is not supported for GUI forwarding; use XWayland or an X11 session.
- This project is under active development — some edge cases may not be handled. All pre-installed tools should work out of the box.