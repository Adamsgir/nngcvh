FROM tmate-java

ARG ATLASSIAN_SDK_VERSION=6.2.2

RUN \
    apt-get update && apt-get install -y \
         apt-transport-https
RUN \
    (echo "deb https://sdkrepo.atlassian.com/debian/ stable contrib" | tee /etc/apt/sources.list.d/atlassian-sdk.list) && \
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys B07804338C015B73

RUN \
    apt-get update && \
    apt-get install -y \
        atlassian-plugin-sdk=$ATLASSIAN_SDK_VERSION \
        oracle-java8-set-default
