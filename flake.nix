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
            ignores = [];
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
      ignoreRepoFile = file:
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
          ++
          # User Defined
          (
            if builtins.hasAttr "extraConfig" settings
            then writeExtraConfig settings.extraConfig
            else []
          )
          # Sane Defaults - Ingested
          ++ (
            if (!settings ? useSaneDefaults || settings.useSaneDefaults)
            then map ignoreRepoFile saneDefaults
            else []
          )
          # Ingested Ignores
          ++ (
            if (builtins.hasAttr "ignores" settings)
            then map ignoreRepoFile settings.ignores
            else []
          ));

      # We can't link the file in the store. What a crime. Gotta copy.
      gitignore = settings: ''
        cp -f ${generateGitIgnore settings} ./.gitignore
      '';
    });
  };
}
