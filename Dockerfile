# syntax=docker/dockerfile:1.5
FROM nixos/nix:2.18.1

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Update channel to ensure security tools are available
RUN nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs \
    && nix-channel --update

# Install security tooling with nix, including smbmap
RUN nix-env -iA \
        nixpkgs.python311Full \
        nixpkgs.git \
        nixpkgs.nmap \
        nixpkgs.masscan \
        nixpkgs.sqlmap \
        nixpkgs.smbmap

WORKDIR /app

COPY requirements.txt ./

# Bootstrap pip and install Python dependencies (without smbmap)
RUN python3 -m ensurepip --upgrade \
    && python3 -m pip install --no-cache-dir --upgrade pip \
    && python3 -m pip install --no-cache-dir \
        flask \
        requests \
        psutil \
        fastmcp \
        beautifulsoup4 \
        selenium \
        webdriver-manager \
        aiohttp \
        mitmproxy \
        pwntools \
        angr \
        bcrypt

COPY . .

EXPOSE 8888

CMD ["python3", "hexstrike_server.py", "--port", "8888"]
