{ nixpkgs
, nixos-mailserver
, keys
}:

{
  inherit nixpkgs;

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
  };

  mail = { config, pkgs, ... }: {
    deployment.targetHost = "mail.vvvu.org";
    deployment.keys.xchen.text = keys.mail.xchen;
    deployment.keys.jli.text = keys.mail.jli;

    imports = [ nixos-mailserver.nixosModules.default ];

    mailserver = {
      enable = true;
      fqdn = "mail.vvvu.org";
      domains = [ "vvvu.org" ];

      loginAccounts = {
        "xchen@vvvu.org" = {
          hashedPasswordFile = "/run/keys/xchen";
        };
        "jli@vvvu.org" = {
          hashedPasswordFile = "/run/keys/jli";
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

  nextcloud = { config, pkgs, ... }: {
    deployment.targetHost = "nextcloud.vvvu.org";
    deployment.keys.admin = {
      text = keys.nextcloud;
      user = "nextcloud";
      group = "nextcloud";
    };

    users.groups.keys.members = [ "nextcloud" ];

    services.nextcloud = {
      enable = true;
      package = pkgs.nextcloud29;
      hostName = "nextcloud.vvvu.org";
      config.adminpassFile = "/run/keys/admin";
      https = true;
    };

    services.nginx.virtualHosts.${config.services.nextcloud.hostName} = {
      forceSSL = true;
      enableACME = true;
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}
