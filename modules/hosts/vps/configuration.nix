{ self, ... }:
{
  flake.nixosModules.vpsConfiguration = { pkgs, ... }: {
    imports = [
      self.nixosModules.vpsDisko
      self.nixosModules.vpsHardware
    ];

    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    # OCI uses UEFI. systemd-boot installs a fallback EFI loader without
    # relying on a mutable UEFI NVRAM boot entry.
    boot.loader = {
      efi.canTouchEfiVariables = false;
      systemd-boot.enable = true;
    };
    boot.kernelParams = [ "console=tty0" "console=ttyAMA0,115200" ];

    networking = {
      hostName = "vps";
      useDHCP = false;
      firewall = {
        enable = true;
        allowedTCPPorts = [ 22 ];
        allowedUDPPorts = [ 41641 ];
        trustedInterfaces = [ "tailscale0" ];
      };
    };
    systemd.network = {
      enable = true;
      networks."10-oci" = {
        matchConfig.Name = "en*";
        networkConfig.DHCP = "yes";
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

    programs.fish.enable = true;
    security.sudo.wheelNeedsPassword = false;
    users.users.zep = {
      isNormalUser = true;
      description = "zep";
      extraGroups = [ "wheel" ];
      shell = pkgs.fish;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILAMmCq+fp/yhJ3FQmPo5h02i5HavSXCxD1rB3FICOxA zep@cachyos-legion"
	"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICUeS6icEgYSY/KeXVAHg3I5gsaIgnhdmkEJFLX/n6CP zep@fedora-t14g5"
      ];
    };

    environment.systemPackages = with pkgs; [
      neovim
      wget
      git
      btop
      batmon
      tailscale
      fastfetch
    ];

    services = {
      openssh = {
        enable = true;
        openFirewall = true;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = "no";
          AllowUsers = [ "zep" ];
          MaxAuthTries = 3;
          PerSourcePenalties = "crash:3600s authfail:3600s max:86400s";
        };
      };
      tailscale.enable = true;
      qemuGuest.enable = true;
    };

    system.stateVersion = "26.05";
  };
}
