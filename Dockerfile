# syntax=docker/dockerfile:1
FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

# ---- Base OS deps & tools ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    sudo \
    tini \
    ripgrep \
    fd-find \
    jq \
    less \
    openssh-client \
    build-essential \
    pkg-config \
    python3 \
    python3-pip \
    python3-venv \
    pipx \
    locales \
  && rm -rf /var/lib/apt/lists/*

# ---- Node.js 22 LTS via NodeSource ----
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/*

# Optional: nicer locale behavior
RUN sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
 && locale-gen
ENV LANG=en_US.UTF-8

# Debian calls fd as fdfind; add a friendly symlink
RUN ln -sf "$(command -v fdfind)" /usr/local/bin/fd

# ---- Create "normal user" ----
ARG USERNAME=agent
ARG UID=1000
ARG GID=1000

RUN groupadd -g ${GID} ${USERNAME} \
 && useradd -m -u ${UID} -g ${GID} -s /bin/bash ${USERNAME} \
 && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
 && chmod 0440 /etc/sudoers.d/${USERNAME}

# Workspace and helper mount points
RUN mkdir -p /workspace /reads \
 && chown -R ${USERNAME}:${USERNAME} /workspace /reads

ENV HOME=/home/agent \
    PATH=/home/agent/.local/bin:/home/agent/.cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

USER ${USERNAME}
WORKDIR /workspace

# ---- Install uv (via pipx) + rustup (user install) ----
RUN pipx install uv

RUN npm config set prefix /home/agent/.local \
 && npm install -g @mariozechner/pi-coding-agent

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --profile minimal \
 && /home/agent/.cargo/bin/rustup toolchain install stable

# tini handles signals well (important for interactive TUIs)
ENTRYPOINT ["/usr/bin/tini","-s","--"]
CMD ["bash"]
