FROM ubuntu:jammy as static-compat-test-env
MAINTAINER Martchus <martchus@gmx.net>
LABEL description="Container for testing static-compat packages"

RUN apt-get update && \
    apt-get install --yes libglx0 libopengl0 libegl1
