{ ... }:
{
  flake.nixosModules.packetstream =
    { config, lib, ... }:
    {
      options.features.packetstream.enable = lib.mkEnableOption "PacketStream bandwidth-sharing client" // {
        default = false;
      };

      # No documented, pinned official Linux/x86_64 artifact is available in
      # this repository or the pinned nixpkgs input. Do not create a service
      # around an unverified binary, image, command, or credential format.
      config = lib.mkIf config.features.packetstream.enable {
        assertions = [{
          assertion = false;
          message = "features.packetstream.enable requires a verified, pinned official PacketStream Linux/x86_64 artifact and documented non-argv credential bootstrap; none is available yet.";
        }];
      };
    };
}
