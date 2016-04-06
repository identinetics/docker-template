FROM centos:centos7
MAINTAINER Rainer Hörbe <r2h2@hoerbe.at>

RUN yum -y install epel-release curl ip lsof net-tools \
 && yum -y install gcc gcc-c++ openssl

# CentOS 7: EPEL does contain pyhton 3.4, but it fails to install PIP -> extra download
RUN yum -y install python34-devel \
 && curl https://bootstrap.pypa.io/get-pip.py | python3.4 \
 && yum clean all

# == install JAVA
RUN yum -y install java-1.8.0-openjdk-devel.x86_64
ENV JAVA_HOME=/etc/alternatives/java_sdk_1.8.0

# Application will run as a non-root user/group that must map to the docker host
ARG USERNAME
ARG UID
RUN groupadd -g $UID $USERNAME \
 && adduser -g $UID -u $UID $USERNAME \
 && mkdir -p /opt && chmod 750 /opt

COPY install/sample_data /opt/sample_data
COPY install/scripts/*.sh /
RUN chmod +x /*.sh \
 && chmod -R 755 /opt

