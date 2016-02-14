FROM scratch

ARG USER=dev
ARG GROUP=dev
ARG GID=1001
ARG UID=1001

ARG HOME_DIR=/home/$USER

RUN \
    groupadd -g $GID $USER && \
    useradd -d $HOME_DIR -m -u $UID -g $GID $USER

USER $USER