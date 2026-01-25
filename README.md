# sadela
Pentesting docker image based on debian with a wrapper to make it cool.

### Basic usage
First you have to pull the latest version of the image 

    ./sadela.py -p

You can also build it locally

    ./sadela.py -b [-d]

Then you can create containers 

    ./sadela.py -r -n container_name [-w /path/to/workspace/dir] [-s /path/to/shared/dir]

Start an existing container 

    ./sadela.py -r -n container_name

Delete a container 

    ./sadela.py -R -n container_name

List containers and images

    ./sadela.py -l

Delete an image

    ./sadela.py -I -i <image_version>

### Warning
This has only been tested on Linux. GUI apps work only in X11-based environments.

This project is in development and some things may not work as expected. Pre installed tools should all work though.