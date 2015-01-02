FROM fedora:latest
MAINTAINER Patrik Martinsson <patrik.martinsson>

# Make sure we are up to date, and got the packaging tools in place, 
RUN yum update  -y && \
    yum install -y fedora-packager wget 

# Set up the ~/rpmbuild-directory-structure, 
RUN rpmdev-setuptree

# Get the current release of tcp-monitor, 
RUN cd ~/rpmbuild/SOURCES/ && \
    wget https://github.com/patchon/tcp_monitor/archive/tcp_monitor-1.5.tar.gz

# Get the spec, 
RUN cd ~/rpmbuild/SPECS/ && \
    wget https://raw.githubusercontent.com/patchon/tcp_monitor/master/tcp_monitor.spec

# Download build-dependencies (they are already met, but we could add 
# dependencies in the future), and build the actual rpm, 
RUN yum-builddep -y ~/rpmbuild/SPECS/tcp_monitor.spec && \
    rpmbuild -ba ~/rpmbuild/SPECS/tcp_monitor.spec

# Install it, 
RUN yum install -y /root/rpmbuild/RPMS/noarch/tcp_monitor-1.5-1.fc21.noarch.rpm
