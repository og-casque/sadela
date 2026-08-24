#!/usr/bin/env python3

import argparse
import subprocess
import os
import sys
import docker
import sqlite3
import datetime
from rich.table import Table
from rich.console import Console
from rich.progress import Progress, BarColumn, DownloadColumn, TextColumn, TransferSpeedColumn, TimeRemainingColumn

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "data")
DB_PATH = os.path.join(DATA_DIR, "sadela.db")

IMAGE_NAME = "ghcr.io/og-casque/sadela:v0.4"

client = docker.from_env()

# Database helpers
def init_db():
    # ensure data directory exists
    os.makedirs(DATA_DIR, exist_ok=True)

    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("""
    CREATE TABLE IF NOT EXISTS images (
        id INTEGER PRIMARY KEY,
        image_tag TEXT UNIQUE,
        dockerfile_path TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
    """)
    cur.execute("""
    CREATE TABLE IF NOT EXISTS containers (
        id INTEGER PRIMARY KEY,
        name TEXT UNIQUE,
        image_tag TEXT,
        work_dir TEXT,
        shared_dir TEXT,
        last_status TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT
    )
    """)
    conn.commit()
    conn.close()

def add_image_record(image_tag, dockerfile_path):
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("SELECT id FROM images WHERE image_tag = ?", (image_tag,))
    if cur.fetchone():
        cur.execute("UPDATE images SET dockerfile_path = ?, created_at = CURRENT_TIMESTAMP WHERE image_tag = ?",
                    (dockerfile_path, image_tag))
    else:
        cur.execute("INSERT INTO images (image_tag, dockerfile_path) VALUES (?, ?)",
                    (image_tag, dockerfile_path))
    conn.commit()
    conn.close()

def add_container_record(name, image_tag, work_dir=None, shared_dir=None, status=None):
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    cur.execute("SELECT id FROM containers WHERE name = ?", (name,))
    if cur.fetchone():
        cur.execute("""UPDATE containers
                       SET image_tag = ?, work_dir = ?, shared_dir = ?, last_status = ?, updated_at = ?
                       WHERE name = ?""",
                    (image_tag, work_dir, shared_dir, status, now, name))
    else:
        cur.execute("""INSERT INTO containers (name, image_tag, work_dir, shared_dir, last_status, updated_at)
                       VALUES (?, ?, ?, ?, ?, ?)""",
                    (name, image_tag, work_dir, shared_dir, status, now))
    conn.commit()
    conn.close()

def update_container_status(name, status):
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    cur.execute("UPDATE containers SET last_status = ?, updated_at = ? WHERE name = ?", (status, now, name))
    conn.commit()
    conn.close()

def delete_container_record(name):
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("DELETE FROM containers WHERE name = ?", (name,))
    conn.commit()
    conn.close()

def delete_image_record(image_tag):
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("DELETE FROM images WHERE image_tag = ?", (image_tag,))
    conn.commit()
    conn.close()

def delete_image(requested_image):
    """Remove an image if no containers reference it (DB or live)."""
    # normalize requested image (allow 'v0.3' or 'sadela:v0.3')
    image_tag = resolve_image_tag(requested_image)
    # ensure DB exists
    init_db()

    # check DB for containers using this image
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM containers WHERE image_tag = ?", (image_tag,))
    count_db = cur.fetchone()[0]
    conn.close()
    if count_db > 0:
        print(f"❌ Cannot remove image {image_tag}: {count_db} container(s) in DB reference it.")
        return

    # check live docker containers
    used_by_live = []
    try:
        for cont in client.containers.list(all=True):
            try:
                tags = cont.image.tags or []
            except Exception:
                tags = []
            if image_tag in tags:
                used_by_live.append(cont.name)
    except Exception as e:
        print("❌ Failed to query docker containers:", e)
        return

    if used_by_live:
        print(f"❌ Cannot remove image {image_tag}: used by running/existing containers: {', '.join(used_by_live)}")
        return

    # attempt to remove the image
    try:
        client.images.remove(image=image_tag)
        # remove DB record if present
        delete_image_record(image_tag)
        print(f"✅ Image {image_tag} removed successfully.")
    except docker.errors.ImageNotFound:
        # image not present locally, still remove DB record if any
        delete_image_record(image_tag)
        print(f"ℹ️ Image {image_tag} not found locally — DB record removed if present.")
    except docker.errors.APIError as e:
        print(f"❌ Docker API error while removing image {image_tag}:\n", e)
    except Exception as e:
        print(f"❌ Unexpected error while removing image {image_tag}:\n", e)

def get_tracked_containers():
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("SELECT name, image_tag, work_dir, shared_dir, last_status, created_at, updated_at FROM containers")
    rows = cur.fetchall()
    conn.close()
    return rows

def get_tracked_images():
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("SELECT image_tag, dockerfile_path, created_at FROM images")
    rows = cur.fetchall()
    conn.close()
    return rows

# Docker operations
def build_image(dockerfile_path, debug_mode):
    print(f"🛠️  Building image '{IMAGE_NAME}' from Dockerfile at '{dockerfile_path}'...")
    try:
        if debug_mode:
            build_cmd = [
                "docker", "build", "--progress=plain", "--no-cache", "-t", IMAGE_NAME,
                "-f", dockerfile_path, "."]
        else:
            build_cmd = [
                "docker", "build", "--no-cache", "-t", IMAGE_NAME,
                "-f", dockerfile_path, "."]
        subprocess.run(build_cmd, check=True)
        add_image_record(IMAGE_NAME, dockerfile_path)
        print("✅ Image built and recorded successfully.")
    except subprocess.CalledProcessError as e:
        print("❌ Failed to build Docker image.\n", e)
    except Exception as e:
        print("❌ Unexpected error during build:\n", e)

def resolve_image_tag(requested_image=None):
    """Return a full image tag to use. If requested_image is provided it is normalized
    (e.g. 'v0.3' -> '<repo>:v0.3', or 'ghcr.io/..../sadela:v0.3' left as-is). If omitted, pick the
    most recently created local image for the IMAGE_NAME repo. Fallback to IMAGE_NAME when nothing is found.
    """
    repo = IMAGE_NAME.split(":")[0]
    if requested_image:
        return requested_image if ":" in requested_image else f"{repo}:{requested_image}"

    try:
        images = client.images.list()
        candidates = []
        for img in images:
            for tag in img.tags or []:
                if tag.startswith(repo + ":") or tag == repo:
                    created = img.attrs.get("Created")
                    try:
                        created_dt = datetime.datetime.fromisoformat(created.replace("Z", "+00:00"))
                    except Exception:
                        created_dt = datetime.datetime.min
                    candidates.append((created_dt, tag))
        if candidates:
            candidates.sort(reverse=True)
            return candidates[0][1]
    except Exception:
        pass

    return IMAGE_NAME

def pull_image(requested_image=None):
    """Pull an image from the registry. requested_image may be full tag or short version (v0.3)."""
    tag = requested_image if requested_image and ":" in requested_image else (f"{IMAGE_NAME.split(':')[0]}:{requested_image}" if requested_image else IMAGE_NAME)
    console = Console()
    console.print(f"⬇️  Pulling image '[bold]{tag}[/bold]'...")
    try:
        # layer_id -> task_id mapping for per-layer progress bars
        layer_tasks = {}

        with Progress(
            TextColumn("[bold blue]{task.description}"),
            BarColumn(),
            DownloadColumn(),
            TransferSpeedColumn(),
            TimeRemainingColumn(),
            console=console,
            transient=True,
        ) as progress:
            for event in client.api.pull(tag, stream=True, decode=True):
                status = event.get("status", "")
                layer_id = event.get("id", "")
                detail = event.get("progressDetail", {})
                current = detail.get("current", 0)
                total = detail.get("total", 0)

                if not layer_id:
                    continue

                if status in ("Pulling fs layer", "Waiting"):
                    if layer_id not in layer_tasks:
                        layer_tasks[layer_id] = progress.add_task(
                            f"[cyan]{layer_id}[/cyan] {status}", total=None
                        )
                elif status == "Downloading":
                    if layer_id not in layer_tasks:
                        layer_tasks[layer_id] = progress.add_task(
                            f"[cyan]{layer_id}[/cyan] Downloading", total=total or None
                        )
                    progress.update(
                        layer_tasks[layer_id],
                        description=f"[cyan]{layer_id}[/cyan] Downloading",
                        completed=current,
                        total=total or None,
                    )
                elif status == "Pull complete":
                    if layer_id in layer_tasks:
                        progress.update(
                            layer_tasks[layer_id],
                            description=f"[green]{layer_id}[/green] Pull complete",
                            completed=total or 1,
                            total=total or 1,
                        )
                elif status == "Already exists":
                    if layer_id not in layer_tasks:
                        layer_tasks[layer_id] = progress.add_task(
                            f"[yellow]{layer_id}[/yellow] Already exists", total=1, completed=1
                        )

        # record in DB (dockerfile_path unknown when pulling)
        add_image_record(tag, None)
        console.print("✅ Image pulled and recorded successfully.")
    except docker.errors.APIError as e:
        console.print(f"❌ Docker API error while pulling image {tag}:\n", e)
    except Exception as e:
        console.print(f"❌ Unexpected error during pull:\n", e)

def run_container(container_name, work_dir=None, shared_dir=None, image_tag=None):
    display = os.getenv("DISPLAY", ":0")
    # ensure DB initialized
    init_db()

    # resolve fallback image to use for creation if DB has no record
    image_to_use = resolve_image_tag(image_tag)

    # prefer DB to detect existing container
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("SELECT image_tag, work_dir, shared_dir, last_status FROM containers WHERE name = ?", (container_name,))
    db_row = cur.fetchone()
    conn.close()

    # decide which image label to show/use: prefer DB-stored image_tag when present
    db_image_tag = db_row[0] if db_row else None
    db_work_dir = db_row[1] if db_row else None
    db_shared_dir = db_row[2] if db_row else None

    image_label = db_image_tag or image_to_use

    try:
        # try to get container by name from Docker
        try:
            container = client.containers.get(container_name)
        except docker.errors.NotFound:
            container = None

        if db_row:
            # DB claims the container exists (or existed) — treat as existing
            if container:
                stat = container.status
                if stat == "exited":
                    print(f"🚀 Starting container '{container_name}' (image: {image_label})...")
                    subprocess.run(["xhost", "+local:docker"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    container.start()
                    update_container_status(container_name, "running")
                    subprocess.run(["docker", "exec", "-it", container_name, "zsh"])
                    try:
                        container.kill()
                        update_container_status(container_name, "exited")
                    except Exception:
                        pass
                    subprocess.run(["xhost", "-local:docker"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                elif stat == "running":
                    print(f"⚠️ Container '{container_name}' is already running (image: {image_label}). Use `docker exec -it {container_name} zsh` to access it.")
                    update_container_status(container_name, "running")
                else:
                    print(f"❓ Container '{container_name}' is in an unknown state: {stat} (image: {image_label})")
                    update_container_status(container_name, stat)
            else:
                # DB entry exists but container not present in Docker -> recreate using DB data
                print(f"ℹ️ DB has record for '{container_name}' — creating container using image '{image_label}' and stored mounts...")
                volumes_to_mount = {'/tmp/.X11-unix': {'bind': '/tmp/.X11-unix', 'mode': 'rw'},
                                    '/etc/localtime': {'bind': '/etc/localtime', 'mode': 'ro'}}

                work_dir_abs_path = None
                if db_work_dir:
                    work_dir_abs_path = os.path.abspath(db_work_dir)
                    volumes_to_mount[work_dir_abs_path] = {'bind': '/workspace', 'mode': 'rw'}
                elif work_dir:
                    work_dir_abs_path = os.path.abspath(work_dir)
                    volumes_to_mount[work_dir_abs_path] = {'bind': '/workspace', 'mode': 'rw'}

                if db_shared_dir:
                    shared_dir_abs_path = os.path.abspath(db_shared_dir)
                    if work_dir_abs_path and shared_dir_abs_path == work_dir_abs_path:
                        print(f"--shared-dir and --work-dir cannot refer to the same directory, {shared_dir_abs_path} won't be mapped to /shared")
                    else:
                        volumes_to_mount[shared_dir_abs_path] = {'bind': '/shared', 'mode': 'ro'}
                elif shared_dir:
                    shared_dir_abs_path = os.path.abspath(shared_dir)
                    if work_dir_abs_path and shared_dir_abs_path == work_dir_abs_path:
                        print(f"--shared-dir and --work-dir cannot refer to the same directory, {shared_dir_abs_path} won't be mapped to /shared")
                    else:
                        volumes_to_mount[shared_dir_abs_path] = {'bind': '/shared', 'mode': 'ro'}

                container = client.containers.create(
                    image=image_label,
                    name=container_name,
                    cap_add=["NET_ADMIN", "NET_RAW"],
                    network_mode="host",
                    volumes=volumes_to_mount,
                    environment={"DISPLAY": display},
                    stdin_open=True,
                    tty=True,
                    hostname=container_name
                )

                add_container_record(container_name, image_label, work_dir_abs_path, db_shared_dir if db_shared_dir else (shared_dir if shared_dir else None), status="created")
                subprocess.run(["xhost", "+local:docker"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                container.start()
                update_container_status(container_name, "running")
                subprocess.run(["docker", "exec", "-it", container_name, "zsh"])
                try:
                    container.kill()
                    update_container_status(container_name, "exited")
                except Exception:
                    pass
                subprocess.run(["xhost", "-local:docker"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        else:
            # No DB record -> treat as new container creation
            print(f"➕ Creating new container '{container_name}' using image '{image_to_use}'...")
            volumes_to_mount = {'/tmp/.X11-unix': {'bind': '/tmp/.X11-unix', 'mode': 'rw'},
                                '/etc/localtime': {'bind': '/etc/localtime', 'mode': 'ro'}}

            work_dir_abs_path = None
            if work_dir:
                work_dir_abs_path = os.path.abspath(work_dir)
                volumes_to_mount[work_dir_abs_path] = {'bind': '/workspace', 'mode': 'rw'}

            if shared_dir:
                shared_dir_abs_path = os.path.abspath(shared_dir)
                if work_dir and shared_dir_abs_path == work_dir_abs_path:
                    print(f"--shared-dir and --work-dir cannot refer to the same directory, {shared_dir_abs_path} won't be mapped to /shared")
                else:
                    volumes_to_mount[shared_dir_abs_path] = {'bind': '/shared', 'mode': 'ro'}

            container = client.containers.create(
                image=image_to_use,
                name=container_name,
                cap_add=["NET_ADMIN", "NET_RAW"],
                network_mode="host",
                volumes=volumes_to_mount,
                environment={"DISPLAY": display},
                stdin_open=True,
                tty=True,
                hostname=container_name
            )

            add_container_record(container_name, image_to_use, work_dir_abs_path, shared_dir if shared_dir else None, status="created")
            subprocess.run(["xhost", "+local:docker"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            container.start()
            update_container_status(container_name, "running")
            subprocess.run(["docker", "exec", "-it", container_name, "zsh"])
            try:
                container.kill()
                update_container_status(container_name, "exited")
            except Exception:
                pass
            subprocess.run(["xhost", "-local:docker"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    except subprocess.CalledProcessError:
        print("❌ Failed to run or resume container.")
    except docker.errors.NotFound:
        print("❌ Container not found.")
    except Exception as e:
        print("❌ Unexpected error in run_container:\n", e)

def list_containers():
    init_db()
    rows = get_tracked_containers()
    console = Console()

    table = Table(show_header=True, header_style="bold cyan")
    table.add_column("NAME", no_wrap=True, max_width=30)
    table.add_column("IMAGE", max_width=18)
    table.add_column("DB_STATUS", max_width=12)
    table.add_column("LIVE", max_width=12)
    table.add_column("WORK_DIR", max_width=40, overflow="ellipsis")
    table.add_column("SHARED_DIR", max_width=36, overflow="ellipsis")
    table.add_column("UPDATED_AT", max_width=20)

    for r in rows:
        name, image_tag, work_dir, shared_dir, last_status, created_at, updated_at = r
        try:
            cont = client.containers.get(name)
            live_status = cont.status
        except Exception:
            live_status = ""
        table.add_row(
            name or "",
            image_tag or "",
            last_status or "",
            live_status or "",
            work_dir or "",
            shared_dir or "",
            updated_at or ""
        )

    if rows:
        console.print(table)
    else:
        console.print("[yellow]No tracked containers found in the database.[/yellow]")

    imgs = get_tracked_images()
    if not imgs:
        console.print("\n[yellow]No tracked images found in the database.[/yellow]")
    else:
        img_table = Table(show_header=True, header_style="bold cyan")
        img_table.add_column("IMAGE_TAG", max_width=30)
        img_table.add_column("DOCKERFILE_PATH", max_width=60, overflow="ellipsis")
        img_table.add_column("CREATED_AT", max_width=20)
        for img in imgs:
            img_table.add_row(img[0] or "", img[1] or "", img[2] or "")
        console.print("\nTracked images:")
        console.print(img_table)

def delete_container(container_name):
    print(f"Deleting {container_name}...")
    try:
        # attempt to remove docker container if exists
        try:
            cont = client.containers.get(container_name)
            cont.remove(force=True)
            print(f"Removed docker container {container_name}")
        except docker.errors.NotFound:
            print("Container not found in Docker, removing DB entry if present.")
        delete_container_record(container_name)
        print("DB record removed.")
    except Exception as e:
        print("❌ Error deleting container:\n", e)

def main():
    parser = argparse.ArgumentParser(
        description="Docker CLI Wrapper",
        formatter_class=lambda prog: argparse.RawDescriptionHelpFormatter(prog, max_help_position=35, width=100)
    )

    parser.add_argument('-b', '--build', action='store_true', help='Build Docker image')
    parser.add_argument('-r', '--run', action='store_true', help='Run container')
    parser.add_argument('-l', '--list', action='store_true', help='List containers')
    parser.add_argument('-d', '--debug', action='store_true', default=False, help='Increase verbosity during build. Default value: False')
    parser.add_argument('-f', '--dockerfile', default='BuildDir/Dockerfile.debian', help='Path to Dockerfile. Default value: BuildDir/Dockerfile.debian')
    parser.add_argument('-n', '--name', help='Name of the container')
    parser.add_argument('-w', '--work-dir', help='Path to a directory to share with container (mapped to /workspace rw, used when creating a new container).')
    parser.add_argument('-s', '--shared-dir', help='Path to a directory to share with container (mapped to /shared ro, used when creating a new container).')
    parser.add_argument('-R', '--rm', action='store_true', help='Delete a container')
    parser.add_argument('-i', '--image', help='Image tag to use (e.g. v0.3 or full ghcr tag). If omitted uses latest local image or IMAGE_NAME.')
    parser.add_argument('-I', '--rmi', action='store_true', help='Remove an image (requires -i/--image to specify which image)')
    parser.add_argument('-p', '--pull', action='store_true', help='Pull an image from the registry (use -i/--image to specify tag)')

    args = parser.parse_args()

    init_db()

    if args.build:
        if not args.dockerfile:
            print("❗ Please provide -f (--dockerfile) for the image (default value should be BuildDir/Dockerfile.debian).")
            sys.exit(1)
        build_image(dockerfile_path=args.dockerfile, debug_mode=args.debug)

    elif args.run:
        if not args.name:
            print("❗ Please provide -n (--name) for the container.")
            sys.exit(1)
        run_container(container_name=args.name, work_dir=args.work_dir, shared_dir=args.shared_dir, image_tag=args.image)

    elif args.list:
        list_containers()

    elif args.rm:
        if not args.name:
            print("❗ Please provide -n (--name) for the container to remove.")
            sys.exit(1)
        delete_container(args.name)

    elif args.rmi:
        if not args.image:
            print("❗ Please provide -i (--image) to specify which image to remove.")
            sys.exit(1)
        delete_image(args.image)

    elif args.pull:
        # pull specified image or IMAGE_NAME if not provided
        pull_image(args.image)

    else:
        parser.print_help(sys.stderr)
#
if __name__ == "__main__":
    main()