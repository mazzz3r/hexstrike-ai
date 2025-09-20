# syntax=docker/dockerfile:1

FROM nixos/nix:2.21.2

ENV NIX_CONFIG "experimental-features = nix-command flakes"
ENV NIXPKGS_ALLOW_UNFREE=1

WORKDIR /opt/hexstrike

COPY flake.nix ./
COPY requirements.txt ./
COPY hexstrike_server.py ./
COPY hexstrike_mcp.py ./
COPY hexstrike-ai-mcp.json ./
COPY assets ./assets
COPY README.md ./

RUN nix --extra-experimental-features "nix-command flakes" profile install .#hexstrike-ai-server \
    && nix --extra-experimental-features "nix-command flakes" profile install .#hexstrike-ai-mcp \
    && nix --extra-experimental-features "nix-command flakes" profile install nixpkgs#bashInteractive \
    && rm -rf /root/.cache/nix

# Provide a writable workspace for scan outputs and reports
RUN mkdir -p /workspace
WORKDIR /workspace

ENV PATH=/nix/var/nix/profiles/default/bin:$PATH \
    HEXSTRIKE_HOST=0.0.0.0 \
    HEXSTRIKE_PORT=8888

EXPOSE 8888

ENTRYPOINT ["hexstrike_server.py"]
CMD ["--port", "8888"]
