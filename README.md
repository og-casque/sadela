# sadela
Pentesting docker image based on debian with a wrapper to make it cool.

### Basic usage
First you have to build the image 

    ./sadela.py --build [--debug]

Then you can create containers 

    ./sadela.py --run --name container_name [--work-dir /path/to/workspace/dir] [--shared-dir /path/to/shared/dir]

Start an existing container 

    ./sadela.py --run --name container_name

Delete a container 

    ./sadela.py --rm --name container_name

List created containers

    ./sadela.py --list

### Warning
This has only been tested on Linux. GUI apps work only in X11-based environments.

This project is in development and some things may not work as expected. Pre installed tools should all work though.