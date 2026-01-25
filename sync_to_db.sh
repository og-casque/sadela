#!/usr/bin/env bash
set -euo pipefail

# Usage:
# ./sync_to_db.sh --image sadela:v0.2 --containers --images
# defaults: --image sadela:v0.2 --containers --images

IMAGE="sadela:v0.2"
DO_CONTAINERS=1
DO_IMAGES=1

# parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --image|-i) IMAGE="$2"; shift 2;;
    --containers|-c) DO_CONTAINERS=1; shift;;
    --no-containers) DO_CONTAINERS=0; shift;;
    --images|-m) DO_IMAGES=1; shift;;
    --no-images) DO_IMAGES=0; shift;;
    --help|-h) echo "Usage: $0 [--image IMAGE] [--containers|--no-containers] [--images|--no-images]"; exit 0;;
    *) echo "Unknown arg: $1"; exit 2;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_PATH="$SCRIPT_DIR/data/sadela.db"

# ensure data dir + DB schema
mkdir -p "$(dirname "$DB_PATH")"

sqlite3 "$DB_PATH" <<'SQL'
PRAGMA journal_mode=WAL;
CREATE TABLE IF NOT EXISTS images (
    id INTEGER PRIMARY KEY,
    image_tag TEXT UNIQUE,
    dockerfile_path TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS containers (
    id INTEGER PRIMARY KEY,
    name TEXT UNIQUE,
    image_tag TEXT,
    work_dir TEXT,
    shared_dir TEXT,
    last_status TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT
);
SQL

# helper to quote for sqlite
sql_escape() {
  printf "%s" "$1" | sed "s/'/''/g"
}

# containers: find containers whose image matches the provided image (ancestor/ancestor filter)
if [[ $DO_CONTAINERS -eq 1 ]]; then
  echo "Scanning docker containers using image reference '$IMAGE'..."
  # If user provided a repo without tag (eg. sadela) we'll accept any tag: convert "repo" -> "repo:*" for filter
  if [[ "$IMAGE" == *":"* ]]; then
    FILTER_REF="$IMAGE"
  else
    FILTER_REF="${IMAGE}:*"
  fi

  # Use docker ps -a with filter ancestor (matches images used to create)
  docker ps -a --filter "ancestor=$IMAGE" --format '{{.Names}}\t{{.Image}}\t{{.Status}}' | while IFS=$'\t' read -r cname cimage cstatus; do
    # normalize status
    if [[ "$cstatus" == Up* ]]; then
      last="running"
    elif [[ "$cstatus" == Exited* ]]; then
      last="exited"
    else
      last="$(echo "$cstatus" | awk '{print $1}')"
    fi
    nname=$(sql_escape "$cname")
    nimage=$(sql_escape "$cimage")
    nlast=$(sql_escape "$last")
    now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    sql="INSERT OR REPLACE INTO containers (name, image_tag, work_dir, shared_dir, last_status, updated_at) VALUES ('$nname', '$nimage', NULL, NULL, '$nlast', '$now');"
    sqlite3 "$DB_PATH" "$sql"
    echo "Added/updated container: $cname (image: $cimage, status: $last)"
  done

  # fallback: if docker ps -a --filter ancestor produced nothing, try matching by image tag in `docker ps -a`
  if ! docker ps -a --filter "ancestor=$IMAGE" --format '{{.Names}}' | grep -q '.' 2>/dev/null; then
    # scan all containers and pick those whose image tag exactly matches IMAGE
    docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}' | while IFS=$'\t' read -r cname cimage cstatus; do
      if [[ "$cimage" == "$IMAGE" ]]; then
        if [[ "$cstatus" == Up* ]]; then
          last="running"
        elif [[ "$cstatus" == Exited* ]]; then
          last="exited"
        else
          last="$(echo "$cstatus" | awk '{print $1}')"
        fi
        nname=$(sql_escape "$cname")
        nimage=$(sql_escape "$cimage")
        nlast=$(sql_escape "$last")
        now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        sql="INSERT OR REPLACE INTO containers (name, image_tag, work_dir, shared_dir, last_status, updated_at) VALUES ('$nname', '$nimage', NULL, NULL, '$nlast', '$now');"
        sqlite3 "$DB_PATH" "$sql"
        echo "Added/updated container: $cname (image: $cimage, status: $last)"
      fi
    done
  fi
fi

# images: add matching images (by exact tag or by repo:* if user passed repo only)
if [[ $DO_IMAGES -eq 1 ]]; then
  echo "Scanning docker images for '$IMAGE'..."
  # if IMAGE includes ':', treat as exact tag; otherwise use repo:*
  if [[ "$IMAGE" == *":"* ]]; then
    refs=( "$IMAGE" )
  else
    repo="${IMAGE}"
    # list tags for repo
    mapfile -t refs < <(docker images --format '{{.Repository}}:{{.Tag}}' | grep -E "^${repo}:" || true)
  fi

  # if no refs found and IMAGE included a tag, still try to add that tag record
  if [[ ${#refs[@]} -eq 0 && "$IMAGE" == *":"* ]]; then
    refs=( "$IMAGE" )
  fi

  for tag in "${refs[@]}"; do
    t=$(sql_escape "$tag")
    # insert or replace, dockerfile_path unknown when adding from docker
    sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO images (image_tag, dockerfile_path, created_at) VALUES ('$t', NULL, DATETIME('now'));"
    echo "Added/updated image: $tag"
  done
fi

echo "Done."