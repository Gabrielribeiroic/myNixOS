{ self, inputs, ... }: {

  flake.nixosModules.workstationConfiguration = { config, pkgs, ... }:

    {
      imports = [ 
          self.nixosModules.workstationHardware
          self.nixosModules.gnome
	  self.nixosModules.fish
	  self.nixosModules.zenbrowser
	  self.nixosModules.legion
	  self.nixosModules.gh
	  self.nixosModules.sops
        ];


      nix.settings = {
        experimental-features = [ "nix-command" "flakes" ];
        substituters = [
	  "https://attic.xuyh0120.win/lantian"
	];
	trusted-public-keys = [
          "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
	];
      };

      nixpkgs.overlays = [
        inputs.nix-cachyos-kernel.overlays.pinned
      ];

      boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest-lto-x86_64-v3;

      services.scx = {
        enable = true;
	scheduler = "scx_lavd";
      };

      # Bootloader.
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;

      # Use latest kernel. -> Disabled in order to use cachyos kernel
      # boot.kernelPackages = pkgs.linuxPackages_latest;

      networking.hostName = "workstation"; # Define your hostname.

      # Enable networking
      networking.networkmanager.enable = true;

      # Set your time zone.
      time.timeZone = "America/Recife";

      # Select internationalisation properties.
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

      # Configure console keymap
      console.keyMap = "us";

      # Enable sound with pipewire.
      services.pulseaudio.enable = false;
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };

      # Define a user account. Don't forget to set a password with ‘passwd’.
      users.users."zep" = {
        isNormalUser = true;
        description = "zep";
        extraGroups = [ "networkmanager" "wheel" "input" ];
        packages = with pkgs; [
          fastfetch
        ];
      };

      # Install firefox.
      programs.firefox.enable = true;

      # Enable SSH Agent
      # programs.ssh.startAgent = true;

      # Allow unfree packages
      nixpkgs.config.allowUnfree = true;

      environment.systemPackages = with pkgs; [
        neovim
        git
        wget
        firefox
	btop
	scx.full
      ];

      fonts.packages = with pkgs; [
        inter
        fira-code
        nerd-fonts.fira-code
      ];

      hardware = {
        graphics = {
          enable = true;
          enable32Bit = true;
        };
        nvidia = {
          modesetting.enable = true;
          open = true;
          nvidiaSettings = true;
          package = config.boot.kernelPackages.nvidiaPackages.latest;
          powerManagement = {
	    enable = true;
	    finegrained = false;
	  };
	  prime = {
            sync.enable = true;
            intelBusId = "PCI:0:2:0";
            nvidiaBusId = "PCI:6:0:0";
          };
        };
      };

      services.xserver.videoDrivers = [ "nvidia" ];

      system.stateVersion = "26.05";
    };
}
