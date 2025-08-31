# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is `codex-nix`, a Nix package repository that provides always up-to-date packaging for the OpenAI Codex CLI. The project automatically tracks GitHub releases and maintains current binaries across multiple platforms without relying on traditional package managers.

## Development Commands

### Building and Testing
```bash
# Build the codex package
nix build .#codex

# Test the built binary
./result/bin/codex --version

# Run codex directly without installing
nix run .

# Enter development shell with all tools
nix develop

# Format Nix code
nixpkgs-fmt *.nix
```

### Development Shell Tools
The `nix develop` command provides access to:
- `nixpkgs-fmt` for Nix code formatting
- `jq` for JSON processing (sources.json)
- `curl` for HTTP requests
- `cachix` for binary cache management
- `gh` for GitHub CLI operations

## Architecture

### Core Components

**Flake Structure**: The project follows modern Nix flake patterns with `flake.nix` as the entry point, providing packages, apps, overlays, and development environments for multiple platforms.

**Package Definition**: `package.nix` contains the main derivation logic that:
- Reads platform-specific metadata from `sources.json`
- Downloads prebuilt binaries with SHA256 verification
- Creates wrapper scripts for macOS stability
- Handles cross-platform binary detection and installation

**Sources Management**: `sources.json` is auto-generated and contains version information, download URLs, and cryptographic hashes for each supported platform (x86_64-darwin, aarch64-darwin, x86_64-linux, aarch64-linux).

### Automation Pipeline

**Daily Updates**: `.github/workflows/update-codex.yml` runs at 03:00 UTC to:
- Check for new GitHub releases via API
- Download assets and compute SHA256 hashes using OpenSSL
- Update `sources.json` with new metadata
- Create pull requests with version updates

**Build Pipeline**: Automated builds occur on main branch changes, with artifacts cached to Cachix for faster user downloads.

### Platform-Specific Considerations

**macOS Handling**: The package creates stable symlinks at `$HOME/.local/bin/codex` to prevent repeated macOS permission prompts. Wrapper scripts handle executable persistence issues specific to macOS security model.

**Binary Detection**: Robust logic handles various upstream packaging formats, preferring compressed archives over raw binaries and detecting both `codex` and `codex-exec` naming conventions.

## Key Files

- `flake.nix` - Main flake configuration and package definitions
- `package.nix` - Core packaging logic and derivation
- `sources.json` - Auto-generated version and asset metadata
- `.github/workflows/update-codex.yml` - Automated update pipeline
- `.github/workflows/build.yml` - Main branch build and caching

## Testing

Always test changes with:
```bash
nix build .#codex && ./result/bin/codex --version
```

For cross-platform testing, the GitHub Actions will build for all supported platforms on pull requests.

## Automation Notes

The update workflow automatically handles routine maintenance. Manual intervention is only needed for:
- Upstream packaging format changes
- New platform support
- Breaking changes in the Codex CLI interface

When modifying automation, test changes in feature branches as the workflows will run on all PRs but only deploy from main.