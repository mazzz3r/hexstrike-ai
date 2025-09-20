# syntax=docker/dockerfile:1

FROM nixos/nix:2.21.2

# The base nixos/nix image does not provide /bin/bash; invoke bash via env
SHELL ["/usr/bin/env", "bash", "-euo", "pipefail", "-c"]

ENV NIX_CONFIG="experimental-features = nix-command flakes" \
    NIXPKGS_ALLOW_UNFREE=1 \
    NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1 \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PATH=/root/.nix-profile/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

ARG ZAP_VERSION=2.15.0
ARG GHIDRA_VERSION=10.4
ARG GHIDRA_DIST=ghidra_10.4_PUBLIC_20230928

# Configure nixpkgs channels and update package metadata
RUN nix-channel --add https://nixos.org/channels/nixos-24.05 nixpkgs \
    && nix-channel --add https://nixos.org/channels/nixos-unstable nixos-unstable \
    && nix-channel --update

# Base utilities, compilers, Python runtime, browsers, and runtime support
RUN nix-env -iA \
    nixpkgs.bash \
    nixpkgs.coreutils \
    nixpkgs.cacert \
    nixpkgs.findutils \
    nixpkgs.gawk \
    nixpkgs.gnutar \
    nixpkgs.gzip \
    nixpkgs.unzip \
    nixpkgs.xz \
    nixpkgs.zip \
    nixpkgs.curl \
    nixpkgs.wget \
    nixpkgs.git \
    nixpkgs.procps \
    nixpkgs.nettools \
    nixpkgs.iproute2 \
    nixpkgs.iputils \
    nixpkgs.ncurses \
    nixpkgs.which \
    nixpkgs.gnumake \
    nixpkgs.pkg-config \
    nixpkgs.gcc \
    nixpkgs.zlib \
    nixpkgs.openssl \
    nixpkgs.libffi \
    nixpkgs.python311Full \
    nixpkgs.mitmproxy \
    nixpkgs.chromium \
    nixpkgs.chromedriver \
    nixpkgs.nodejs_20 \
    nixpkgs.jdk17

# Install core security tooling leveraged by HexStrike AI agents
RUN nix-env -iA \
    nixpkgs.nmap \
    nixpkgs.masscan \
    nixpkgs.rustscan \
    nixpkgs.amass \
    nixpkgs.subfinder \
    nixpkgs.nuclei \
    nixpkgs.fierce \
    nixpkgs.dnsenum \
    nixpkgs.theharvester \
    nixpkgs.responder \
    nixpkgs.netexec \
    nixpkgs.enum4linux-ng \
    nixpkgs.arp-scan \
    nixpkgs.nbtscan \
    nixpkgs.samba \
    nixpkgs.gobuster \
    nixpkgs.feroxbuster \
    nixpkgs.ffuf \
    nixpkgs.dirb \
    nixpkgs.httpx \
    nixpkgs.katana \
    nixpkgs.nikto \
    nixpkgs.sqlmap \
    nixpkgs.wpscan \
    nixpkgs.dalfox \
    nixpkgs.wafw00f \
    nixpkgs.sslscan \
    nixpkgs.thc-hydra \
    nixpkgs.john \
    nixpkgs.hashcat \
    nixpkgs.medusa \
    nixpkgs.crackmapexec \
    nixpkgs.evil-winrm \
    nixpkgs.hash-identifier \
    nixpkgs.radare2 \
    nixpkgs.gdb \
    nixpkgs.binwalk \
    nixpkgs.ropgadget \
    nixpkgs.checksec \
    nixpkgs.volatility3 \
    nixpkgs.foremost \
    nixpkgs.steghide \
    nixpkgs.exiftool \
    nixpkgs.trivy \
    nixpkgs.checkov \
    nixpkgs.wfuzz \
    nixpkgs.commix \
    nixpkgs.whatweb \
    nixpkgs.burpsuite \
    nixpkgs.kube-hunter \
    nixpkgs.kube-bench \
    nixpkgs.metasploit

RUN nix-env -iA nixpkgs.jq

RUN nix-env -iA \
    nixos-unstable.ophcrack-cli

RUN mkdir -p /opt/tools/bin /opt/tools/owasp-zap

RUN curl -L "https://github.com/zaproxy/zaproxy/releases/download/v${ZAP_VERSION}/ZAP_${ZAP_VERSION}_Linux.tar.gz" \
    | tar -xz --strip-components=1 -C /opt/tools/owasp-zap \
    && ln -s /opt/tools/owasp-zap/zap.sh /opt/tools/bin/zap

RUN curl -L "https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_${GHIDRA_VERSION}_build/${GHIDRA_DIST}.zip" \
    -o /tmp/ghidra.zip \
    && unzip /tmp/ghidra.zip -d /opt/tools \
    && mv /opt/tools/${GHIDRA_DIST} /opt/tools/ghidra \
    && ln -s /opt/tools/ghidra/ghidraRun /opt/tools/bin/ghidra \
    && rm /tmp/ghidra.zip

RUN git clone --depth 1 https://github.com/docker/docker-bench-security.git /opt/tools/docker-bench-security \
    && ln -s /opt/tools/docker-bench-security/docker-bench-security.sh /opt/tools/bin/docker-bench-security

RUN if [ -x /root/.nix-profile/bin/ophcrack-cli ]; then \
        ln -s /root/.nix-profile/bin/ophcrack-cli /opt/tools/bin/ophcrack; \
    fi

ENV CHROME_BIN=/root/.nix-profile/bin/chromium \
    CHROMEDRIVER_PATH=/root/.nix-profile/bin/chromedriver \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /opt/hexstrike

COPY requirements.txt ./

# Create Python virtual environment and install Python dependencies
RUN python3 -m venv /opt/venv \
    && . /opt/venv/bin/activate \
    && pip install --upgrade pip setuptools wheel \
    && pip install --no-cache-dir -r requirements.txt \
    && pip install --no-cache-dir \
        autorecon \
        dirsearch \
        arjun \
        paramspider \
        patator \
        prowler \
        scout-suite \
        smbmap \
        sslyze \
        uro \
        hashID \
        nosqlmap \
        tplmap

# Copy application source
COPY . /opt/hexstrike

# Ensure runtime directories exist for logs and persistent data
RUN mkdir -p /opt/hexstrike/logs /opt/hexstrike/data

ENV VIRTUAL_ENV=/opt/venv \
    PATH=/opt/tools/bin:/opt/venv/bin:${PATH}

# Provide an entrypoint script that keeps the container running in the
# application directory so all generated artefacts stay within mounted volumes
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 8888

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["python", "hexstrike_server.py", "--host", "0.0.0.0", "--port", "8888"]
