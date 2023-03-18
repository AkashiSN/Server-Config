FROM alpine AS download

ENV KUBE_VERSION="v1.26.3"

RUN apk --update add curl && \
    curl -L "https://storage.googleapis.com/kubernetes-release/release/${KUBE_VERSION}/bin/linux/amd64/kubectl" -o /kubectl && \
    chmod +x /kubectl

FROM gcr.io/distroless/static-debian11

COPY --from=download /kubectl /

ENTRYPOINT ["/kubectl"]