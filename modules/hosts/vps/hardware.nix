{ ... }:
{
  flake.nixosModules.vpsHardware = { lib, ... }: {
    boot.initrd.availableKernelModules = [
      "virtio_pci"
      "virtio_blk"
      "virtio_net"
    ];

    nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
  };
}
