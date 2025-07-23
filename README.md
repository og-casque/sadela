# sadela
Pentesting docker image based on debian with a wrapper to make it cool.

### Basic usage
First you have to build the image 

    ./sadela.py --build [--debug]

Then you can create containers 

    ./sadela.py --run --name container_name [--shared-dir /path/to/shared/dir]

Start an existing container 

    ./sadela.py --run --name container_name

Delete a container 

    ./sadela.py --rm --name container_name

List created containers

    ./sadela.py --list

### TODO

- [ ] fix rights for files in shared dir
- [ ] fix `/etc/hosts` file
- [ ] fix issues with `bloodhound` crashing unexpectedly
- [ ] cleaner install for personall wordlists
- [ ] add a personal ressources option
- [ ] fix issues with the wrapper (when a container crashes, fix list)

### Warning
This project is in development and some things may not work as expected. Pre installed tools should all work though.