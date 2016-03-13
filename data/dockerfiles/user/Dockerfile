# User Dockerfile
FROM debian:jessie

ARG name=dev
ARG group=$name
ARG gid=1001
ARG uid=1001

ARG home=/home/$name

RUN \
    groupadd -g $gid $group && \
    useradd -d $home -m -u $uid -g $gid $name

USER $name