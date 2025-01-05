# IgnoreBoy

## What is this?

This is a nix-shell lib that helps you create best practice `.gitignore` files
by using
[Githubs Default .gitignore Templates](https://github.com/github/gitignore). No
longer will you be held back by the tyrany of copy and pasting files from around
the internet! Let this copy paste for you!

## Why would I use this? Like, my guy, I almost never touch my `.gitignore`.

There are a few reasons that you might enjoy using this:

- Codebases with diverse languages often tend to have a `.gitignore` that are
  sparse, and don't use best practices.
- If you're setting up a development environment for a new codebase, you might
  not event know what a best practice code `.gitignore` looks like! Take the
  [Julia](https://github.com/github/gitignore/blob/main/Julia.gitignore)
  language for example. I didn't know it looked like that.
- You could _just_ copy and paste these templates, but keeping track, and
  checking for updates (if ever!) is annoying, and might be at the very bottom
  of your todo list.
- For the low-low price of using this, there are some
  [sane defaults built-in](https://github.com/Ookiiboy/ignoreBoy/blob/main/flake.nix#L71C1-L76C24).
  All the stuff you forget to add (or never add but should), now added by
  default!
- Did a goddamned Node.js project get added to your codebase by Alice. Don't
  know what to add to the `.gitignore`? Add `"Node"` to the array and be done
  with it.

## Okay, I want to at least give it a whirl. How do you use this?

It should look something like the below. We've left out non-related code for
brevity. In short, add it to your inputs, and have it run in your shellhook of
your main devshell.

```nix

# 1. https://github.com/github/gitignore - use this repo, and add the filename
#    and/ or path/filename to the array, drop the extension. Note the uppercase
#    filenames.
# 2. `curl -sL https://www.toptal.com/developers/gitignore/api/list`; this
#    will give you a list of supported languages.
# 3. GOTCHA: This will fail on first run, you will need to copy the hash into 
#    the attribute. **Everytime** you update the `gitignoreio.languages`, delete
#    the hash, re-run the shell, and copy the updated hash back into the 
#    attribute after the next fail again. This will force the input to refresh,
#    and make a new API request. Otherwise it will remain cached.
# 4. Defaults to t`rue`, but you can set to false if you don't want OS related 
#    ignores. You don't uusually need to specify. It's here for clarity.
# 5. Anything custom you might want in your .gitignore you can place in this
#    extraConfig.

{
  inputs = {
    # ...
    systems.url = "github:nix-systems/default";
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
              github.languages = ["Node" "community/JavaScript/Vue"]; # 1
              gitignoreio.languages = ["node"]; # 2
              gitignoreio.hash = ""; # 3
              useSaneDefaults = true; # 4
              extraConfig = ''
                .editorconfig
                .pre-commit-config.yaml
              ''; # 5
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
