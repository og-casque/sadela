#!/usr/bin/env python3

import argparse
import subprocess
import os
import sys

IMAGE_NAME = "sadela"

def build_image(dockerfile_path,debug_mode):
    print(f"🛠️  Building image '{IMAGE_NAME}' from Dockerfile at '{dockerfile_path}'...")
    try:
        if debug_mode:
            build_cmd = [
            "docker", "build", "--progress=plain", "--no-cache", "-t", IMAGE_NAME,
            "-f", dockerfile_path, "."
        ]
        else:
            build_cmd = [
            "docker", "build", "--no-cache", "-t", IMAGE_NAME,
            "-f", dockerfile_path, "."
        ]
        subprocess.run(build_cmd, check=True)
        print("✅ Image built successfully.")
    except subprocess.CalledProcessError:
        print("❌ Failed to build Docker image.")

def run_container(container_name, shared_dir=None):
    print(f"🚀 Running container '{container_name}' from image '{IMAGE_NAME}'...")
    display = os.getenv("DISPLAY", ":0")

    result = subprocess.run(
        ["docker", "ps", "-a", "--format", "{{.Names}}:{{.Status}}"],
        capture_output=True, text=True
    )
    containers = dict()
    for line in result.stdout.splitlines():
        name, status = line.split(":", 1)
        containers[name.strip()] = status.strip()
    try:
        if container_name in containers:
            if containers[container_name].startswith("Exited"):
                print(f"🔁 Restarting container '{container_name}'...")
                subprocess.run(["xhost", "+local:docker"], check=True)
                subprocess.run(["docker", "start", "-ai", container_name], check=True)
                subprocess.run(["xhost", "-local:docker"], check=True)
                subprocess.run(["docker", "stop", container_name], check=True)
            elif containers[container_name].startswith("Up"):
                print(f"⚠️ Container '{container_name}' is already running.")
                print("Use `docker exec -it {}` to access it.".format(container_name))
            else:
                print(f"❓ Container '{container_name}' is in an unknown state: {containers[container_name]}")
        else:
            print(f"➕ Creating new container '{container_name}'...")
            subprocess.run(["xhost", "+local:docker"], check=True)
            docker_cmd = [
                "docker", "run", "-it",
                "--network", "host",
                "--hostname", container_name,
                "--name", container_name,
                "--cap-add=NET_ADMIN",
                "--cap-add=NET_RAW",
                "-e", f"DISPLAY={display}",
                "-v", "/tmp/.X11-unix:/tmp/.X11-unix"
            ]

            if shared_dir:
                abs_path = os.path.abspath(shared_dir)
                docker_cmd += ["-v", f"{abs_path}:/workspace"]

            docker_cmd.append(IMAGE_NAME)
            subprocess.run(docker_cmd, check=True)
            subprocess.run(["xhost", "-local:docker"], check=True)
            subprocess.run(["docker", "stop", container_name], check=True)

    except subprocess.CalledProcessError:
        print("❌ Failed to run or resume container.")


def list_containers():
    print("📋 Listing all containers...")
    try:
        subprocess.run(f"docker ps -a | grep {IMAGE_NAME}", shell=True)
    except subprocess.CalledProcessError:
        print("❌ Failed to list containers.")

def delete_container(container_name):
    print(f"Deleting {container_name}...")
    try:
        subprocess.run(["docker", "rm", container_name], check=True)
    except subprocess.CalledProcessError:
        print(f"❌ Failed to delete {container_name}")

def main():
    parser = argparse.ArgumentParser(description="Docker CLI Wrapper")
    parser.add_argument('--build', action='store_true', help='Build Docker image')
    parser.add_argument('--run', action='store_true', help='Run container')
    parser.add_argument('--list', action='store_true', help='List containers')

    parser.add_argument('--debug', action='store_true', default=False, help='Increase verbosity (False by default)')

    parser.add_argument('--dockerfile', default='BuildDir/Dockerfile.debian', help='Path to Dockerfile (debian by default)')

    parser.add_argument('--name', help='Container name')
    parser.add_argument('--shared-dir', help='Directory to share with container (only on first run, none by default)')

    parser.add_argument('--rm', action='store_true', help='Delete a container')
    args = parser.parse_args()

    if args.build:
        if not args.dockerfile:
            print("❗ Please provide --dockerfile for the image (default value should be BuildDir/Dockerfile.debian).")
            sys.exit(1)
        build_image(dockerfile_path=args.dockerfile, debug_mode=args.debug)

    elif args.run:
        if not args.name:
            print("❗ Please provide --name for the container.")
            sys.exit(1)
        run_container(container_name=args.name, shared_dir=args.shared_dir)


    elif args.list:
        list_containers()
    elif args.rm:
        delete_container(container_name=args.name)

    else:
        print("Didn't understand what you meant")

if __name__ == '__main__':
    main()

