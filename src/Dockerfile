# Single-module build. Three static binaries: oci-pull-bills (orchestrator),
# oci-load-bills (DB loader), oci-pull-advisor (Cloud Advisor snapshot).
# Runtime: FROM scratch.

FROM golang:1.26.3-alpine AS build
WORKDIR /src
COPY . .
# -mod=vendor: build offline from vendored deps (corp proxy breaks module fetch)
RUN CGO_ENABLED=0 GOOS=linux go build -mod=vendor -trimpath -ldflags="-s -w" -o /out/oci-load-bills ./cmd/oci-load-bills \
 && CGO_ENABLED=0 GOOS=linux go build -mod=vendor -trimpath -ldflags="-s -w" -o /out/oci-pull-bills ./cmd/oci-pull-bills \
 && CGO_ENABLED=0 GOOS=linux go build -mod=vendor -trimpath -ldflags="-s -w" -o /out/oci-pull-advisor ./cmd/oci-pull-advisor

# Rootfs helper: CA bundle, /etc/passwd, writable dirs.
# No apk (corp proxy breaks apk TLS): alpine base already ships the CA bundle,
# and Go falls back to UTC without tzdata.
FROM alpine:3.20 AS rootfs
RUN mkdir -p /rootfs/data /rootfs/tmp /rootfs/home/app/.oci /rootfs/etc/ssl/oci /rootfs/etc/oci-costing /rootfs/etc/ssl/certs \
 && echo 'app:x:1000:1000:app:/home/app:/sbin/nologin' > /rootfs/etc/passwd \
 && echo 'app:x:1000:' > /rootfs/etc/group \
 && cp /etc/ssl/certs/ca-certificates.crt /rootfs/etc/ssl/certs/ca-certificates.crt \
 && chown -R 1000:1000 /rootfs/data /rootfs/tmp /rootfs/home/app

FROM scratch
COPY --from=rootfs /rootfs/ /
COPY --from=build /out/oci-pull-bills /oci-pull-bills
COPY --from=build /out/oci-load-bills /oci-load-bills
COPY --from=build /out/oci-pull-advisor /oci-pull-advisor
COPY tags.yaml /etc/oci-costing/tags.yaml
COPY NOTICE /NOTICE

ENV OCI_LOAD_BILLS_BIN=/oci-load-bills \
    OCI_DATA_DIR=/data \
    TAGS_CONFIG=/etc/oci-costing/tags.yaml \
    DB_SSLROOTCERT=/etc/ssl/oci/dbsystem.pub \
    HOME=/home/app \
    TZ=UTC

USER 1000:1000
ENTRYPOINT ["/oci-pull-bills"]
