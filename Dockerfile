FROM registry.fedoraproject.org/fedora:38
LABEL name="art-tools-dev" \
  description="art-tools development container image" \
  maintainer="OpenShift Automated Release Tooling (ART) Team <aos-team-art@redhat.com>"

ENV \
  ELLIOTT_DATA_PATH=https://github.com/openshift-eng/ocp-build-data \
  DOOZER_DATA_PATH=https://github.com/openshift-eng/ocp-build-data \
  PATH="/usr/local/go/bin:$PATH"

ARG \
  OC_VERSION=latest \
  GO_VERSION=1.24.4 \
  ACT_VERSION=v0.2.78 \
  USERNAME=dev \
  USER_UID=1000 \
  USER_GID=1000

# Trust the Red Hat IT Root CAs and set up rcm-tools repo
COPY Current-IT-Root-CAs.pem /etc/pki/ca-trust/source/anchors/IT-Root-CAs.pem
COPY rcm-tools-fedora.repo /etc/yum.repos.d/rcm-tools-fedora.repo
RUN update-ca-trust extract

# Install system packages
RUN dnf install -y \
  # runtime dependencies
  krb5-workstation git tig rsync koji skopeo podman docker rpmdevtools \
  python3.11 python3-certifi python-bugzilla-cli \
  # nice to have tools
  jq tree findutils expect \
  # provides en_US.UTF-8 locale
  glibc-langpack-en \
  # development dependencies
  gcc gcc-c++ krb5-devel \
  python3-devel python3-pip python3-wheel python3-autopep8 \
  # other tools for development and troubleshooting
  bash-completion vim tmux procps-ng psmisc wget net-tools iproute socat \
  # install rcm-tools
  koji brewkoji rhpkg \
  && dnf clean all \
  && ln -sfn /usr/bin/python3 /usr/bin/python

# Set locale AFTER installing glibc-langpack-en
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8
RUN echo "en_US.UTF-8" > /etc/locale.conf

# Include oc client
COPY openshift-client-linux.tar.gz /tmp/
RUN tar -C /usr/local/bin -xzf /tmp/openshift-client-linux.tar.gz oc kubectl \
  && rm /tmp/openshift-client-linux.tar.gz

# Install golang from source
RUN wget -O /tmp/go${GO_VERSION}.linux-amd64.tar.gz https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz \
  && rm -rf /usr/local/go \
  && tar -C /usr/local -xzf /tmp/go${GO_VERSION}.linux-amd64.tar.gz \
  && rm /tmp/go${GO_VERSION}.linux-amd64.tar.gz

# install act CLI
RUN curl -sSfL -o act.tar.gz https://github.com/nektos/act/releases/download/${ACT_VERSION}/act_Linux_x86_64.tar.gz && \
  tar -xzf act.tar.gz && \
  mv act /usr/local/bin/act && \
  chmod +x /usr/local/bin/act && \
  rm act.tar.gz

# Locale is now properly configured after installing glibc-langpack-en

# Create the "dev" user with necessary permissions and directories
RUN groupadd --gid "$USER_GID" "$USERNAME" \
  && useradd --uid "$USER_UID" --gid "$USER_GID" -m "$USERNAME" \
  && mkdir -p /workspaces/{art-tools,ocp-build-data,doozer-working-dir,elliott-working-dir} \
  && chown -R "$USER_UID:$USER_GID" /home/"$USERNAME" /workspaces \
  && chmod 0755 /home/"$USERNAME" \
  && echo "$USERNAME ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/"$USERNAME" \
  && chmod 0440 /etc/sudoers.d/"$USERNAME"

# Configure Kerberos
COPY artcommon/configs/krb5-redhat.conf /etc/krb5.conf.d/

WORKDIR /workspaces/art-tools
ADD . .

RUN chown -R "$USERNAME:$USER_GID" /workspaces/art-tools

# Use pip to install Python dependencies and packages in editable mode
USER root
RUN pip3 install --ignore-installed -U "pip>=22.3" "setuptools>=64" \
  && pip3 install --ignore-installed ruff pylint pytest flexmock click jsonschema schema \
  && pip3 install --ignore-installed -e ./artcommon -e ./doozer -e ./elliott -e ./pyartcd -e ./ocp-build-data-validator

USER "$USER_UID"

# Set the entry point to bash for interactive use
CMD ["/bin/bash"]