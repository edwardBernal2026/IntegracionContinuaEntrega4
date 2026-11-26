# Jenkins LTS (Java 21) + cliente Docker (con buildx y compose) + plugins preinstalados
FROM jenkins/jenkins:lts-jdk21
USER root
# Cliente Docker y sus plugins copiados desde la imagen oficial docker:cli
COPY --from=docker:cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker:cli /usr/local/libexec/docker/cli-plugins/docker-buildx /usr/local/libexec/docker/cli-plugins/docker-buildx
COPY --from=docker:cli /usr/local/libexec/docker/cli-plugins/docker-compose /usr/local/libexec/docker/cli-plugins/docker-compose
USER jenkins
# Plugins: se instalan al construir la imagen (instalación reproducible, sin asistente)
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
# Configuration as Code: ".override" hace que se aplique la versión de la imagen en cada arranque
COPY jenkins.yaml /usr/share/jenkins/ref/casc/jenkins.yaml.override
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc/jenkins.yaml
