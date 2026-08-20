#!/bin/bash
set -euo pipefail

AGENT_USER="agent001"
AGENT_HOME="/home/agent001"
AGENT_WORKDIR="/home/agent001/workspace"

# ============================================================
# Java
# ============================================================

sudo apt update
sudo apt install -y openjdk-21-jre openjdk-21-jdk

# ============================================================
# Docker
# ============================================================

sudo apt install -y ca-certificates curl

sudo install -m 0755 -d /etc/apt/keyrings

sudo curl -fsSL \
  https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc

sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "$${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update

sudo apt install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

sudo systemctl enable docker
sudo systemctl start docker

# ============================================================
# Jenkins Agent user
# ============================================================

sudo useradd \
  -m \
  -d "$${AGENT_HOME}" \
  -s /bin/bash \
  "$${AGENT_USER}" || true

sudo usermod -aG docker "$${AGENT_USER}"

sudo mkdir -p "$${AGENT_WORKDIR}"

sudo chown -R \
  "$${AGENT_USER}:$${AGENT_USER}" \
  "$${AGENT_HOME}"

# ============================================================
# SSH
# ============================================================

sudo mkdir -p "$${AGENT_HOME}/.ssh"

sudo tee "$${AGENT_HOME}/.ssh/authorized_keys" > /dev/null <<'KEYEOF'
${public_key}
KEYEOF

sudo chmod 700 "$${AGENT_HOME}/.ssh"
sudo chmod 600 "$${AGENT_HOME}/.ssh/authorized_keys"

sudo chown -R \
  "$${AGENT_USER}:$${AGENT_USER}" \
  "$${AGENT_HOME}/.ssh"

echo "=============================================="
echo "Jenkins Agent installation complete"
echo "User: $${AGENT_USER}"
echo "Workspace: $${AGENT_WORKDIR}"
echo "=============================================="
