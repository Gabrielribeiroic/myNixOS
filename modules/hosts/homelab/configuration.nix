{ self, inputs, ... }: {
  flake.nixosModules.homelabConfiguration = { config, pkgs, ... }: {
    imports = [
      self.nixosModules.homelabHardware
      inputs.home-manager.nixosModules.home-manager
      self.nixosModules.fish
      self.nixosModules.gh
      self.nixosModules.sops
      self.nixosModules.searxng
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
      extraGroups = [ "networkmanager" "wheel" ];
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
