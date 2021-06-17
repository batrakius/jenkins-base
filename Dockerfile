FROM openjdk:8u292-jdk

RUN apt-get update && apt-get upgrade -y && apt-get install -y git curl && rm -rf /var/lib/apt/lists/*

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000
ARG http_port=8080
ARG agent_port=50000
ARG JENKINS_HOME=/var/jenkins_home
ARG REF=/usr/share/jenkins/ref
ENV JENKINS_HOME $JENKINS_HOME
ENV JENKINS_SLAVE_AGENT_PORT ${agent_port}
ENV REF $REF

# Jenkins is run with user `jenkins`, uid = 1000
# If you bind mount a volume from the host or a data container,
# ensure you use the same uid
RUN mkdir -p $JENKINS_HOME \
  && chown ${uid}:${gid} $JENKINS_HOME \
  && groupadd -g ${gid} ${group} \
  && useradd -d "$JENKINS_HOME" -u ${uid} -g ${gid} -m -s /bin/bash ${user}

# Jenkins home directory is a volume, so configuration and build history
# can be persisted and survive image upgrades
# VOLUME $JENKINS_HOME

# $REF (defaults to `/usr/share/jenkins/ref/`) contains all reference configuration we want
# to set on a fresh new installation. Use it to bundle additional plugins
# or config file with your custom jenkins Docker image.
RUN mkdir -p ${REF}/init.groovy.d

# Use tini as subreaper in Docker container to adopt zombie processes
ARG TINI_VERSION=v0.19.0
COPY tini_pub.gpg ${JENKINS_HOME}/tini_pub.gpg
RUN curl -fsSL https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-$(dpkg --print-architecture) -o /sbin/tini \
  && curl -fsSL https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-$(dpkg --print-architecture).asc -o /sbin/tini.asc \
  && gpg --no-tty --import ${JENKINS_HOME}/tini_pub.gpg \
  && gpg --verify /sbin/tini.asc \
  && rm -rf /sbin/tini.asc /root/.gnupg \
  && chmod +x /sbin/tini

# jenkins version being bundled in this docker image
ARG JENKINS_VERSION
ENV JENKINS_VERSION ${JENKINS_VERSION:-2.289.1}

# jenkins.war checksum, download will be validated using it
#ARG JENKINS_SHA=33a6c3161cf8de9c8729fd83914d781319fd1569acf487c7b1121681dba190a5

# Can be used to customize where jenkins.war get downloaded from
ARG JENKINS_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war

# could use ADD but this one does not check Last-Modified header neither does it allow to control checksum
# see https://github.com/docker/docker/issues/8331
RUN curl -fsSL ${JENKINS_URL} -o /usr/share/jenkins/jenkins.war 
#  && echo "${JENKINS_SHA}  /usr/share/jenkins/jenkins.war" | sha256sum -c -

ENV JENKINS_UC https://updates.jenkins.io
ENV JENKINS_UC_EXPERIMENTAL=https://updates.jenkins.io/experimental
ENV JENKINS_INCREMENTALS_REPO_MIRROR=https://repo.jenkins-ci.org/incrementals
RUN chown -R ${user} "$JENKINS_HOME" "$REF"

# for main web interface:
EXPOSE ${http_port}

# will be used by attached slave agents:
EXPOSE ${agent_port}

ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log


COPY jenkins-support /usr/local/bin/jenkins-support
COPY jenkins.sh /usr/local/bin/jenkins.sh
COPY tini-shim.sh /bin/tini
COPY plugins.sh /usr/local/bin/plugins.sh
COPY install-plugins.sh /usr/local/bin/install-plugins.sh
RUN  set -x \
     && chmod +x /usr/local/bin/jenkins.sh \
     && chmod +x /bin/tini \
     && chmod +x /usr/local/bin/plugins.sh \
     && chmod +x /usr/local/bin/install-plugins.sh

USER ${user}
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN  echo ${JENKINS_VERSION} > ${JENKINS_HOME}/jenkins.install.UpgradeWizard.state \
     && echo ${JENKINS_VERSION} > ${JENKINS_HOME}/jenkins.install.InstallUtil.lastExecVersion \
     && /usr/local/bin/install-plugins.sh < /usr/share/jenkins/ref/plugins.txt

USER root
RUN set -x \
    && apt-get update \
    && apt-get install -y git
    
ENV NODE_VERSION 14.15.3                                                                                                                      
                                                                                                                                              
RUN buildDeps='xz-utils' \                                                                                                                    
    && ARCH= && dpkgArch="$(dpkg --print-architecture)" \                                                                                     
    && case "${dpkgArch##*-}" in \                                                                                                            
      amd64) ARCH='x64';; \                                                                                                                   
      ppc64el) ARCH='ppc64le';; \                                                                                                             
      s390x) ARCH='s390x';; \                                                                                                                 
      arm64) ARCH='arm64';; \                                                                                                                 
      armhf) ARCH='armv7l';; \                                                                                                                
      i386) ARCH='x86';; \                                                                                                                    
      *) echo "unsupported architecture"; exit 1 ;; \                                                                                         
    esac \                                                                                                                                    
    && set -ex \                                                                                                                              
    && apt-get update && apt-get install -y ca-certificates curl wget gnupg dirmngr $buildDeps --no-install-recommends \                      
    && rm -rf /var/lib/apt/lists/* \                                                                                                          
    && for key in \                                                                                                                           
      94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \                                                                                              
      FD3A5288F042B6850C66B31F09FE44734EB7990E \                                                                                              
      71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \                                                                                              
      DD8F2338BAE7501E3DD5AC78C273792F7D83545D \                                                                                              
      C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \                                                                                              
      B9AE9905FFD7803F25714661B63B535A4C206CA9 \                                                                                              
      77984A986EBC2AA786BC0F66B01FBB92821C587A \                                                                                              
      8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \                                                                                              
      4ED778F539E3634C779C87C6D7062848A1AB005C \                                                                                              
      A48C2BEE680E841632CD4E44F07496B3EB3C1762 \                                                                                              
      B9E2F5981AA6E0CD28160D9FF13993A75599653C \                                                                                              
    ; do \                                                                                                                                    
      gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \                                                    
      gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \                                                      
      gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \                                                                     
    done \                                                                                                                                    
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH.tar.xz" \                             
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \                                                 
    && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \                                                                     
    && grep " node-v$NODE_VERSION-linux-$ARCH.tar.xz\$" SHASUMS256.txt | sha256sum -c - \                                                     
    && tar -xJf "node-v$NODE_VERSION-linux-$ARCH.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \                                 
    && rm "node-v$NODE_VERSION-linux-$ARCH.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \                                                        
    && apt-get purge -y --auto-remove $buildDeps \                                                                                            
    && ln -s /usr/local/bin/node /usr/local/bin/nodejs                                                                                        
                                                                                                                                              
ENV YARN_VERSION 1.22.5                                                                                                                       
                                                                                                                                              
RUN set -ex \                                                                                                                                 
  && for key in \                                                                                                                             
    6A010C5166006599AA17F08146C2130DFD2497F5 \                                                                                                
  ; do \                                                                                                                                      
    gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \                                                      
    gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \                                                        
    gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \                                                                       
  done \                                                                                                                                      
  && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \                                      
  && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" \                                  
  && gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \                                                         
  && mkdir -p /opt \                                                                                                                          
  && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/ \                                                                                           
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn \                                                                            
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg \                                                                      
  && rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz                                                                             
                                                                                                                                                                                                                                                                                       
    
ENV UID_ENTRYPOINT /entrypoint.sh
RUN echo '#!/bin/sh\n \
if ! whoami &> /dev/null; then\n \
  if [ -w /etc/passwd ]; then\n \
    echo "${USER_NAME:-default}:x:$(id -u):0:${USER_NAME:-default} user:${JENKINS_HOME}:/bin/bash" >> /etc/passwd\n \
  fi\n \
fi 2>/dev/null\n \
exec "$@"\n' \
>>${UID_ENTRYPOINT}
RUN chmod +x ${UID_ENTRYPOINT} \
    &&  chmod -R g=u /etc/passwd  \
    &&  chmod -R o=u $JENKINS_HOME

ENTRYPOINT ["/entrypoint.sh","/sbin/tini", "--", "/usr/local/bin/jenkins.sh"]
USER 10001
