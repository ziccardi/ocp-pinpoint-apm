FROM centos:7
MAINTAINER Marcos Entenza <mak@redhat.com>

LABEL io.k8s.description="Platform for running Pinpoint Application Performance Monitoring" \
      io.k8s.display-name="Pinpoint APM" \
      io.openshift.expose-services="28080:http,28081:http,28082:http" \
      io.openshift.tags="pinpoint-apm"

ENV JAVA_6_HOME /usr/java/jdk1.6.0_45
ENV JAVA_7_HOME /usr/java/jdk1.8.0_181-amd64
ENV JAVA_8_HOME /usr/java/jdk1.8.0_181-amd64
ENV JAVA_HOME /usr/java/jdk1.8.0_181-amd64

COPY src/* /usr/local/src/

RUN cd /usr/local/src/ && \
    cp epel-apache-maven.repo /etc/yum.repos.d/ && \
    rpm -i epel-release-7-8.noarch.rpm && \
    yum install git wget tar hostname lsof net-tools apache-maven -y && \
    wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" https://download.java.net/openjdk/jdk8u40/ri/jdk_ri-8u40-b25-linux-x64-10_feb_2015.tar.gz -O jdk-8u181-linux-x64.rpm && \
    rpm -i jdk-6u45-linux-amd64.rpm --force && \
    rpm -i jdk-8u181-linux-x64.rpm --force && \
    yum clean all && \
    rm -rf jdk-6u45-linux-amd64.rpm jdk-8u181-linux-x64.rpm epel-release-7-8.noarch.rpm

COPY src/howto-startup.sh /root/
COPY src/pinpoint-start.sh /root/

RUN chmod +x /root/howto-startup.sh /root/pinpoint-start.sh && \
    echo "/root/howto-startup.sh" >> /etc/bashrc

RUN git clone https://github.com/naver/pinpoint.git /pinpoint && \
    mkdir /pinpoint/logs
WORKDIR /pinpoint
RUN git checkout tags/1.6.0
RUN mvn install -Dmaven.test.skip=true -B


RUN sed -i '/^CLOSE_WAIT_TIME/c\CLOSE_WAIT_TIME=1000' /pinpoint/quickstart/bin/start-collector.sh && \
    sed -i '/^CLOSE_WAIT_TIME/c\CLOSE_WAIT_TIME=1000' /pinpoint/quickstart/bin/start-web.sh && \
    sed -i '/^CLOSE_WAIT_TIME/c\CLOSE_WAIT_TIME=1000' /pinpoint/quickstart/bin/start-testapp.sh

WORKDIR quickstart/hbase
ADD http://archive.apache.org/dist/hbase/hbase-1.0.3/hbase-1.0.3-bin.tar.gz ./
RUN tar -xf hbase-1.0.3-bin.tar.gz && \
    rm hbase-1.0.3-bin.tar.gz && \
    ln -s hbase-1.0.3 hbase && \
    cp ../conf/hbase/hbase-site.xml hbase-1.0.3/conf/ && \
    chmod +x hbase-1.0.3/bin/start-hbase.sh && \
    chgrp -R root /pinpoint && \
    chmod 775 -R /pinpoint && \
    chmod 775 -R /tmp

RUN /pinpoint/quickstart/bin/start-hbase.sh && \
    /pinpoint/quickstart/bin/init-hbase.sh

RUN chgrp -R root /pinpoint && \
    chmod 775 -R /pinpoint && \
    chmod 775 -R /tmp

EXPOSE 28080 28081 28082

WORKDIR /pinpoint
VOLUME [/pinpoint]

CMD ["sh","/root/pinpoint-start.sh"]
#CMD ["sleep","1000000"]
