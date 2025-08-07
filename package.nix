{ lib
, stdenv
, fetchurl
, bash
, gnutar
, gzip
, findutils
, coreutils
, file
}:

# Package OpenAI Codex CLI by consuming prebuilt GitHub release assets.
# Sources (URLs + hashes) are maintained in ./sources.json by CI.

let
  sources = builtins.fromJSON (builtins.readFile ./sources.json);
  system = stdenv.hostPlatform.system;
  srcInfo = sources.assets.${system} or null;
  isArchive = url: lib.any (s: lib.hasSuffix s url) [ ".zip" ".tar.gz" ".tgz" ".tar.xz" ];
  supported = srcInfo != null && srcInfo.url or "" != "" && srcInfo.sha256 or "" != "";
in
if supported then stdenv.mkDerivation {
  pname = "codex";
  version = sources.version;

  src = fetchurl { url = srcInfo.url; sha256 = srcInfo.sha256; };

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  preferLocalBuild = true;

  nativeBuildInputs = [ gnutar gzip findutils coreutils bash file ];

  installPhase = ''
    set -euxo pipefail
    mkdir -p $out/bin
    work="$PWD/extract"
    mkdir -p "$work"
    echo "tar at: $(command -v tar)"
    tar --version || true
    echo "src: $src"
    ls -l "$src" || true
    file "$src" || true
    case "$src" in
      *.tar.gz|*.tgz)
        tar -xzf "$src" -C "$work" ;;
      *.zip)
        echo "Zip archives are not supported in this build script" >&2; exit 1 ;;
      *)
        # Maybe it's a raw binary; copy as-is
        cp "$src" "$work/codex" || true ;;
    esac
    cd "$work"
    echo "Listing extracted files (top 200):"
    find . -maxdepth 4 -type f | head -n 200 | sed 's/^/  /'
    # Locate the codex binary within the asset (supports codex and codex-exec)
    candidate=$(find . -maxdepth 4 -type f 2>/dev/null | grep -E '/(bin/)?codex(-exec)?$' | head -n1 || true)
    if [ -z "$candidate" ] && [ -f "./codex" ]; then
      candidate="./codex"
    fi
    if [ -z "$candidate" ] && [ -f "./codex-exec" ]; then
      candidate="./codex-exec"
    fi
    if [ -z "$candidate" ]; then
      # Try any file named starting with codex
      candidate=$(find . -maxdepth 4 -type f -name 'codex*' | head -n1 || true)
    fi
    if [ -z "$candidate" ]; then
      # As a last resort, pick the first Mach-O or ELF file
      candidate=$(find . -maxdepth 4 -type f -size +1M -print0 | xargs -0 file | grep -E 'Mach-O|ELF' | cut -d: -f1 | head -n1 || true)
    fi
    if [ -z "$candidate" ]; then
      echo "Could not locate executable 'codex' in release asset" >&2
      find . -maxdepth 4 -type f -perm -u+x >&2 || true
      exit 1
    fi

    # Install the actual binary
    install -Dm755 "$candidate" "$out/bin/codex-bin" || {
      # Fallback: copy then chmod if install -m fails due to perms
      mkdir -p "$out/bin"
      cp -f "$candidate" "$out/bin/codex-bin"
      chmod 0755 "$out/bin/codex-bin"
    }

    # Create wrapper to:
    # - Provide stable path for macOS permission persistence
    # - Disable any auto-updater behavior (if present)
    cat > $out/bin/codex << 'EOF'
#!${bash}/bin/bash

# Stable executable path to avoid macOS permission prompts resetting
export CODEX_EXECUTABLE_PATH="$HOME/.local/bin/codex"

# Disable auto-update if upstream supports env override
export DISABLE_AUTOUPDATER=1

# Create stable symlink for macOS if not managed by Home Manager
if [[ "$OSTYPE" == "darwin"* ]]; then
  mkdir -p "$HOME/.local/bin"
  if [[ -z "$__HM_SESS_VARS_SOURCED" ]] \
     && [[ ! -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]] \
     && [[ ! -f "/etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh" ]]; then
    ln -sf "$out/bin/codex" "$HOME/.local/bin/codex"
  fi
fi

exec "$out/bin/codex-bin" "$@"
EOF
    chmod +x $out/bin/codex

    # Replace $out placeholder with actual path
    substituteInPlace $out/bin/codex --replace '$out' "$out"
  '';

  meta = with lib; {
    description = "OpenAI Codex CLI packaged for Nix (from GitHub releases)";
    homepage = "https://github.com/openai/codex";
    license = licenses.mit; # Adjust if upstream differs
    platforms = builtins.attrNames sources.assets;
    mainProgram = "codex";
    maintainers = [];
  };
} else stdenv.mkDerivation {
  pname = "codex";
  version = sources.version;
  dontUnpack = true;
  installPhase = ''
    echo "Codex binary not available for ${system} or sources.json not populated yet." >&2
    echo "Please run the updater workflow and ensure assets exist for this platform." >&2
    exit 1
  '';
  meta = with lib; {
    description = "OpenAI Codex CLI packaged for Nix (unavailable for this platform)";
    homepage = "https://github.com/openai/codex";
    license = licenses.mit;
    platforms = [ system ];
    mainProgram = "codex";
  };
}
