#!/usr/bin/env python3

import argparse
import subprocess
import os
import sys
import docker

IMAGE_NAME = "sadela:v0.1"

client = docker.from_env()

def build_image(dockerfile_path,debug_mode):
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
        print("✅ Image built successfully.")
    except Exception as e:
        print("❌ Failed to build Docker image.\n",e)

def run_container(container_name, shared_dir=None):
    print(f"🚀 Running container '{container_name}' from image '{IMAGE_NAME}'...")
    display = os.getenv("DISPLAY", ":0")

    try:
        if container_name in [cont.name for cont in client.containers.list(all=True) if cont.image.tags[0].split(':')[0] == IMAGE_NAME.split(':')[0]]:
            container = client.containers.get(container_name)
            if container.status == "exited":
                print(f"🔁 Restarting container '{container_name}'...")
                subprocess.run(["xhost", "+local:docker"], check=False)
                container.start()
                subprocess.run(["docker", "exec", "-it", container_name, "zsh"])
                container.kill()
                subprocess.run(["xhost", "-local:docker"], check=False)
            elif containers[container_name].startswith("Up"):
                print(f"⚠️ Container '{container_name}' is already running.")
                print("Use `docker exec -it {}` to access it.".format(container_name))
            else:
                print(f"❓ Container '{container_name}' is in an unknown state: {container.status}")
        else:
            print(f"➕ Creating new container '{container_name}'...")
            subprocess.run(["xhost", "+local:docker"], check=False)

            if shared_dir:
                abs_path = os.path.abspath(shared_dir)
                volumes_to_mount = {abs_path: {'bind': '/workspace', 'mode': 'rw'},
                '/tmp/.X11-unix': {'bind': '/tmp/.X11-unix', 'mode': 'rw'}}

            else:
                volumes_to_mount = {'/tmp/.X11-unix': {'bind': '/tmp/.X11-unix', 'mode': 'rw'}}

            container = client.containers.create(
                image=IMAGE_NAME,
                name=container_name,
                cap_add=["NET_ADMIN", "NET_RAW"],
                network_mode="host",
                volumes=volumes_to_mount,
                environment={"DISPLAY": display},
                stdin_open=True,
                tty=True,
                hostname=container_name
            )

            container.start()
            subprocess.run(["docker", "exec", "-it", container_name, "zsh"])
            container.kill()
            subprocess.run(["xhost", "-local:docker"], check=False)

    except subprocess.CalledProcessError:
        print("❌ Failed to run or resume container.")


def list_containers():
    print("📋 Listing all containers...")
    [print(cont.name,f"({cont.status}) :", cont.image.tags[0]) for cont in client.containers.list(all=True) if cont.image.tags[0].split(':')[0]==IMAGE_NAME.split(':')[0]]

def delete_container(container_name):
    print(f"Deleting {container_name}...")
    for cont in client.containers.list(all=True):
        if cont.name == container_name and cont.image.tags[0].split(':')[0]==IMAGE_NAME.split(':')[0]:
            cont.remove()

def main():
    parser = argparse.ArgumentParser(description="Docker CLI Wrapper")
    parser.add_argument('--build', action='store_true', help='Build Docker image')
    parser.add_argument('--run', action='store_true', help='Run container')
    parser.add_argument('--list', action='store_true', help='List containers')

    parser.add_argument('--debug', action='store_true', default=False, help='Increase verbosity (False by default)')

    parser.add_argument('--dockerfile', default='BuildDir/Dockerfile.debian', help='Path to Dockerfile (by default BuildDir/Dockerfile.debian)')

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


if __name__ == '__main__':
    main()

