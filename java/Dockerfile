FROM tmate-base

RUN \
  (echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" | tee /etc/apt/sources.list.d/webupd8team-java.list) && \
  (echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" | tee -a /etc/apt/sources.list.d/webupd8team-java.list) && \
  apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys EEA14886 && \
  apt-get update

RUN \
  echo oracle-java6-installer shared/accepted-oracle-license-v1-1 select true | debconf-set-selections && \
  apt-get install -y oracle-java6-installer

RUN \
  echo oracle-java7-installer shared/accepted-oracle-license-v1-1 select true | debconf-set-selections && \
  apt-get install -y oracle-java7-installer

RUN \
  echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | debconf-set-selections && \
  apt-get install -y oracle-java8-installer

RUN \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf /var/cache/oracle-jdk6-installer && \
  rm -rf /var/cache/oracle-jdk7-installer && \
  rm -rf /var/cache/oracle-jdk8-installer
