FROM jenkins/jenkins:lts-jdk17

# Disable setup wizard — CasC takes over
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"
ENV CASC_JENKINS_CONFIG="/var/jenkins_home/casc_configs"

# Install plugins from plugins.txt
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli \
    --plugin-file /usr/share/jenkins/ref/plugins.txt \
    --verbose

# Copy CasC config into the image
COPY jenkins.yaml /var/jenkins_home/casc_configs/jenkins.yaml

USER jenkins