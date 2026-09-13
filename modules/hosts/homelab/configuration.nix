{ self, inputs, ... }: {
  flake.nixosModules.homelabConfiguration = { config, pkgs, ... }: {
    imports = [
      self.nixosModules.homelabHardware
      inputs.home-manager.nixosModules.home-manager
      self.nixosModules.fish
      self.nixosModules.gh
      self.nixosModules.home-assistant
      self.nixosModules.qbittorrent
      self.nixosModules.sops
      self.nixosModules.searxng
      self.nixosModules.sonarr
      self.nixosModules.radarr
      self.nixosModules.prowlarr
      self.nixosModules.jellyfin
      self.nixosModules.seerr
      self.nixosModules.tuya-pc-power
      self.nixosModules.earnapp
      self.nixosModules.grass
      self.nixosModules.auto-update
      self.nixosModules.opencode
      self.nixosModules.herdr
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
          "bc:35:1e:78:ef:de,10.42.0.115,tuya-relay"
          "8c:86:dd:7d:d5:bd,10.42.0.129,tapo-p110"
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
    features.home-assistant.enable = true;
    features.tuya-pc-power.enable = false;
    features.seerr.enable = true;
    features.earnapp.enable = false;
    features.grass.enable = false;

    # Allow Colmena to deploy (passwordless sudo)
    security.sudo.extraRules = [{
      users = ["zep"];
      commands = [{
        command = "ALL";
        options = ["NOPASSWD"];
      }];
    }];

    # Nightly auto-upgrade + weekly reboot + garbage collection
    features.auto-update.enable = true;

    # Agent devbox: OpenCode + configured Comfy-MCP runtime (Syncthing owns ~/.config/opencode)
    features.opencode.enable = true;

    # herdr headless server (user service + linger)
    features.herdr.enable = true;

    # Syncthing on external drive
    services.syncthing =
      let
        localDeviceId = "MH7LTXT-LLBD5A3-7KWJD27-JSSQWN3-QHOMYTH-OU5PCBX-4CRDNAF-ZZ2RCQR";
        sharedDevices = [ "nixos-t480" "fedora-t14g5" "cachyos-legion" ];
        deviceDefaults = {
          addresses = [ "dynamic" ];
          allowedNetworks = [ ];
          autoAcceptFolders = false;
          certName = "";
          compression = "metadata";
          group = "";
          ignoredFolders = [ ];
          introducer = false;
          maxRecvKbps = 0;
          maxRequestKiB = 0;
          maxSendKbps = 0;
          paused = false;
          remoteGUIPort = 0;
          skipIntroductionRemovals = false;
          untrusted = false;
        };
        folderDefaults = {
          autoNormalize = true;
          blockIndexing = true;
          blockPullOrder = "standard";
          caseSensitiveFS = false;
          copiers = 0;
          copyOwnershipFromParent = false;
          copyRangeMethod = "standard";
          disableFsync = false;
          disableSparseFiles = false;
          filesystemType = "basic";
          fsWatcherDelayS = 10;
          fsWatcherEnabled = true;
          fsWatcherTimeoutS = 0;
          group = "";
          hashers = 0;
          ignoreDelete = false;
          ignorePerms = false;
          junctionsAsDirs = false;
          markerName = ".stfolder";
          maxConcurrentWrites = 16;
          maxConflicts = 10;
          minDiskFree = {
            unit = "%";
            value = 1;
          };
          modTimeWindowS = 0;
          order = "random";
          paused = false;
          pullerDelayS = 1;
          pullerMaxPendingKiB = 0;
          pullerPauseS = 0;
          rescanIntervalS = 3600;
          scanProgressIntervalS = 0;
          sendOwnership = false;
          sendXattrs = false;
          syncOwnership = false;
          syncXattrs = false;
          xattrFilter = {
            entries = [ ];
            maxSingleEntrySize = 1024;
            maxTotalSize = 4096;
          };
        };
      in
      {
      enable = true;
      openDefaultPorts = true;
      user = "zep";
      dataDir = "/mnt/SKYHAWK00_4TB/Sync";
      configDir = "/home/zep/.config/syncthing";
      guiAddress = "0.0.0.0:8384";

      # Declarative transcription of the live config.xml (harvested 2026-09-11).
      settings = {
        # The service-level guiAddress below is authoritative for the binding;
        # the live REST address is intentionally not duplicated here.
        gui = {
          authMode = "static";
          enabled = true;
          insecureAdminAccess = false;
          insecureAllowFrameLoading = false;
          insecureSkipHostcheck = false;
          metricsWithoutAuth = false;
          password = "$2a$10$Ei9XCHrRYOauFpjvahr5KeGKeAMkH8ghTkppJ5nHVEjA1zHbuXYry";
          sendBasicAuthPrompt = false;
          sessionCookieDurationS = 604800;
          sessionCookiePath = "/";
          theme = "black";
          unixSocketPermissions = "";
          useTLS = true;
          user = "zep";
        };

        options = {
          alwaysLocalNets = [ ];
          announceLANAddresses = true;
          auditEnabled = false;
          auditFile = "";
          autoUpgradeIntervalH = 12;
          cacheIgnoredFiles = false;
          connectionLimitEnough = 0;
          connectionLimitMax = 0;
          connectionPriorityQuicLan = 20;
          connectionPriorityQuicWan = 40;
          connectionPriorityRelay = 50;
          connectionPriorityTcpLan = 10;
          connectionPriorityTcpWan = 30;
          connectionPriorityUpgradeThreshold = 0;
          crURL = "https://crash.syncthing.net/newcrash";
          crashReportingEnabled = true;
          featureFlags = [ ];
          globalAnnounceEnabled = true;
          globalAnnounceServers = [ "default" ];
          keepTemporariesH = 24;
          limitBandwidthInLan = false;
          listenAddresses = [ "default" ];
          localAnnounceEnabled = true;
          localAnnounceMCAddr = "[ff12::8384]:21027";
          localAnnouncePort = 21027;
          maxConcurrentIncomingRequestKiB = 0;
          maxFolderConcurrency = 0;
          maxRecvKbps = 0;
          maxSendKbps = 0;
          minHomeDiskFree = {
            unit = "%";
            value = 1;
          };
          natEnabled = true;
          natLeaseMinutes = 60;
          natRenewalMinutes = 30;
          natTimeoutSeconds = 10;
          overwriteRemoteDeviceNamesOnConnect = false;
          progressUpdateIntervalS = 5;
          reconnectionIntervalS = 20;
          relayReconnectIntervalM = 10;
          relaysEnabled = true;
          releasesURL = "https://upgrades.syncthing.net/meta.json";
          sendFullIndexOnUpgrade = false;
          setLowPriority = true;
          startBrowser = true;
          stunKeepaliveMinS = 20;
          stunKeepaliveStartS = 180;
          stunServers = [ "default" ];
          tempIndexMinBlocks = 10;
          trafficClass = 0;
          upgradeToPreReleases = false;
          urAccepted = 3;
          urInitialDelayS = 1800;
          urPostInsecurely = false;
          urSeen = 3;
          urURL = "https://data.syncthing.net/newdata";
        };

        defaults = {
          device = deviceDefaults // {
            deviceID = "";
            name = "";
          };
          folder = folderDefaults // {
            devices = [ { deviceID = localDeviceId; } ];
            id = "";
            label = "";
            path = "";
            type = "sendreceive";
            versioning = {
              cleanupIntervalS = 3600;
              fsPath = "";
              fsType = "basic";
              type = "";
            };
          };
          ignores.lines = [ ];
        };

        devices = {
          nixos-t480 = deviceDefaults // {
            id = localDeviceId;
            name = "nixos-t480";
          };
          fedora-t14g5 = deviceDefaults // {
            id = "4PF6DVW-SVBXLUD-YNKJ2TY-4ZPYNRG-E7ZCVJ7-N2W5P5B-PPP636K-IZE6AAW";
            name = "fedora-t14g5";
          };
          cachyos-legion = deviceDefaults // {
            id = "7SMORQW-IGGTVO6-DNQ37VW-DCSYJUR-Z2LX5ZH-USD2JY4-NCFIA4J-FYVG4AM";
            name = "cachyos-legion";
          };
        };

        folders = {
          "Skyrim Saves" = folderDefaults // {
            id = "aavuh-cxuh6";
            label = "Skyrim Saves";
            path = "/mnt/SKYHAWK00_4TB/Sync/SkyrimSaves";
            type = "sendreceive";
            devices = sharedDevices;
            ignorePatterns = [ ];
          };
          "Opencode Auth" = folderDefaults // {
            id = "kfhrr-vfacf";
            label = "Opencode Auth";
            path = "/mnt/SKYHAWK00_4TB/Sync/home/.local/share/opencode";
            type = "sendreceive";
            devices = sharedDevices;
            ignorePatterns = [ ];
          };
          Projects = folderDefaults // {
            id = "kjyln-n9aar";
            label = "Projects";
            path = "/mnt/SKYHAWK00_4TB/Sync/home/Projects";
            type = "sendreceive";
            devices = sharedDevices;
            ignorePatterns = [ ];
          };
          "Opencode Configuration" = folderDefaults // {
            id = "tfy5m-vhwkk";
            label = "Opencode Configuration";
            path = "/mnt/SKYHAWK00_4TB/Sync/.config/opencode";
            type = "sendreceive";
            devices = sharedDevices;
            ignorePatterns = [ ];
          };
          Wallpapers = folderDefaults // {
            id = "x9ztl-nwukn";
            label = "Wallpapers";
            path = "/mnt/SKYHAWK00_4TB/Sync/home/Pictures/wallpapers";
            type = "sendreceive";
            devices = sharedDevices;
            ignorePatterns = [ ];
          };
        };

        # Syncthing owns empty LDAP/remote-ignore sections and runtime values:
        # GUI API key, options.unackedNotificationIDs/urUniqueId, device
        # numConnections, folder versioning with an empty type, and folder
        # device introducedBy/encryptionPassword.
      };
      };

    # Home-dir symlinks onto the synced drive (dirs are synced by Syncthing;
    # L+ replaces whatever is there, pre-checked empty/absent on 2026-09-11).
    systemd.tmpfiles.rules = [
      "L+ /home/zep/Projects - - - - /mnt/SKYHAWK00_4TB/Sync/home/Projects"
      "L+ /home/zep/.config/opencode - - - - /mnt/SKYHAWK00_4TB/Sync/.config/opencode"
      "L+ /home/zep/.local/share/opencode - - - - /mnt/SKYHAWK00_4TB/Sync/home/.local/share/opencode"
    ];

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
    # (drive root is zep-owned, so tmpfiles refuses to create dirs there —
    # create the library dirs from a root oneshot instead)
    systemd.services.media-dirs = {
      description = "Create media library directories on the external drive";
      wantedBy = [ "multi-user.target" ];
      requires = [ "mnt-SKYHAWK00_4TB.mount" ];
      after = [ "mnt-SKYHAWK00_4TB.mount" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        install -d -o root -g media -m 0775 /mnt/SKYHAWK00_4TB/Media/TV
        install -d -o root -g media -m 0775 /mnt/SKYHAWK00_4TB/Media/Movies
        chown root:media /mnt/SKYHAWK00_4TB/Media
        chmod 0775 /mnt/SKYHAWK00_4TB/Media
      '';
    };
    systemd.services.sonarr = {
      requires = [ "mnt-SKYHAWK00_4TB.mount" ];
      after = [ "mnt-SKYHAWK00_4TB.mount" "media-dirs.service" ];
      bindsTo = [ "mnt-SKYHAWK00_4TB.mount" ];
    };
    systemd.services.radarr = {
      requires = [ "mnt-SKYHAWK00_4TB.mount" ];
      after = [ "mnt-SKYHAWK00_4TB.mount" "media-dirs.service" ];
      bindsTo = [ "mnt-SKYHAWK00_4TB.mount" ];
    };
    systemd.services.jellyfin = {
      requires = [ "mnt-SKYHAWK00_4TB.mount" ];
      after = [ "mnt-SKYHAWK00_4TB.mount" "media-dirs.service" ];
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
