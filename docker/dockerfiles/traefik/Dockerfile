FROM ubuntu:18.04

RUN apt-get update && apt-get install -y \
    curl \
    iproute2 \
    iptables \
    iputils-ping \
    net-tools \
    procps

RUN groupadd -r traefik && useradd --no-log-init -r -g traefik traefik

USER traefik

COPY --chown=traefik:traefik . /opt/traefik-ingress-controller
RUN chmod -R 755 /opt/traefik-ingress-controller

ENV KUBERNETES_SERVICE_HOST=kubernetes.default.svc.cluster.local \
    KUBERNETES_SERVICE_PORT=443 \
    POD_NAME=traefik-ingress-controller \
    POD_NAMESPACE=default

EXPOSE 80 443

WORKDIR /opt/traefik-ingress-controller

CMD ["/opt/traefik-ingress-controller/traefik"]
