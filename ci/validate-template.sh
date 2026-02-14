#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch_root="${repo_root}/.ci-scratch"
work_dir="${scratch_root}/template-validate"
host="ci-host"
user="ci-user"

case "$(uname -m)" in
  arm64|aarch64) system_arch="aarch64-linux" ;;
  x86_64|amd64) system_arch="x86_64-linux" ;;
  *) system_arch="aarch64-linux" ;;
esac

rm -rf "${work_dir}"
mkdir -p "${work_dir}"

cp "${repo_root}/flake.nix" "${work_dir}/flake.nix"

cat >"${work_dir}/hardware-configuration.nix" <<'EOF'
{ lib, ... }:
{
  # Container mode keeps the template validation lightweight and hardware-agnostic.
  boot.isContainer = true;
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
  };
  swapDevices = [ ];
  networking.useDHCP = lib.mkDefault true;
  networking.useHostResolvConf = lib.mkForce false;
}
EOF

python3 - <<'PY' "${work_dir}/flake.nix" "${host}" "${user}" "${system_arch}"
from pathlib import Path
import sys

flake_path = Path(sys.argv[1])
host = sys.argv[2]
user = sys.argv[3]
system_arch = sys.argv[4]

text = flake_path.read_text()

replacements = [
    ("pkgs-alpha = pkgsFor matrix.\"aarch64-linux\".unstable", f"pkgs-ci-host = pkgsFor matrix.\"{system_arch}\".unstable"),
    ("users.users.\"user\"", f"users.users.\"{user}\""),
    ('openssh.authorizedKeys.keys = [ "ssh-ed25519 <your_ssh_key_here>" ];', "openssh.authorizedKeys.keys = [ ];"),
    ("homeConfigurations.user =", f"homeConfigurations.{user} ="),
    ('username = "user";', f'username = "{user}";'),
    ("pkgs = pkgs-alpha;", "pkgs = pkgs-ci-host;"),
    ("pkgs = pkgs-alpha;", "pkgs = pkgs-ci-host;"),
    ("nixosConfigurations.alpha =", f"nixosConfigurations.{host} ="),
    (
        '# CHANGE ME: replace "aarch64-linux" with your architecture\n'
        '          system = "aarch64-linux";',
        '# CHANGE ME: replace "aarch64-linux" with your architecture\n'
        f'          system = "{system_arch}";'
    ),
    ("networking.hostName = \"alpha\";", f'networking.hostName = "{host}";'),
]

for old, new in replacements:
    if old not in text:
        raise SystemExit(f"Unable to patch template flake; missing expected text: {old}")
    text = text.replace(old, new, 1)

flake_path.write_text(text)
PY

cd "${work_dir}"
nix build -L --no-write-lock-file "path:.#nixosConfigurations.${host}.config.system.build.toplevel"
