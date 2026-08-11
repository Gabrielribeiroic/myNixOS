{ self, inputs, ... }: {
  flake.nixosModules.homelabConfiguration = { config, pkgs, ... }: {
    imports = [
      self.nixosModules.homelabHardware
      inputs.home-manager.nixosModules.home-manager
      self.nixosModules.fish
      self.nixosModules.gh
      self.nixosModules.qbittorrent
      self.nixosModules.sops
      self.nixosModules.searxng
      self.nixosModules.sonarr
      self.nixosModules.radarr
      self.nixosModules.prowlarr
      self.nixosModules.jellyfin
      self.nixosModules.seerr
    ];

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "hm-backup";
      users.zep.home.stateVersion = "26.05";
    };

    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    # Bootloader
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    networking = {
      hostName = "homelab";
      networkmanager.enable = true;
      firewall = {
        enable = true;
        allowedTCPPorts = [ 22 22000 ];
        allowedUDPPorts = [ 22000 21027 ];
        trustedInterfaces = [ "tailscale0" ];
      };
      firewall.interfaces."wlp3s0".allowedUDPPorts = [ 53 67 ];
    };

    # Wi-Fi AP (hostapd) — makeshift router on the internal Wi-Fi chip
    networking.networkmanager.unmanaged = [ "interface-name:wlp3s0" ];
    networking.interfaces.wlp3s0.ipv4.addresses = [{
      address = "10.42.0.1";
      prefixLength = 24;
    }];

    services.hostapd = {
      enable = true;
      radios.wlp3s0 = {
        # 5 GHz AP is impossible on this 8265: iwlwifi firmware (LAR) keeps
        # 5 GHz channels NO-IR regardless of country (see ArchWiki "Software
        # access point": Intel devices since 2019). 2.4 GHz only.
        band = "2g";
        channel = 6;
        countryCode = "BR";
        networks.wlp3s0 = { # primary BSS must be named like the radio
          ssid = "homelab-AP";
          authentication = {
            mode = "wpa2-sha256";
            wpaPasswordFile = "/run/secrets/wifi-pass"; # sops
          };
        };
      };
    };

    services.dnsmasq = {
      enable = true;
      resolveLocalQueries = false; # don't hijack the host's own DNS
      settings = {
        interface = "wlp3s0";
        bind-interfaces = true;
        dhcp-range = [ "10.42.0.10,10.42.0.200,12h" ];
        # DHCP reservations (MAC,IP,hostname)
        "dhcp-host" = [
          "70:d8:c2:11:ae:db,10.42.0.83,cachyos-legion"
          "12:94:05:7b:b6:07,10.42.0.187,fedora-t14g5"
        ];
      };
    };

    networking.nat = {
      enable = true;
      internalInterfaces = [ "wlp3s0" ];
      externalInterface = "enp0s31f6";
    };

    # hostapd must not start before sops has written the passphrase
    systemd.services.hostapd = {
      requires = [ "sops-install-secrets.service" ];
      after = [ "sops-install-secrets.service" ];
    };

    # dnsmasq needs wlp3s0 up (with its address) before it can bind
    systemd.services.dnsmasq = {
      after = [ "hostapd.service" ];
    };

    sops = {
      # makes sops-nix provision secrets via a sysinit unit (so hostapd can
      # order itself after it) instead of only the activation script
      useSystemdActivation = true;
      secrets."wifi-pass" = {
        sopsFile = ../../../secrets/hostapd.yaml;
      };
    };

    time.timeZone = "America/Recife";
    i18n.defaultLocale = "en_US.UTF-8";
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "pt_BR.UTF-8";
      LC_IDENTIFICATION = "pt_BR.UTF-8";
      LC_MEASUREMENT = "pt_BR.UTF-8";
      LC_MONETARY = "pt_BR.UTF-8";
      LC_NAME = "pt_BR.UTF-8";
      LC_NUMERIC = "pt_BR.UTF-8";
      LC_PAPER = "pt_BR.UTF-8";
      LC_TELEPHONE = "pt_BR.UTF-8";
      LC_TIME = "pt_BR.UTF-8";
    };

    # Keymap (Brazilian Portuguese with ThinkPad variant)
    services.xserver.xkb = {
      layout = "br";
      variant = "thinkpad";
    };
    console.keyMap = "br-abnt2";

    users.users.zep = {
      isNormalUser = true;
      description = "zep";
      extraGroups = [ "networkmanager" "wheel" "media" ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICUeS6icEgYSY/KeXVAHg3I5gsaIgnhdmkEJFLX/n6CP zep@fedora-t14g5"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKiklor/K3gReBQ8C/qqUBYXjTO3YfIiixyZFGSfOvNe zep@cachy-main"
      ];
    };

    nixpkgs.config.allowUnfree = true;

    environment.systemPackages = with pkgs; [
      neovim
      wget
      git
      btop
      batmon
      tailscale
      fastfetch
      cmake
      gcc
      gnumake
      binutils
    ];

    # SSH
    services.openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
      settings.PermitRootLogin = "no";
      settings.AllowUsers = [ "zep" ];
    };

    # Tailscale
    services.tailscale.enable = true;

    # SearXNG
    features.searxng.enable = true;

    # Shared group for the media stack: qBittorrent, Sonarr, Radarr, Jellyfin
    # all write with 0775/0664 perms so hardlinks and atomic moves work.
    # (zep joins via extraGroups above)
    users.groups.media = { };

    # qBittorrent
    features.qbittorrent.enable = true;

    # Media stack: Sonarr + Radarr + Prowlarr + Jellyfin + Seerr
    features.sonarr.enable = true;
    features.radarr.enable = true;
    features.prowlarr.enable = true;
    features.jellyfin.enable = true;
    features.seerr.enable = true;

    # Allow Colmena to deploy (passwordless sudo)
    security.sudo.extraRules = [{
      users = ["zep"];
      commands = [{
        command = "ALL";
        options = ["NOPASSWD"];
      }];
    }];

    # Syncthing on external drive
    services.syncthing = {
      enable = true;
      openDefaultPorts = true;
      user = "zep";
      dataDir = "/mnt/SKYHAWK00_4TB/Sync";
      configDir = "/home/zep/.config/syncthing";
      guiAddress = "0.0.0.0:8384";
    };

    systemd.services.syncthing = {
      requires = [ "mnt-SKYHAWK00_4TB.mount" ];
      after = [ "mnt-SKYHAWK00_4TB.mount" ];
      bindsTo = [ "mnt-SKYHAWK00_4TB.mount" ];
    };

    # qBittorrent saves to the external drive too
    systemd.services.qbittorrent = {
      requires = [ "mnt-SKYHAWK00_4TB.mount" ];
      after = [ "mnt-SKYHAWK00_4TB.mount" ];
      bindsTo = [ "mnt-SKYHAWK00_4TB.mount" ];
    };

    # Media stack reads/writes the external drive
    systemd.services.sonarr = {
      requires = [ "mnt-SKYHAWK00_4TB.mount" ];
      after = [ "mnt-SKYHAWK00_4TB.mount" ];
      bindsTo = [ "mnt-SKYHAWK00_4TB.mount" ];
    };
    systemd.services.radarr = {
      requires = [ "mnt-SKYHAWK00_4TB.mount" ];
      after = [ "mnt-SKYHAWK00_4TB.mount" ];
      bindsTo = [ "mnt-SKYHAWK00_4TB.mount" ];
    };
    systemd.services.jellyfin = {
      requires = [ "mnt-SKYHAWK00_4TB.mount" ];
      after = [ "mnt-SKYHAWK00_4TB.mount" ];
      bindsTo = [ "mnt-SKYHAWK00_4TB.mount" ];
    };

    # Samba share of the external drive (LAN/Windows access)
    services.samba = {
      enable = true;
      openFirewall = true; # opens 139/445
      settings = {
        global = {
          "server string" = "homelab NAS";
          "map to guest" = "never";
        };
        nas = {
          path = "/mnt/SKYHAWK00_4TB";
          browseable = "yes";
          "valid users" = "zep";
          "read only" = "no";
        };
      };
    };

    # External drive mount
    fileSystems."/mnt/SKYHAWK00_4TB" = {
      device = "/dev/disk/by-uuid/b9eb70b3-d3c9-46ad-80e9-769344600ad9";
      fsType = "ext4";
      options = [ "nofail" "noatime" "x-systemd.device-timeout=10s" ];
    };

    # ThinkPad T480 — battery charge limits
    services.tlp = {
      enable = true;
      settings = {
        START_CHARGE_THRESH_BAT0 = 60;
        START_CHARGE_THRESH_BAT1 = 60;
        STOP_CHARGE_THRESH_BAT0 = 70;
        STOP_CHARGE_THRESH_BAT1 = 70;
      };
    };

    # Ignore lid switch
    services.logind.settings.Login = {
      HandleLidSwitch = "ignore";
      HandleLidSwitchDocked = "ignore";
      HandleLidSwitchExternalPower = "ignore";
    };

    # Disable sleep/hibernate
    systemd.targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
    };

    system.stateVersion = "26.05";
  };
}
