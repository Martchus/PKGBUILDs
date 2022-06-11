FROM archlinux:base as base
MAINTAINER Martchus <martchus@gmx.net>

RUN mkdir -p /startdir /build && \
    useradd -m -d /build -u 1000 -U -s /bin/bash builduser && \
    chown -R builduser:builduser /build && \
    pacman -Syu --noconfirm --needed base-devel pacman-contrib && \
    pacman -Scc --noconfirm && \
    paccache -r -k0 && \
    rm -rf /usr/share/man/* /tmp/* /var/tmp/*
