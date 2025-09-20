{
  description = "HexStrike AI Nix flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    pyproject-nix = {
      url = "github:nix-community/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    autorecon-src = {
      url = "github:Tib3rius/AutoRecon";
      flake = false;
    };
    paramspider-src = {
      url = "github:devanshbatham/ParamSpider/790eb91213419e9c4ddec2c91201d4be5399cb77";
      flake = false;
    };
    scout-suite-src = {
      url = "github:nccgroup/ScoutSuite/7909f2fc6186063e5c9e7ddef8c4d7d1072c8f3d";
      flake = false;
    };
    docker-bench-security-src = {
      url = "github:docker/docker-bench-security";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-utils,
      pyproject-nix,
      autorecon-src,
      paramspider-src,
      scout-suite-src,
      docker-bench-security-src,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        overlayWebdriverManager = (final: prev: {
          python3 = prev.python3.override {
            packageOverrides = self': super: {
              "webdriver-manager" =
                super."webdriver-manager".overridePythonAttrs (old: {
                  meta = builtins.removeAttrs old.meta [ "platforms" ];
                  doCheck = false;
                  nativeCheckInputs = [ ];
                  checkInputs = [ ];
                  checkPhase = "true";
                  pythonImportsCheck = [ ];
                });
            };
          };
          python3Packages = final.python3.pkgs;
        });

        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
          overlays = [ overlayWebdriverManager ];
        };

        lib = pkgs.lib;
        python = pkgs.python3;
        pythonPackages = pkgs.python3Packages;

        docker-bench-security = pkgs.stdenv.mkDerivation {
          name = "docker-bench-security";
          builder = pkgs.bash;
          buildInputs = [ pkgs.jq ];
          args = let
            buildScript = pkgs.writeShellScript "build" ''
              ${pkgs.coreutils}/bin/mkdir -p $out/bin
              ${pkgs.coreutils}/bin/cp ${docker-bench-security-src}/docker-bench-security.sh $out/bin/docker-bench-security.sh
            '';
          in [ buildScript ];
        };

        corepkgs = with pkgs; [
          nmap
          masscan
          rustscan
          amass
          subfinder
          nuclei
          fierce
          dnsenum
          aircrack-ng
          metasploit
          responder
          enum4linux-ng
          theharvester
          gobuster
          feroxbuster
          pythonPackages.dirsearch
          ffuf
          dirb
          httpx
          katana
          nikto
          sqlmap
          wpscan
          arjun
          dalfox
          wafw00f
          john
          hashcat
          medusa
          evil-winrm
          hash-identifier
          gdb
          radare2
          binwalk
          ghidra-bin
          binutils
          volatility3
          foremost
          steghide
          exiftool
          trivy
          kube-hunter
          kube-bench
          docker-bench-security
        ] ++ lib.optionals pkgs.stdenv.isLinux [
          netexec
          hydra
          ophcrack
          checksec
          u-root-cmds
          chromium
          chromedriver
        ] ++ lib.optionals pkgs.stdenv.isDarwin [
          google-chrome
        ];

        core-tools = pkgs.buildEnv {
          name = "hexstrike-core-tools";
          paths = corepkgs;
        };

        hexstrike-ai-project = pyproject-nix.lib.project.loadRequirementsTxt {
          projectRoot = ./.;
        };
        hexstrike-attrs = hexstrike-ai-project.renderers.buildPythonPackage { inherit python; };
        hexstrike-ai-server-pkg = python.pkgs.buildPythonApplication (hexstrike-attrs // {
          name = "hexstrike-ai-server";
          nativeBuildInputs = [ pkgs.makeWrapper ];
          installPhase = ''
            runHook preInstall

            mkdir -p $out/bin
            cp ${self}/hexstrike_server.py $out/bin/hexstrike_server.py
            chmod +x $out/bin/hexstrike_server.py

            wrapProgram $out/bin/hexstrike_server.py \
              --prefix PATH : ${pkgs.lib.makeBinPath corepkgs}

            runHook postInstall
          '';
          meta = {
            mainProgram = "hexstrike_server.py";
          };
        });

        hexstrike-ai-mcp-pkg = python.pkgs.buildPythonApplication (hexstrike-attrs // {
          name = "hexstrike-ai-mcp";
          installPhase = ''
            runHook preInstall

            mkdir -p $out/bin
            cp ${self}/hexstrike_mcp.py $out/bin/hexstrike_mcp.py
            chmod +x $out/bin/hexstrike_mcp.py
            runHook postInstall
          '';
          meta = {
            mainProgram = "hexstrike_mcp.py";
          };
        });

      in
      {
        devShell = pkgs.mkShell {
          name = "HexStrike AI Dev Shell";
          buildInputs = [ hexstrike-ai-server-pkg hexstrike-ai-mcp-pkg core-tools ];
        };

        packages = rec {
          inherit core-tools;
          hexstrike-ai-server = hexstrike-ai-server-pkg;
          hexstrike-ai-mcp = hexstrike-ai-mcp-pkg;
          default = hexstrike-ai-server;
        };

        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}
