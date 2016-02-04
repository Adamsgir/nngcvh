FROM tmate-java

ARG MAVEN_VERSION=3.3.9

RUN \
    apt-get update && apt-get install -y \
        curl

RUN \
    curl -fsSLk https://archive.apache.org/dist/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz | tar xzf - -C /usr/share && \
    ln -s /usr/share/apache-maven-$MAVEN_VERSION /usr/share/maven
