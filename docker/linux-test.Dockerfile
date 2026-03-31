FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        file \
        git \
        jq \
        python3 \
        rsync \
        unzip \
        xz-utils \
        zsh \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /repo
COPY . /repo

CMD ["bash"]
