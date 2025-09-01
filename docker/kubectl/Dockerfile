FROM alpine AS download

ENV KUBE_VERSION="v1.34.0"

RUN apk --update add curl && \
    curl -L "https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/amd64/kubectl" -o /kubectl && \
    chmod +x /kubectl

FROM gcr.io/distroless/static-debian11

COPY --from=download /kubectl /

ENTRYPOINT ["/kubectl"]