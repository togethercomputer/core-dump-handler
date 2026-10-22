FROM docker.io/alpine:3.22 as builder

ARG ARCH

RUN apk update && apk add curl binutils build-base

ARG RUSTUP_VERSION=1.29.2

RUN if [ $ARCH == "amd64" ]; then RUST_TARGET=x86_64-unknown-linux-musl; RUSTUP_SHA256=2ba97d668c06dc4b1884f2a3fa6f4cf14b9bd0c1db379af7e4f87a705ff19edd; fi; \
    if [ $ARCH == "arm64" ]; then RUST_TARGET=aarch64-unknown-linux-musl; RUSTUP_SHA256=7fdbb23acf6495efee2e371580c52b365917551b4835090a225c44ac30915235; fi; \
    curl -sSfL -o /tmp/rustup-init https://static.rust-lang.org/rustup/archive/${RUSTUP_VERSION}/${RUST_TARGET}/rustup-init && \
    echo "${RUSTUP_SHA256}  /tmp/rustup-init" | sha256sum -c - && \
    chmod +x /tmp/rustup-init && \
    /tmp/rustup-init -y --default-toolchain stable-${RUST_TARGET} && \
    rm /tmp/rustup-init

RUN ls -a /root/.cargo/bin

COPY . /app-build

WORKDIR "/app-build"

ENV PATH=/root/.cargo/bin:${PATH}
RUN cargo build --verbose --release

RUN curl -L https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.22.0/crictl-v1.22.0-linux-$ARCH.tar.gz --output crictl-v1.22.0-linux-$ARCH.tar.gz
RUN tar zxvf crictl-v1.22.0-linux-$ARCH.tar.gz

FROM docker.io/alpine:3.22

RUN apk update && apk add --upgrade ca-certificates procps

WORKDIR "/app"
COPY --from=builder /app-build/target/release/core-dump-agent ./
WORKDIR "/app/vendor/default"
COPY --from=builder /app-build/target/release/core-dump-composer ./
RUN mv core-dump-composer cdc

WORKDIR "/app"
COPY --from=builder /app-build/crictl ./
CMD ["./core-dump-agent"]