FROM ubuntu:18.04

RUN apt-get update && apt-get install -y \
    curl \
    iproute2 \
    iptables \
    iputils-ping \
    net-tools \
    procps

RUN groupadd -r nginx && useradd --no-log-init -r -g nginx nginx

USER nginx

COPY --chown=nginx:nginx . /opt/nginx-ingress-controller
RUN chmod -R 755 /opt/nginx-ingress-controller

ENV KUBERNETES_SERVICE_HOST=kubernetes.default.svc.cluster.local \
    KUBERNETES_SERVICE_PORT=443 \
    POD_NAME=nginx-ingress-controller \
    POD_NAMESPACE=default

EXPOSE 80 443

WORKDIR /opt/nginx-ingress-controller

CMD ["/opt/nginx-ingress-controller/nginx-ingress"]
