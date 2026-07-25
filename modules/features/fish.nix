{ self, inputs, ... }: {

  flake.nixosModules.fish = { pkgs, ... }: {
    programs.fish.enable = true;

    users.users."zep".shell = pkgs.fish;

    home-manager.users.zep = { ... }: {
      programs.fish = {
        enable = true;
        
        interactiveShellInit = ''
          set -g fish_greeting ""
        '';

        shellAliases = {
          ll = "ls -la";
          

	  # QoL nix aliases
	  nix-sync = "sudo nixos-rebuild switch --flake ~/myNixOS/";
	  nix-test-build = "sudo nixos-rebuild test --flake ~/myNixOS/";
	  nix-upgrade = "sudo nixos-rebuild switch --upgrade --flake ~/myNixOS/";
	  nix-generations = "nixos-rebuild list-generations";
	  nix-clean = "sudo nix-collect-garbage -d && nix-store --optimise";


	  # QoL git aliases
	  gs = "git status";
	  ga = "git add";
	  gac = "git add . && git commit -m";
	  gp = "git push";

        };
      };
    };
  };
}
