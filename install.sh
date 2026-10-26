#!/usr/bin/env bash
# Install jenkins-local for this user: link the command into ~/.local/bin and check that
# everything it needs is here. Safe to run again (e.g. after moving the repo).
set -euo pipefail

# realpath is missing before macOS 13; perl's abs_path also resolves symlinks.
repo=$(cd "$(dirname "$(perl -MCwd -e 'print Cwd::abs_path(shift)' "$0")")" && pwd)
bin=$HOME/.local/bin
secrets=${XDG_CONFIG_HOME:-$HOME/.config}/jenkins-local/secrets

missing=()
for cmd in bash git perl curl docker; do
  command -v "$cmd" >/dev/null || missing+=("$cmd")
done
[ ${#missing[@]} -eq 0 ] || { echo "Install first: ${missing[*]}" >&2; exit 1; }
docker info >/dev/null 2>&1 \
  || { echo "Docker is not usable by $(id -un): start it, or add yourself to the docker group." >&2; exit 1; }

mkdir -p "$bin" "$secrets"
chmod 700 "$secrets"
ln -sfn "$repo/bin/jenkins-local" "$bin/jenkins-local"
echo "Linked $bin/jenkins-local -> $repo/bin/jenkins-local"

case ":$PATH:" in
  *":$bin:"*) ;;
  *) echo "Add $bin to PATH, e.g. in ~/.bashrc:  export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac
echo "Next: jenkins-local selftest   (checks everything works; then jenkins-local help)"
