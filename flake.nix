{
  description = "NixOps configuration for nvvvu.org";

  inputs = {
    nixos-mailserver.url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
  };

  outputs = { self, nixpkgs, nixos-mailserver }: {
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;

    nixopsConfigurations.default = let keys = import ./keys.nix; in {
      nixpkgs = nixpkgs;

      network = {
        description = "vvvu.org";
        storage.legacy.databasefile = { };
      };

      defaults = {
        imports = [ (nixpkgs + "/nixos/modules/virtualisation/digital-ocean-image.nix") ];

        security.acme = {
          acceptTerms = true;
          defaults.email = "xchen@vvvu.org";
        };

        services.automatic-timezoned.enable = true;
      };

      mail = { config, pkgs, ... }: {
        deployment.targetHost = "mail.vvvu.org";
        deployment.keys.xchen.text = keys.mail.xchen;

        imports = [ nixos-mailserver.nixosModules.default ];

        mailserver = {
          enable = true;
          fqdn = "mail.vvvu.org";
          domains = [ "vvvu.org" ];

          loginAccounts = {
            "xchen@vvvu.org" = {
              hashedPasswordFile = "/run/keys/xchen";
            };
          };

          certificateScheme = "acme-nginx";
        };
      };

      bitwarden = { config, pkgs, ... }: {
        deployment.targetHost = "bitwarden.vvvu.org";

        services.nginx = {
          enable = true;

          virtualHosts."bitwarden.vvvu.org" = {
            enableACME = true;
            forceSSL = true;
            locations."/" = {
              proxyPass = "http://127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}";
            };
          };
        };

        services.vaultwarden = {
          enable = true;
          config = {
            ROCKET_ADDRESS = "127.0.0.1";
            ROCKET_PORT = 8222;
            ROCKET_LOG = "critical";
            SIGNUPS_ALLOWED = false;
          };
        };

        networking.firewall.allowedTCPPorts = [ 80 443 ];
      };

      wg = { config, pkgs, ... }: {
        deployment.targetHost = "wg.vvvu.org";
        deployment.keys.wg0.text = keys.wg.wg0.private;

        networking.nat = {
          enable = true;
          externalInterface = "ens3";
          internalInterfaces = [ "wg0" ];
        };

        networking.firewall = {
          allowedTCPPorts = [ 53 ];
          allowedUDPPorts = [ 53 51820 ];
        };


        networking.wireguard.interfaces.wg0 = {
          privateKeyFile = "/run/keys/wg0";

          ips = [ "10.100.0.1/24" ];
          listenPort = 51820;

          postSetup = "${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 10.100.0.0/24 -o eth0 -j MASQUERADE";
          postShutdown = "${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 10.100.0.0/24 -o eth0 -j MASQUERADE";

          peers = [
            {
              name = "racc";
              publicKey = keys.wg.wg0.peers.racc.public;
              allowedIPs = [ "10.100.0.2/32" ];
            }
            {
              name = "galaxy";
              publicKey = keys.wg.wg0.peers.galaxy.public;
              allowedIPs = [ "10.100.0.3/32" ];
            }
          ];
        };

        services.dnsmasq = {
          enable = true;
          extraConfig = "interface=wg0";
        };
      };
    };
  };
}
