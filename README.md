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

### Warning
This project has a lot of issues and some things may not work as expected. 