{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    # Non-flake
    editorconfig.url = "github:Ookiiboy/editor-config/";
    editorconfig.flake = false;
  };

  outputs = {
    self,
    systems,
    nixpkgs,
    pre-commit-hooks,
    editorconfig,
    ...
  }: let
    forAllSystems = nixpkgs.lib.genAttrs (import systems);
  in {
    formatter = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
    in
      pkgs.alejandra);
    checks = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      pre-commit-check = pre-commit-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          # Nix
          alejandra.enable = true;
          deadnix.enable = true;
          statix.enable = true;
          flake-checker.enable = true;
          # Deno
          denofmt.enable = true;
          denolint.enable = true;
          # Shell Scripts
          shellcheck.enable = true;
          beautysh.enable = true;
          # JSON
          check-json.enable = true;
          # Github Actions
          actionlint.enable = true;
          # Generic - .editorconfig
          editorconfig-checker.enable = true;
          check-toml.enable = true;
          # CSS - .stylelint.json
          stylelint = {
            enable = true;
            name = "Stylelint";
            entry = "${pkgs.stylelint}/bin/stylelint --fix";
            files = "\\.(css)$";
            types = ["text" "css"];
            language = "system";
            pass_filenames = true;
          };
        };
      };
    });
    devShells = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
      gitIgnore = rec {
        ignoreRepoFile = file:
          pkgs.fetchFromGitHub {
            owner = "github";
            repo = "gitignore";
            rev = "main";
            hash = "sha256-A2n4LDn7nZ/Znj/ia6FbNZOYPLBylWQ034UrZqfoFLI=";
          }
          + /${file}.gitignore;

        ignoreDirenv = pkgs.writeText "ignoreSelf" ''
          .direnv/
        '';
        writeExtraConfig = extra:
          pkgs.writeText "extraConfig" ''
            # User Provided
            ${extra}
          '';
        generateGitIgnore = settings:
          pkgs.concatText ".gitignore" ([
              ignoreDirenv
              (
                if builtins.hasAttr "extraConfig" settings
                then writeExtraConfig settings.extraConfig
                else false
              )
            ]
            ++ map ignoreRepoFile settings.ignores);
        # We can't link .gitignore files
        place = settings: ''
          cp -f ${generateGitIgnore settings} ./.gitignore
        '';
      };
    in {
      default = pkgs.mkShell {
        name = "development";
        shellHook = ''
          ln -sf ${editorconfig}/.editorconfig ./.editorconfig
          ${self.checks.${system}.pre-commit-check.shellHook}
          ${gitIgnore.place {
            ignores = ["Node" "C++" "Android" "C" "ChefCookbook" "CommonLisp" "Global/macOS" "Global/Windows"];
            extraConfig = ''
              .editorconfig
              .pre-commit-config.yaml
            '';
          }}
        '';
        ENV = "dev";
        buildInputs = with pkgs;
          []
          ++ self.checks.${system}.pre-commit-check.enabledPackages;
      };
    });
  };
}
