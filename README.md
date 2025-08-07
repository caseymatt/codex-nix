# codex-nix

Always up-to-date Nix package for the OpenAI Codex CLI.

Automatically checks GitHub releases daily and opens a PR with updated sources and hashes, so you can stay current without Homebrew or npm.

## Why

- Avoid package managers (Homebrew/npm) for system tools
- Keep Codex updated automatically via GitHub Actions
- Use from Nix/Home Manager across macOS and Linux

## Quick Start

### Run directly

```bash
nix run github:YOUR_GH_USERNAME/codex-nix
```

### Install to profile

```bash
nix profile install github:YOUR_GH_USERNAME/codex-nix
```

### As an overlay (flakes)

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    codex-nix.url = "github:YOUR_GH_USERNAME/codex-nix";
  };

  outputs = { self, nixpkgs, codex-nix, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        { nixpkgs.overlays = [ codex-nix.overlays.default ];
          environment.systemPackages = [ pkgs.codex ];
        }
      ];
    };
  };
}
```

### Home Manager

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    codex-nix.url = "github:YOUR_GH_USERNAME/codex-nix";
  };

  outputs = { self, nixpkgs, home-manager, codex-nix, ... }: {
    homeConfigurations."your-user" = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs { system = "x86_64-darwin"; }; # adjust
      modules = [
        { nixpkgs.overlays = [ codex-nix.overlays.default ];
          home.packages = [ pkgs.codex ];
        }
      ];
    };
  };
}
```

## How it works

- `package.nix` reads `sources.json` and installs the prebuilt `codex` binary
- `update-codex.yml` fetches the latest GitHub release, computes sha256 for each asset, and updates `sources.json`
- `build.yml` builds and smoke-tests on macOS/Linux

## Updating manually

- Edit `codex-nix/sources.json` with the desired `version` and asset URLs/hashes
- Build locally: `nix build .#codex && ./result/bin/codex --version`
- Commit and push

## Notes

- Linux builds may need additional runtime libraries depending on upstream’s build; this derivation installs the binary as-is
- If upstream changes asset naming, the update workflow’s patterns may need adjustment

## License

Nix packaging is MIT. Upstream Codex is under its own license.

## Optional: Enable Cachix (faster installs)

To use prebuilt binaries from CI builds, configure Cachix:

```bash
# Install cachix if needed
nix-env -iA cachix -f https://cachix.org/api/v1/install

# Use the cache
cachix use caseymatt
```

Or add to your Nix config:

```nix
{
  nix.settings = {
    substituters = [ "https://caseymatt.cachix.org" ];
    trusted-public-keys = [ "caseymatt.cachix.org-1:4ibk5HdiGrczujjkgrqXt43UGOGufm4JtBvtQYvRRac=" ];
  };
}
```

CI pushes to Cachix on the `main` branch when builds succeed. Set the `CACHIX_AUTH_TOKEN` secret in your GitHub repo.
