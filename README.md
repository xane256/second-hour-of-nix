# Jumpstart Flake

This flake contains several NixOS & Home Manager modules to get your brand new system up and running with a handful of developer tools.
The flake is organized into several NixOS modules which can be added / removed individually from the `nixosConfigurations.*` settings for your system.

## 0. Download This Flake:

    nix --extra-experimental-features 'nix-command flakes' run nixpkgs#git -- clone https://github.com/xane256/second-hour-of-nix.git
    cd second-hour-of-nix

## 1. Hardware Configuration

    # Copy your existing configuration.nix & hardware-configuration.nix
    cp /etc/nixos/*configuration.nix .

    # OR regenerate it here
    nixos-generate-config --dir .

## 2. Enable flakes via alias

Source the shell script until your config enables flakes:

    # create `nixf` alias
    # alias nixf="nix --extra-experimental-features 'nix-command flakes'"
    . ./nixenv.sh

## 3. Update the flake with your username, hostname, and architecture

    # use the alias
    nixf shell nixpkgs#vim

Search for "CHANGE ME" in the flake:

- Replace `"user"` with your username
- Replace `"aarch64-linux"` with your architecture
- Replace `"alpha"` with your hostname

## 4. Apply the configuration

    # Before your first reboot, you must specify your hostname:
    sudo nixos-rebuild --flake .#<hostname> -L --show-trace switch
    home-manager --flake .#<username> switch

    # After you install `just` and have the correct hostname:
    just rebuild

## 5. Fix rebuild errors

If the rebuild fails because of "conflicting values" or a value defined in multiple places, it's because the flake configured one of a few settings already defined in your `configuration.nix` or `hardware-configuration.nix`.

- -> Fix these errors by commenting out the offending lines from `configuration.nix` or `hardware-configuration.nix`. The error will say which file is conflicting.

You'll probably need to fix the following:

- `networking.useDHCP` in `hardware-configuration.nix` -> comment this out (redundant with flake)
- `networking.networkmanager.enable = true` in `configuration.nix` -> comment this out (conflicts with default flake settings)
- `networking.hostName = "nixos"` in `configuration.nix` -> comment this out (conflicts with flake)
- `nixpkgs.config.*` in `configuration.nix` -> comment this out (conflicts with the way flake constructs & configures nixpkgs)

# Background

**Why do I need to comment those lines?**

- Running `sudo nixos-rebuild --flake .#alpha switch` will gracefully fail when two different nix modules (different nix files) define the same setting, like `networking.useDHCP`, when the value is a literal string, boolean, or integer.

**Why does the flake define those things in the first place?**

- Networking: I think it's nice to have all the networking settings in one place.
- Hostname: Your hostname should be consistent across the 4-5 places in the flake where it occurs.
  - `nixosConfigurations.alpha` should match `networking.hostName = "alpha"` because `sudo nixos-rebuild --flake . switch` looks for nixosConfigurations with your hostname.
  - `pkgs-alpha` is a local variable in the flake you can think of as an "instance" of nixpkgs for your system. It includes your system architecture, unfree settings, and "overlays". This flake constructs `pkgs-alpha` once and passes it as an argument to `inputs.home-manager-unstable.lib.homeManagerConfiguration` for homeConfigurations and `system_builder` for nixosConfigurations. There are other ways to configure nixpkgs, but this way aligns pkgs between home-manager and your system while still allowing you to rebuild your home and system configurations independently.
- `nixpkgs.config`: This is a different way to configure nixpkgs, incompatible with this flake.
