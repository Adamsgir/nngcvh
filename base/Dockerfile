FROM debian:jessie

ARG USER=vagrant
ARG UID=1000
ARG GUID=1000

RUN groupadd -g 1000 $USER
RUN useradd -ms /bin/bash -u $USID -g $GUID $USER

ENV HOME /home/$USER
