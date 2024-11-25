# IgnoreBoy

## What is this?

This is a nix-shell lib that helps you create best practiace `.gitignore` files
by using
[Githubs Default .gitignore Templates](https://github.com/github/gitignore). No
longer will you be held back by the tyrany of copy and pasting shit from around
the internet!

## How do you use this?

It should look something like the below. We've left out non-related code for
brevity.

```nix
{
  inputs = {
    # ...
    ignoreBoy.url = "github:Ookiiboy/ignoreBoy";
  };

  outputs = {
    # ...
    ignoreBoy,
    ...
  } @ inputs: let
    forAllSystems = nixpkgs.lib.genAttrs (import systems);
  in {
    devShells = forAllSystems (system: {
      default = 
        pkgs.mkShell {
          shellHook = ''
            # ...
            ${ignoreBoy.lib.${system}.gitignore {
              ignores = ["Node" "community/JavaScript/Vue"]; 
              # https://github.com/github/gitignore - use this repo, and add 
              # the filename and/ or path/filename to the array, drop the extension.
              useSaneDefaults = true; 
              # Defaults to true, but you can set to false if you don't want OS
              # related ignores
              extraConfig = ''
                # Anything Custom you might want to be placed here.
                .editorconfig
                .pre-commit-config.yaml
              '';
            }}
            # ...
          '';
          buildInputs = with pkgs; [
            # ...
          ];
        };
    });
    };
  }
```
