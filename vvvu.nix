{ nixpkgs, nixos-mailserver, keys }:

{
  inherit nixpkgs;

  network = {
    description = "vvvu.org";
    storage.legacy.databasefile = "./.nixops/deployments.nixops";
  };

  defaults = {
    imports = [
      (nixpkgs + "/nixos/modules/virtualisation/digital-ocean-image.nix")
      nixos-mailserver.nixosModules.default
    ];

    security.acme = {
      acceptTerms = true;
      defaults.email = "xchen@vvvu.org";
    };

    time.timeZone = "Europe/Stockholm";
    nix.optimise.automatic = true;
  };

  mail = { config, pkgs, ... }: {
    deployment.targetHost = "mail.vvvu.org";
    deployment.keys.sasl.text = keys.mail.sasl;
    deployment.keys.xchen.text = keys.mail.xchen;
    deployment.keys.jli.text = keys.mail.jli;
    deployment.keys.uppsala.text = keys.mail.uppsala;
    deployment.keys.gavle.text = keys.mail.gavle;

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
        "uppsala@vvvu.org" = {
          hashedPasswordFile = "/run/keys/uppsala";
        };
        "gavle@vvvu.org" = {
          hashedPasswordFile = "/run/keys/gavle";
        };
      };

      certificateScheme = "acme-nginx";
    };

    services.postfix = {
      enable = true;
      relayHost = "email-smtp.eu-north-1.amazonaws.com";
      relayPort = 587;
      config = {
        smtp_use_tls = "yes";
        smtp_sasl_auth_enable = "yes";
        smtp_sasl_security_options = "";
        smtp_sasl_password_maps = "texthash:/run/keys/sasl";
      };
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
    deployment.keys.admin.text = keys.nextcloud;
    services.nextcloud = {
      enable = true;
      package = pkgs.nextcloud31;
      hostName = "nextcloud.vvvu.org";
      config = {
        adminpassFile = "/run/keys/admin";
        dbtype = "sqlite";
      };
      https = true;
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
