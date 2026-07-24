{ self, inputs, ...}: {

  flake.nixosModules.niri = { pkgs, lib, ... }: {
    programs.niri = {
      enable = true;
      package = self.packages.${pkgs.stdenv.hostPlatform.system}.myNiri;
    };
  };

  perSystem = { pkgs, self', ... }: {
    packages.myNiri = inputs.wrapper-modules.wrappers.niri.wrap {
      inherit pkgs;
      settings = {
       
        spawn-at-startup = [
	"${pkgs.lib.getExe self'.packages.myDMS} run"
	];

        input.keyboard = {
	  xkb = {
	    layout = "us";
	    variant = "alt-intl";
	  };
	};
	layout.gaps = 5;
	binds = {
	  "Mod+Return".spawn-sh = pkgs.lib.getExe pkgs.kitty;
	};
      };
    };
  };
}
