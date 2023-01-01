FROM quay.io/almalinux/almalinux:9.1-20221201
LABEL maintainer="Adam W Zheng <adam.w.zheng@icloud.com>"

ARG UID=30000
ARG GID=30000
ARG S6_OVERLAY_VERSION=3.1.2.1
ARG PROMETHEUS_CPP_VERSION=1.1.0
ARG IRRLICHTMT_TAG=1.9.0mt8
ARG MINETEST_TAG=5.6.1

# Disable service timeout
ENV S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0

# Add s6-overlay process supervisor
ADD ["https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz", "/tmp"]
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
ADD ["https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz", "/tmp"]
RUN tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz

# Enable CRB
RUN dnf update -y \
 && dnf install -y epel-release dnf-plugins-core \
 && dnf config-manager --enable crb

# Install minetestserver build dependencies
RUN dnf install -y doxygen hiredis-devel libpq-devel gettext-devel libjpeg-devel git make automake gcc gcc-c++ kernel-devel cmake libcurl-devel openal-soft-devel libvorbis-devel libXi-devel libogg-devel freetype-devel mesa-libGL-devel zlib-devel jsoncpp-devel gmp-devel sqlite-devel luajit-devel leveldb-devel ncurses-devel spatialindex-devel libzstd-devel

# Clone and Build Prometheus Client Library
RUN git clone --depth 1 --branch v${PROMETHEUS_CPP_VERSION} --single-branch --recursive https://github.com/jupp0r/prometheus-cpp.git /usr/local/share/prometheus-cpp \
 && mkdir /usr/local/share/prometheus-cpp/build \
 && cd /usr/local/share/prometheus-cpp/ \
 && cmake /usr/local/share/prometheus-cpp/ -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Release -DENABLE_TESTING=0 \
 && make -j$(nproc)

# Clone and Build Irrlicht MT, and Minetest
RUN git clone --depth 1 --branch ${MINETEST_TAG} --single-branch https://github.com/minetest/minetest.git /usr/local/share/minetest \
 && git clone --depth 1 --branch ${IRRLICHTMT_TAG} --single-branch https://github.com/minetest/irrlicht.git /usr/local/share/minetest/lib/irrlichtmt \
 && cd /usr/local/share/minetest \
 && cmake . -DBUILD_SERVER=TRUE -DRUN_IN_PLACE=FALSE -DBUILD_CLIENT=FALSE -DCMAKE_BUILD_TYPE=RELEASE -DENABLE_PROMETHEUS=ON \
 && make -j$(nproc)

# Copy s6-supervisor source definition directory into the container
COPY ["etc/s6-overlay/", "/etc/s6-overlay/"]

# Cleanup
RUN dnf -y update && dnf clean all && rm -rf /var/cache/yum && > /var/log/yum.log

# Create minetest user and group
RUN groupadd -g "${GID}" minetest \
 && useradd -u "${UID}" minetest -g "${GID}"

# Create and set working dir to variable games
RUN mkdir /var/games/minetest-server \
 && chown -R minetest:minetest /var/games/minetest-server

# Port Metadata for Minetest (30000/udp) and Prometheus (30000/tcp)
EXPOSE 30000/tcp
EXPOSE 30000/udp

# Set default user
USER minetest:minetest

# Set working dir to variable games
WORKDIR /var/games/minetest-server

ENTRYPOINT ["/init"]
