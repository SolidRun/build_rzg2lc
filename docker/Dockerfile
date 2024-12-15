# use ubuntu base
FROM ubuntu:24.04

# retry at least 3 times to succeed on sketchy connections
RUN printf 'Acquire::http { Proxy "%s"; };\n' $APTPROXY | tee -a /etc/apt/apt.conf.d/proxy

# apt proxy (optional)
ARG APTPROXY=
RUN printf 'Acquire::Retries 3;\n' | tee -a /etc/apt/apt.conf.d/retry || true

# prevent dpkg interactive dialogues
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get --no-install-recommends -y install bash git \
	bc bison build-essential coccinelle ccache \
	device-tree-compiler dfu-util efitools flex gdisk graphviz imagemagick \
	liblz4-tool libgnutls28-dev libguestfs-tools libncurses-dev \
	libpython3-dev libsdl2-dev libssl-dev lz4 lzma lzma-alone openssl \
	pkg-config python3 python3-asteval python3-coverage python3-filelock \
	python3-pkg-resources python3-pycryptodome python3-pyelftools \
	python3-pytest python3-pytest-xdist python3-sphinxcontrib.apidoc \
	python3-sphinx-rtd-theme python3-subunit python3-testtools \
	python3-virtualenv swig uuid-dev u-boot-tools dosfstools python3-libfdt \
	qemu-system-arm e2tools bmap-tools patch fakeroot debootstrap unzip rsync

# build environment
WORKDIR /work
COPY shflags /
COPY entry.sh /
ENTRYPOINT ["/bin/sh", "/entry.sh"]
