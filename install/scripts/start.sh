#!/bin/sh
# entrypoint for pyffd (discovery and mdx service)

/usr/bin/pyffd -a -f --proxy \
    --log=$LOGDIR/pyffd.log \
    --error-log=$LOGDIR/pyffd.error \
    --loglevel=$LOGLEVEL \
    --frequency=$FREQUENCY \
    -H0.0.0.0 \
    -p $PIDFILE \
    $PIPELINEDAEMON
