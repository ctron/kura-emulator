FROM centos:7

MAINTAINER Jens Reimann <jreimann@redhat.com>
LABEL maintainer="Jens Reimann <jreimann@redhat.com>" \
      io.k8s.description="Containerized version of the Eclipse Kura™ IoT gateway" \
      io.openshift.non-scalable=true

ARG GIT_REPO=https://github.com/eclipse/kura.git
ARG GIT_BRANCH=develop
ARG KURA_COMMIT=d0420e8c7c16477ed47cdf014576ef6917bb0b69
ARG PACKED=false

ENV \
  GIT_REPO=${GIT_REPO:-https://github.com/eclipse/kura.git} \
  GIT_BRANCH=${GIT_BRANCH:-develop} \
  KURA_COMMIT=${KURA_COMMIT:-d0420e8c7c16477ed47cdf014576ef6917bb0b69} \
  JAVA_HOME=/usr/lib/jvm/jre-1.8.0 \
  MAVEN_PROPS=-DskipTests \
  KURA_DIR=/opt/eclipse/kura \
  LAUNCHER_VERSION="1.4.0.v20161219-1356"

RUN \
    echo "$GIT_REPO / $GIT_BRANCH / $KURA_COMMIT" && \
    chmod a+x -R /usr/local/bin && \
    yum -y update && \
    yum -y install scl-utils scl-utils-build centos-release-scl && \
    yum -y install git java-1.8.0-openjdk-devel rh-maven35 && \
    git clone "$GIT_REPO" -b "$GIT_BRANCH" && cd kura && git checkout $KURA_COMMIT && \
    git revert -n 2149c3280ae38cd77ca5edc619af2b5e80d5668a && \
    git log -1 && \
    ( \
      cd /kura && \
      `# Replace broken 'nn' script` \
      cp kura/distrib/src/main/sh/extract.sh kura/distrib/src/main/sh/extract_nn.sh && \
      scl enable rh-maven35 "mvn -B -f target-platform/pom.xml clean install $MAVEN_PROPS" && \
      scl enable rh-maven35 "mvn -B -f kura/pom.xml clean install $MAVEN_PROPS -Pspeedup" && \
      scl enable rh-maven35 "mvn -B -f kura/distrib/pom.xml clean install $MAVEN_PROPS -Pintel-up2-centos-7-nn -nsu" \
    ) && \
    ls -la /kura/kura/distrib/target && \
    yum -y history undo last && \
    yum -y install java-1.8.0-openjdk-headless && \
    yum -y install procps zip unzip gzip tar psmisc socat telnet dos2unix openssl net-tools hostname which && \
    yum -y clean all && rm -rf /var/cache/yum && \
    \
    /kura/kura/distrib/target/kura_*-SNAPSHOT_intel-up2-centos-7-nn_installer.sh && \
    chmod a+rw -R /opt/eclipse && \
    find /opt/eclipse -type d | xargs chmod a+x && \
    chmod a+rwx /var/log && \
    `# Test for the existence of the entry point` \
    test -x "${KURA_DIR}/bin/start_kura.sh" && \
    rm -Rf /kura /root/.m2 && \
    install -m 0777 -d "${KURA_DIR}/data" && \
    if [ "$PACKED" == "true" ]; then touch /kura.packed && pack-kura; fi

COPY ./utils /usr/local/bin

RUN \
    unpack-kura && \
    dp-install "https://repo1.maven.org/maven2/de/dentrassi/kura/addons/de.dentrassi.kura.addons.utils.fileinstall/0.6.0/de.dentrassi.kura.addons.utils.fileinstall-0.6.0.dp" && \
    add-config-ini "felix.fileinstall.disableNio2=true" && \
    add-config-ini "felix.fileinstall.dir=/load" && \
    sed -i 's/org.osgi.service.http.port=.*/org.osgi.service.http.port=8080/g' "${KURA_DIR}/framework/config.ini" && \
    pack-kura

EXPOSE 8080

VOLUME ["/load"]

ENTRYPOINT ["/usr/local/bin/kura-entry-point"]
