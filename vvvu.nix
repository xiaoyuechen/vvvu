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
      package = pkgs.nextcloud30;
      hostName = "nextcloud.vvvu.org";
      database.createLocally = true;
      config = {
        adminpassFile = "/run/keys/admin";
        dbtype = "mysql";
      };
      https = true;
      notify_push.enable = true;
    };

    services.nginx.virtualHosts.${config.services.nextcloud.hostName} = {
      forceSSL = true;
      enableACME = true;
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };

  ntfy = { config, pkgs, ... }: {
    deployment.targetHost = "ntfy.vvvu.org";
    deployment.keys.mollysocket = {
      text = keys.mollysocket;
      user = "mollysocket";
      group = "mollysocket";
    };

    services.mollysocket = {
      enable = true;
      environmentFile = "/run/keys/mollysocket";
      settings = {
        allowed_uuids = ["5a6862ec-7c60-457f-b178-f2ccd82ea99c"];
        allowed_endpoints = ["https://ntfy.vvvu.org/upRXSufuKOSEAv"];
      };
    };

    services.ntfy-sh = {
      enable = true;
      settings = {
        base-url = "http://ntfy.vvvu.org";
        behind-proxy = true;
      };
    };

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      validateConfigFile = false;
      virtualHosts."ntfy.vvvu.org" = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://${config.services.ntfy-sh.settings.listen-http}";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_buffering off;
            proxy_request_buffering off;
            proxy_redirect off;

            proxy_connect_timeout 3m;
            proxy_send_timeout 3m;
            proxy_read_timeout 3m;

            client_max_body_size 0;
          '';
        };
        locations."/molly/" = {
          proxyPass = with config.services.mollysocket.settings; "http://${host}:${toString port}/";
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Original-URL $uri;
          '';
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}
