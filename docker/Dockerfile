# use ubuntu base
FROM ubuntu:focal

# retry at least 3 times to succeed on sketchy connections
RUN printf 'Acquire::http { Proxy "%s"; };\n' $APTPROXY | tee -a /etc/apt/apt.conf.d/proxy

# apt proxy (optional)
ARG APTPROXY=
RUN printf 'Acquire::Retries 3;\n' | tee -a /etc/apt/apt.conf.d/retry || true

# prevent dpkg interactive dialogues
ENV DEBIAN_FRONTEND=noninteractive

# update
RUN set -e; \
	apt-get update; \
	apt-get -y upgrade; \
	:

RUN set -e; \
	apt-get update; \
	apt-get --no-install-recommends -y install bash bc binutils bison build-essential chrpath coreutils cpio device-tree-compiler diffstat dosfstools e2fsprogs e2tools file flex g++ gawk gcc git kmod libncurses5-dev libncursesw5-dev libssl-dev make meson mtools ninja-build p7zip p7zip-full parted patch python python2 python3 python3-pip python3-pyelftools rsync sed sudo tar texinfo u-boot-tools udev unzip util-linux wget genext2fs debootstrap fakeroot qemu-system-aarch64 ccache; \
	:

# build environment
WORKDIR /work
COPY shflags /
COPY entry.sh /
ENTRYPOINT ["/bin/sh", "/entry.sh"]
