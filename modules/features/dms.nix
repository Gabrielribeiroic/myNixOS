{ self, inputs, ... }: {
  perSystem = { pkgs, ... }: let 
    dmsPackage = pkgs.dms-shell; 
  in {
    packages.myDMS = pkgs.symlinkJoin {
      name = "dms-${dmsPackage.version}";
      paths = [ dmsPackage ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/dms \
          --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.quickshell dmsPackage ]}
      '';
      meta.mainProgram = "dms";
    };
  };
}
