{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    gitignore-repo.url = "github:github/gitignore";
    gitignore-repo.flake = false;
    editorconfig.url = "github:Ookiiboy/editor-config/";
    editorconfig.flake = false;
  };

  outputs = {
    self,
    systems,
    nixpkgs,
    pre-commit-hooks,
    editorconfig,
    gitignore-repo,
    ...
  }: let
    forAllSystems = nixpkgs.lib.genAttrs (import systems);
  in {
    formatter = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
    in
      pkgs.alejandra);
    checks = forAllSystems (system: {
      pre-commit-check = pre-commit-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          # Nix
          alejandra.enable = true;
          deadnix.enable = true;
          statix.enable = true;
          flake-checker.enable = true;
          # Generic - .editorconfig
          editorconfig-checker.enable = true;
        };
      };
    });

    devShells = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      default = pkgs.mkShell {
        name = "development";
        shellHook = ''
          ln -sf ${editorconfig}/.editorconfig ./.editorconfig
          ${self.checks.${system}.pre-commit-check.shellHook}
          ${self.lib.${system}.gitignore {
            github.languages = [];
            extraConfig = ''
              .editorconfig
              .pre-commit-config.yaml
            '';
          }}
        '';
        buildInputs = self.checks.${system}.pre-commit-check.enabledPackages;
      };
    });

    lib = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
    in rec {
      toptalGitignoreIo = arguments @ {
        languages ? [],
        hash ? "",
        # Allow variadic arguments so we have one API
        ...
      }:
        builtins.fetchurl {
          url = "https://www.toptal.com/developers/gitignore/api/${pkgs.lib.concatStringsSep "," arguments.languages}";
          name = "toptalGitignoreIo"; # Required as both "," and "%2C" are invalid store paths
          # For some godforsaken reason arguments.hash bombs on missing property
          sha256 = hash;
        };

      ignoreRepoFile = file:
      # ↓ By the way, how fucking cool is this?! ↓
        gitignore-repo + "/${file}.gitignore";

      ignoreDirenv = pkgs.writeText "ignoreDirenv" ''
        .direnv/
      '';
      saneDefaults = [
        "Global/macOS"
        "Global/Windows"
        "Global/Linux"
        "Global/Patch"
        "community/Nix"
      ];
      writeExtraConfig = extra: [
        (pkgs.writeText
          "extraConfig"
          ''
            # User Provided
            ${extra}
          '')
      ];
      generateGitIgnore = settings:
        pkgs.concatText ".gitignore" ([
            ignoreDirenv
          ]
          # Sane Defaults - Ingested
          ++ (
            if (!settings ? useSaneDefaults || settings.useSaneDefaults)
            then map ignoreRepoFile saneDefaults
            else []
          )
          # API Derrived Ignores
          ++ (
            if (builtins.hasAttr "gitignoreio" settings && builtins.hasAttr "languages" settings.gitignoreio)
            then [
              (toptalGitignoreIo {
                inherit (settings) gitignore;
                hash =
                  if (builtins.hasAttr "hash" settings.gitignoreio)
                  then settings.gitignoreio.hash
                  else "";
              })
            ]
            else []
          )
          ++ (
            if (builtins.hasAttr "github" settings && builtins.hasAttr "languages" settings.github)
            then map ignoreRepoFile settings.github.languages
            else []
          )
          ++
          # User Defined - These come last in the event that anything should be
          # overridden.
          (
            if builtins.hasAttr "extraConfig" settings
            then writeExtraConfig settings.extraConfig
            else []
          ));

      # We can't link the file in the store. What a crime. Gotta copy.
      gitignore = settings: ''
        cp -f ${generateGitIgnore settings} ./.gitignore
      '';
    });
  };
}
