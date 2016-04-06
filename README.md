# Docker project template 

A docker image for running a XYZ instance. Has a few scripts around the docker commend that
is becoming unwiedly when one needs many arguments. Tries to be a thin wrapper around the
docerk CLI.

Features:
- The image produces immutable containers, i.e. a container can be removed and re-created
  any time without loss of data, because data is stored on mounted volumes.
- Configuration from a config file, building and running containers with the same script in
  different projects
- Consistent image, container, user and network mapping for multiple containers
- 

## Build the docker image
1. adapt conf.sh
2. run build.sh: 

   To run multiple XYZ containers on the same system you need to create separate 
   conf.sh files and build separate images:
   E.g. to create XYZ container instance 3:
   a) create a file conf3.sh, and set the IMGID=3; and
   b) build the container with the -n option, e.g. `build.sh -n 3`
   c) run the container with the -n option, e.g. `run.sh -n 3`


## Usage
Initialize mounted volumes with sample data (optional):
    
    run.sh -i init_sample.sh

Configure XYZ 
    ...

Configure env variables (in conf.sh):

    run.sh
    curl http://localhost:8080
    
Take care of appropriate port mapping and/or proxying


Execute batch script from crom
    exec_batch.sh 

Sample entry for /etc/crontab on docker host to run pyff every hour:

    29 *  *  *  *  root /docker_images/XYZ/exec_batch.sh -n 3 2>&1 > /var/log/exec_batch-3.log 
 