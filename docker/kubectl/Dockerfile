FROM alpine AS download

ENV KUBE_VERSION="v1.28.3"

RUN apk --update add curl && \
    curl -L "https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/amd64/kubectl" -o /kubectl && \
    chmod +x /kubectl

FROM gcr.io/distroless/static-debian11

COPY --from=download /kubectl /

ENTRYPOINT ["/kubectl"]