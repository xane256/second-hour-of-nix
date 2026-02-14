# justfile for nix configurations

hostname := shell('hostname -s')

alias rb := rebuild
alias ts := test
alias rbh := rebuild-host

_default:
    just --list

### MAIN FUNCTIONS

# Rebuild & activate NixOS configuration for the current system and update the bootloader.
rebuild:
    sudo nixos-rebuild --flake .#{{hostname}} --show-trace --print-build-logs switch
    just home

# Rebuild Home Manager configuration for current user.
home:
    # This searches flake outputs `homeConfigurations.*`
    # home-manager switch --flake .#user
    home-manager switch --flake .

# Build & activate current host but don't update bootloader.
test:
    sudo nixos-rebuild --flake .#{{hostname}} --show-trace --print-build-logs --no-reexec test

# Build `HOST`'s configuration without touching the system and put the built files in `./result/`
validate HOST:
    nix build -L .#nixosConfigurations.{{HOST}}.config.system.build.toplevel

# Template validation: copy flake.nix into ignored scratch dir,
# patch CHANGE ME defaults, and build a synthetic host.
validate-template:
    ./ci/validate-template.sh

### HOST-SPECIFIC FUNCTIONS

# Invoke another function specific to this host
rebuild-host:
    just _rebuild-{{hostname}}

_rebuild-alpha:
    sudo nixos-rebuild --flake .#{{hostname}} --show-trace dry-build
