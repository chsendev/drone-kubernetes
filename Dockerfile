FROM alpine:3.4
RUN apk add --no-cache \
        curl \
        ca-certificates \
        bash \
    && KUBECTL_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt) \
    && curl -Lo /usr/local/bin/kubectl \
        "https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && chmod +x /usr/local/bin/kubectl \
    && apk del curl \
    && rm -rf /var/cache/apk/*
COPY update.sh /bin/
ENTRYPOINT ["/bin/bash"]
CMD ["/bin/update.sh"]
