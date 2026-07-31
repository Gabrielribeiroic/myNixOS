# ❄️ myNixOS
A modular, Flake-based NixOS configuration for my personal and professional use.

## Features
- **Desktop:** GNOME (Wayland) with custom shortcuts and power settings
- **Hardware:** NVIDIA Prime Sync & custom `lenovo-legion` kernel module fan profiles
- **Secrets Management:** [`sops-nix`](https://github.com/mic92/sops-nix) with Age encryption
- **Shell:** Fish Shell + Home Manager

I took most of my inspiration from [vimjoyer](https://www.vimjoyer.com/) after seeing [this video.](https://youtu.be/aNgujRXDTdE)
Of course, this is very basic and lacks proper documentation, but I plan to make this configuration more robust as time goes on.

## Oracle ARM VPS

The `vps` configuration targets an Oracle Always Free ARM instance with a single
`/dev/sda` boot volume. `nixos-anywhere` destroys that disk and creates a 1 GiB
EFI system partition plus an ext4 root filesystem. It installs systemd-boot to
the UEFI fallback path, avoiding a dependency on OCI UEFI NVRAM entries.

Before installation, ensure the OCI Security List or Network Security Group
permits TCP port 22 from your current public IP. The existing Ubuntu instance
must accept `root` SSH with your key. Run these commands on a machine with Nix
and network access to the instance:

```bash
nix flake lock
nix flake check
nix eval .#nixosConfigurations.vps.config.system.build.toplevel.drvPath

KEXEC="$(sudo nix build --accept-flake-config --print-out-paths github:nix-community/nixos-images#packages.aarch64-linux.kexec-installer-nixos-unstable-noninteractive)/nixos-kexec-installer-noninteractive-aarch64-linux.tar.gz"

umask 077
nix run github:nix-community/nixos-anywhere -- \
  --build-on remote \
  --kexec "$KEXEC" \
  --flake .#vps \
  --target-host root@<oracle-public-ip>
```

Commit the resulting `flake.lock` before installation so the deployed input set
is reproducible.

In Fish, use `set KEXEC (...)` instead of Bash's `KEXEC=...` assignment. SSH
private keys passed with `-i` must be owned by you and have mode `0600`.

`--build-on remote` builds the system in the temporary ARM installer, so the
source machine does not need AArch64 emulation. The command destroys the
current Ubuntu installation. After it completes, remove the old SSH host key
and log in as `zep`:

```bash
ssh-keygen -R <oracle-public-ip>
ssh zep@<oracle-public-ip>
sudo tailscale up
```

Tailscale requires interactive authentication unless an encrypted auth key is
added later. Syncthing and public web ports are intentionally not configured.

### Updates

Commit and push changes from your development machine. On the VPS, clone the
repository once and rebuild natively:

```bash
git clone https://github.com/Gabrielribeiroic/myNixOS.git ~/myNixOS
cd ~/myNixOS
sudo nixos-rebuild switch --flake .#vps
```

For later changes:

```bash
cd ~/myNixOS
git pull --ff-only
sudo nixos-rebuild switch --flake .#vps
```

### Colmena deployments

The pinned Colmena output deploys to the Oracle VPS as `zep`, uses passwordless
sudo for activation, and builds the AArch64 closure on the VPS. The target IP is
defined in `modules/colmena.nix`; update it if OCI assigns a different public
IP.

From your development machine, first confirm the remote SSH connection, then
build or apply the selected node:

```bash
ssh zep@164.152.53.60 true
nix run .#colmena -- build --on vps
nix run .#colmena -- apply --on vps
```

`build` realizes the closure on the target without activation. `apply` builds,
copies the required store paths, and activates the selected configuration. Use
`--on @oracle` to target every node with the `oracle` deployment tag.

Colmena deploys the local checkout, so a Git push is not required before
`apply`. Commit and push after a successful deployment to record the exact
configuration running on the VPS and keep the VPS checkout available for
emergency local rebuilds.

`zep` has passwordless sudo because the account is SSH-key-only and needs to
perform NixOS rebuilds. Review `nixos-rebuild switch` output before rebooting;
use OCI Console Connection if networking or boot configuration is ever broken.
