{
  description = "pwn.college dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, flake-utils, rust-overlay, ... }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { 
        inherit system; 
        overlays = [ (import rust-overlay) ];
      };

      python = pkgs.python311.withPackages (p: with p; [ 
        pwntools 
        ipython 
        ipdb
        ropper
      ]);

      armpkgs = pkgs.pkgsCross.aarch64-multiplatform.pkgs;

      download_script = pkgs.writeShellApplication {
        name = "download";
        text = ''
          CHAL=$(ssh hacker@dojo.pwn.college hostname)
          OUTDIR="challenges/$CHAL"

          if [ ! -d "$OUTDIR" ]; then
            mkdir -p "$OUTDIR"

            ssh hacker@dojo.pwn.college "tar cf chal.tar /challenge/* && cat chal.tar" > "$OUTDIR"/chal.tar

            (
              # Go to the output directory
              cd "$OUTDIR"

              # Extract the challenge files
              tar xvf chal.tar
              mv challenge/* .
              rmdir challenge
              rm chal.tar

              # Patch the aarch64 binaries if there are any
              FILES=$(ls)
              for f in $FILES; do
                if file "$f" | grep -q "ARM aarch64"; then
                  ${pkgs.patchelf}/bin/patchelf --replace-needed libcapstone.so.4 ${armpkgs.capstone}/lib/libcapstone.so.5 "$f"
                  ${pkgs.patchelf}/bin/patchelf --set-interpreter ${armpkgs.glibc}/lib/ld-linux-aarch64.so.1 "$f"
                fi
              done
            )

            echo "Downloaded files in $OUTDIR:"
            ls -la "$OUTDIR"
          else
            echo "Already downloaded files in $OUTDIR:"
            ls -la "$OUTDIR"
          fi

          # Replace the #! with local python
          fd . "$OUTDIR" | xargs sed -i 's_/opt/pwn.college/python_/usr/bin/env python_g'

          # Initialize basic win script
          cp win.py "$OUTDIR"

          echo Script written to "$OUTDIR"/win.py
        '';
        };

      exploit_script = pkgs.writeShellApplication {
        name = "exploit";
        text = ''
          CHAL=$(ssh hacker@dojo.pwn.college hostname)
          OUTDIR="challenges/$CHAL"

          ssh hacker@dojo.pwn.college mkdir -p /home/hacker/"$OUTDIR"
          REMOTE_FILE="/home/hacker/$OUTDIR/win.py"
          cat "$OUTDIR"/win.py | ssh hacker@dojo.pwn.college "cat - > $REMOTE_FILE"
          ssh hacker@dojo.pwn.college python3 /home/hacker/"$OUTDIR"/win.py
        '';


        excludeShellChecks = [ 
          "SC2029" # Note that, unescaped, this expands on the client side.
          "SC2002" # Useless cat. Consider 'cmd < file | ..' or 'cmd file | ..' instead.
        ];
      };

    in
    {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [ 
          rust-bin.stable.latest.default
          rust-analyzer
          pkg-config

          python 
          qemu
          ropgadget

          pwndbg
        ];

        shellHook = ''
          export PYTHONPATH=$PWD
          export PATH=$PWD:$PATH

          # Rename pwndbg to gdb for `pwntools` to pick up the gdb
          ln -s ${pkgs.pwndbg}/bin/pwndbg gdb

          echo "Welcome to the pwn.college dev shell!"
        '';
      };

      apps.download = flake-utils.lib.mkApp { drv = download_script; };
      apps.win = flake-utils.lib.mkApp { drv = exploit_script; };
    });
}

