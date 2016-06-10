FROM centos:centos7
MAINTAINER Rainer Hörbe <r2h2@hoerbe.at>

# useful tools
RUN yum -y install curl git ip lsof net-tools openssl wget which

# more dev tools than just yum -y install gcc gcc-c++
RUN yum -y groupinstall "Development Tools" --setopt=group_package_types=mandatory,default,optional

# EPEL
RUN yum -y install epel-release

# GNOME
RUN yum -y groups install "GNOME Desktop"

# Python34: EPEL does contain pyhton 3.4, but it fails to install PIP -> extra download
RUN yum -y install python34-devel \
 && curl https://bootstrap.pypa.io/get-pip.py | python3.4
# PYTHON="/usr/bin/python3.4" PIP="/usr/bin/python3.4 -m pip"

# Python34: SCL
RUN yum -y install centos-release-scl \
 && yum -y install rh-python34 rh-python34-python-tkinter rh-python34-python-pip
# PYTHON="scl enable rh-python34 python" PIP="scl enable rh-python34 pip"


# OpenJDK
#RUN yum -y install java-1.8.0-openjdk.x86_64  # JRE only
RUN yum -y install java-1.8.0-openjdk-devel.x86_64
ENV JAVA_HOME=/etc/alternatives/java_sdk_1.8.0

# Python Javabridge
RUN python3.4 -m pip install numpy \
 && python3.4 -m pip install javabridge

# Pyjnius
RUN cd pyjnius && python3.4 setup.py install && cd .. \
 && cd json2html && python3.4 setup.py install && cd ..
# install pyjnius unittests - requires virtualenv to get right python
#RUN cd pyjnius && yum -y install ant && make

# More python libs
RUN yum -y install libffi-devel libxml2 libxslt-devel libxml2-devel openssl-devel \
 && python3.4 -m pip install cffi cython future gitdb GitPython pyOpenSSL pytz requests

# python virtual env (otherwise fails to find libxml/xmlversion.h
RUN python3.4 -m pip install virtualenv \
 && mkdir /opt/virtualenv && cd /opt/virtualenv \
 && virtualenv py34 --python python3.4 --system-site-packages \
 && source py34/bin/activate

# Smart Card support
# Need dbus running for USB interface -> https://github.com/CentOS/sig-cloud-instance-images/issues/22
ENV container docker
RUN yum -y swap -- remove systemd-container systemd-container-libs -- install systemd systemd-libs \
 && yum -y opensc pcsc-lite usbutils \
 && systemctl enable  pcscd.service
# install MOCCA (+Jaba Webstart, pcsc)

RUN yum -y install icedtea-web pcsc-lite usbutils \
 && curl -O http://webstart.buergerkarte.at/mocca/webstart/mocca.jnlp

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

# For development/debugging - map port in config and start sshd with /start_sshd.sh
#RUN yum -y install openssh-server \
# && mkdir -p /opt/ssh/ && chown $USERNAME /opt/ssh \
# && echo changeit | passwd -f --stdin $USERNAME \
# && echo changeit | passwd -f --stdin root
#VOLUME /etc/sshd
#EXPOSE 2022


USER $USERNAME
CMD ["/start.sh"]

