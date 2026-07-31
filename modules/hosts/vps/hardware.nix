{ ... }:
{
  flake.nixosModules.vpsHardware = { lib, ... }: {
    boot.initrd.availableKernelModules = [
      "virtio_pci"
      "virtio_blk"
      "virtio_scsi"
      "virtio_net"
      "sd_mod"
    ];

    nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
  };
}
