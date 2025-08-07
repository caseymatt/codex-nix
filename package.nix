{ lib
, stdenvNoCC
, fetchzip
, fetchurl
, bash
}:

# Package OpenAI Codex CLI by consuming prebuilt GitHub release assets.
# Sources (URLs + hashes) are maintained in ./sources.json by CI.

let
  sources = builtins.fromJSON (builtins.readFile ./sources.json);
  system = stdenvNoCC.hostPlatform.system;
  srcInfo = sources.assets.${system} or null;
  isArchive = url: lib.any (s: lib.hasSuffix s url) [ ".zip" ".tar.gz" ".tgz" ".tar.xz" ];
in
assert (srcInfo != null) || (throw ''
  No release asset found for system: ${system}
  Please run the update workflow to populate sources.json.
'');
stdenvNoCC.mkDerivation {
  pname = "codex";
  version = sources.version;

  src = if (isArchive srcInfo.url)
        then fetchzip { url = srcInfo.url; sha256 = srcInfo.sha256; }
        else fetchurl { url = srcInfo.url; sha256 = srcInfo.sha256; };

  dontConfigure = true;
  dontBuild = true;
  preferLocalBuild = true;

  installPhase = ''
    mkdir -p $out/bin
    if [ -d "$src" ]; then
      cd "$src"
    fi
    # Locate the codex binary within the asset
    candidate=$(find . -type f -maxdepth 3 -name codex -perm -u+x 2>/dev/null | head -n1)
    if [ -z "$candidate" ] && [ -f "./codex" ]; then
      candidate="./codex"
    fi
    if [ -z "$candidate" ]; then
      echo "Could not locate executable 'codex' in release asset" >&2
      find . -maxdepth 3 -type f -perm -u+x >&2 || true
      exit 1
    fi

    # Install the actual binary
    install -Dm755 "$candidate" "$out/bin/codex-bin"

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
}
