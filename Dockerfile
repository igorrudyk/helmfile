FROM golang:1.18.0-alpine as builder

RUN apk add --no-cache make git
WORKDIR /workspace/helmfile

COPY go.mod go.sum /workspace/helmfile/
RUN go mod download

COPY . /workspace/helmfile
RUN make static-linux

# -----------------------------------------------------------------------------

FROM alpine:3.13

LABEL org.opencontainers.image.source https://github.com/helmfile/helmfile

RUN apk add --no-cache ca-certificates git bash curl jq openssh-client

ARG HELM_VERSION="v3.8.2"
ARG HELM_SHA256="6cb9a48f72ab9ddfecab88d264c2f6508ab3cd42d9c09666be16a7bf006bed7b"
ARG HELM_LOCATION="https://get.helm.sh"
ARG HELM_FILENAME="helm-${HELM_VERSION}-linux-amd64.tar.gz"

RUN set -x && \
    wget ${HELM_LOCATION}/${HELM_FILENAME} && \
    echo Verifying ${HELM_FILENAME}... && \
    sha256sum ${HELM_FILENAME} | grep -q "${HELM_SHA256}" && \
    echo Extracting ${HELM_FILENAME}... && \
    tar zxvf ${HELM_FILENAME} && mv /linux-amd64/helm /usr/local/bin/ && \
    rm ${HELM_FILENAME} && rm -r /linux-amd64

# using the install documentation found at https://kubernetes.io/docs/tasks/tools/install-kubectl/
# for now but in a future version of alpine (in the testing version at the time of writing)
# we should be able to install using apk add.
# the sha256 sum can be found at https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256
# maybe a good idea to automate in the future?
ENV KUBECTL_VERSION="v1.21.4"
ENV KUBECTL_SHA256="9410572396fb31e49d088f9816beaebad7420c7686697578691be1651d3bf85a"
RUN set -x && \
    curl --retry 5 --retry-connrefused -LO "https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
    sha256sum kubectl | grep ${KUBECTL_SHA256} && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/kubectl

ENV KUSTOMIZE_VERSION="v3.8.8"
ENV KUSTOMIZE_SHA256="175938206f23956ec18dac3da0816ea5b5b485a8493a839da278faac82e3c303"
RUN set -x && \
    curl --retry 5 --retry-connrefused -LO https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz && \
    sha256sum kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz | grep ${KUSTOMIZE_SHA256} && \
    tar zxvf kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz && \
    rm kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz && \
    mv kustomize /usr/local/bin/kustomize

ENV SOPS_VERSION="v3.7.2"
RUN set -x && \
    curl --retry 5 --retry-connrefused -LO https://github.com/mozilla/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.amd64 && \
    chmod +x sops-${SOPS_VERSION}.linux.amd64  && \
    mv sops-${SOPS_VERSION}.linux.amd64 /usr/local/bin/sops

ENV AGE_VERSION="v1.0.0"
RUN set -x && \
    curl --retry 5 --retry-connrefused -LO https://github.com/FiloSottile/age/releases/download/${AGE_VERSION}/age-${AGE_VERSION}-linux-amd64.tar.gz && \
    tar zxvf age-${AGE_VERSION}-linux-amd64.tar.gz && \
    mv age/age /usr/local/bin/age && \
    mv age/age-keygen /usr/local/bin/age-keygen && \
    rm -rf age-${AGE_VERSION}-linux-amd64.tar.gz age

RUN helm plugin install https://github.com/databus23/helm-diff --version v3.3.1 && \
    helm plugin install https://github.com/jkroepke/helm-secrets --version v3.5.0 && \
    helm plugin install https://github.com/hypnoglow/helm-s3.git --version v0.10.0 && \
    helm plugin install https://github.com/aslafy-z/helm-git.git --version v0.10.0

# Allow users other than root to use helm plugins located in root home
RUN chmod 751 /root

COPY --from=builder /workspace/helmfile/dist/helmfile_linux_amd64 /usr/local/bin/helmfile

CMD ["/usr/local/bin/helmfile"]
