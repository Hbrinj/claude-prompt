FROM node:lts-slim

ARG GO_VERSION=1.23.4
ARG TARGETARCH

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      python3 \
      python3-pip \
      build-essential \
      jq \
 && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    case "${TARGETARCH:-$(dpkg --print-architecture)}" in \
      amd64) GO_ARCH=amd64 ;; \
      arm64) GO_ARCH=arm64 ;; \
      *)     echo "unsupported arch: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz" -o /tmp/go.tgz; \
    tar -C /usr/local -xzf /tmp/go.tgz; \
    rm /tmp/go.tgz
# Reuse the `node` user (uid 1000) already provided by node:lts-slim instead of
# adding a second uid-1000 account.
ENV HOME=/home/node
ENV GOPATH=/home/node/go
ENV PATH=/usr/local/go/bin:/home/node/go/bin:$PATH

RUN npm install -g @anthropic-ai/claude-code

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN mkdir -p /workspace && chown node:node /workspace
WORKDIR /workspace

# claude CLI refuses --dangerously-skip-permissions when running as root.
# Default to a non-root user; Linux dispatch overrides via --user $(id -u):$(id -g)
# (see scripts/dispatch-docker-worker.sh) and provides its own HOME/GOPATH overrides.
USER node

CMD ["/entrypoint.sh"]
