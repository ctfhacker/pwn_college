{
  description = "pwn.college dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; };
      python = pkgs.python311.withPackages (p: with p; [ 
        pwntools 
        ipython 
        ipdb
      ]);

      download_script = pkgs.writeShellApplication {
        name = "download";
        text = ''
          CHAL=$(ssh hacker@dojo.pwn.college hostname)
          OUTDIR="challenges/$CHAL"

          if [ ! -d "$OUTDIR" ]; then
            mkdir -p "$OUTDIR"
            scp -r hacker@dojo.pwn.college:/challenge/* "$OUTDIR"

            echo "Downloaded files in $OUTDIR:"
            ls -la "$OUTDIR"
          else
            echo "Already downloaded files in $OUTDIR:"
            ls -la "$OUTDIR"
          fi
        '';
      };
    in
    {
      devShells.default = pkgs.mkShell {
        buildInputs = [ 
          python 
          pkgs.pkgsCross.aarch64-multiplatform.buildPackages.binutils
        ];

        shellHook = ''
          echo "Welcome to the pwn.college dev shell!"
          export PYTHONPATH=$PWD
        '';
      };

      apps.download = flake-utils.lib.mkApp { drv = download_script; };
    });
}

