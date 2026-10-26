# Local Jenkins for trying Jenkinsfiles of any project. Built and run by bin/jenkins-local.
FROM jenkins/jenkins:lts

# `agent { docker { ... } }` shells out to the docker CLI; the daemon is the host's,
# through the mounted socket.
COPY --from=docker:29-cli /usr/local/bin/docker /usr/local/bin/docker

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# No setup wizard (casc.yaml, written by jenkins-local, configures everything), and let
# jobs clone the local snapshot repos over file://, which the git plugin refuses by default.
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false -Dhudson.plugins.git.GitSCM.ALLOW_LOCAL_CHECKOUT=true"
