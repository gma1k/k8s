FROM ubuntu
ARG KUBECTL_VERSION=1.15.6
ARG HELM_VERSION=3.0.2
ARG HELM_DIFF_VERSION=v3.0.0-rc.7
ARG HELMFILE_VERSION=0.98.1
ARG EKSCTL_VERSION=0.11.1
ENV NODE_VERSION=12.6.0
ENV HELM_FILE_NAME helm-v${HELM_VERSION}-linux-amd64.tar.gz
WORKDIR /
RUN apt-get update -qq && \
  apt-get install -qqy --no-install-recommends \
  apt-transport-https \
  build-essential \
  curl \
  ca-certificates \
  coreutils \
  git \
  gnupg \
  gettext \
  lsb-release \
  python3 \
  python3-pip \
  python3-setuptools \
  rlwrap \
  vim \
  nano \
  groff \
  jq && \
  curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/microsoft.asc.gpg > /dev/null && \
  AZ_REPO=$(lsb_release -cs) && echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | tee /etc/apt/sources.list.d/azure-cli.list && \
  apt-get update -qq && apt-get install -qqy azure-cli && rm -rf /var/lib/apt/lists/* && \
  curl -Lo /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl && chmod +x /usr/local/bin/kubectl && \
  curl -Lo /tmp/${HELM_FILE_NAME} https://get.helm.sh/${HELM_FILE_NAME} && tar -zxvf /tmp/${HELM_FILE_NAME} -C /tmp && mv /tmp/linux-amd64/helm /bin/helm && rm -rf /tmp/* && \
  helm plugin install https://github.com/databus23/helm-diff --version ${HELM_DIFF_VERSION} && \
  curl -Lo /usr/local/bin/helmfile https://github.com/roboll/helmfile/releases/download/v${HELMFILE_VERSION}/helmfile_linux_amd64 && chmod +x /usr/local/bin/helmfile && \
  curl -Lo /tmp/eksctl_Linux_amd64.tar.gz https://github.com/weaveworks/eksctl/releases/download/${EKSCTL_VERSION}/eksctl_Linux_amd64.tar.gz && tar -zxvf /tmp/eksctl_Linux_amd64.tar.gz -C /tmp && mv /tmp/eksctl /bin/eksctl && rm -rf /tmp/* && \
  pip3 install --upgrade --no-cache-dir awscli && \
  ENV PATH $PATH:/root/google-cloud-sdk/bin && \
  curl -Lo /usr/local/bin/aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/1.12.7/2019-03-27/bin/linux/amd64/aws-iam-authenticator && chmod +x /usr/local/bin/aws-iam-authenticator && \
  curl -Lo /usr/local/bin/yaml2json https://github.com/wakeful/yaml2json/releases/latest/download/yaml2json-linux-amd64 && chmod +x yaml2json
CMD "/bin/bash"
