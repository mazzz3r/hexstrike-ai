# syntax=docker/dockerfile:1
FROM nixos/nix:2.21.2

LABEL org.opencontainers.image.title="HexStrike AI"
LABEL org.opencontainers.image.description="Penetration testing toolbox bundled via Nix"
LABEL org.opencontainers.image.authors="HexStrike AI Maintainers"

ENV NIX_CONFIG="experimental-features = nix-command flakes"
ENV PATH="/root/.nix-profile/bin:/root/.nix-profile/sbin:${PATH}"
ENV LANG=C.UTF-8

WORKDIR /opt/hexstrike
COPY . /opt/hexstrike

RUN nix --extra-experimental-features "nix-command flakes" profile install \
      .#core-tools \
      .#hexstrike-ai-server \
      .#hexstrike-ai-mcp \
    && nix-store --optimise

RUN ln -sf /root/.nix-profile/bin/hexstrike_server.py /usr/local/bin/hexstrike-server \
    && ln -sf /root/.nix-profile/bin/hexstrike_mcp.py /usr/local/bin/hexstrike-mcp \
    && chmod +x /opt/hexstrike/docker-entrypoint.sh

ENTRYPOINT ["/opt/hexstrike/docker-entrypoint.sh"]
CMD []
