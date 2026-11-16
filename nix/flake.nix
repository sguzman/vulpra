{
  description = "Vulpra's isolated, Linux-first Firefox development toolchain (not a browser release)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      lib = pkgs.lib;

      # Keep this flake in nix/, not the ~3GB Firefox root. The source and
      # existing obj-vulpra-linux directory never enter the Nix store.
      coreTools = with pkgs; [
        bashInteractive
        fish
        coreutils
        findutils
        gnugrep
        gnused
        gawk
        diffutils
        which
        util-linux
        git
        cacert
        curl
        jq
        gnumake
        pkg-config
        cmake
        ninja
        autoconf213
        clang
        llvmPackages.lld
        llvmPackages.llvm
        bintools
        rustc
        cargo
        rustfmt
        clippy
        rust-analyzer
        cbindgen
        nasm
        yasm
        nodejs
        python3
        zip
        unzip
        gnutar
        gzip
        bzip2
        xz
        zstd
        openssl
        patchelf
        file
        shellcheck
      ];

      # Build-time headers and desktop/runtime integration libraries.
      # This does not replace the user's established local WASI mozconfig.
      geckoTools = with pkgs; [
        glib
        gtk3
        dbus
        cairo
        pango
        gdk-pixbuf
        atk
        libnotify
        libffi
        zlib
        libpng
        libjpeg_turbo
        libwebp
        libevent
        sqlite
        nspr
        nss
        freetype
        fontconfig
        harfbuzz
        alsa-lib
        libpulseaudio
        libdrm
        libva
        libGL
        mesa
        wayland
        wayland-protocols
        libxkbcommon
        xorg.libX11
        xorg.libXext
        xorg.libXrender
        xorg.libXcomposite
        xorg.libXdamage
        xorg.libXt
        xorg.libXi
        xorg.libXrandr
        xorg.libXcursor
        xorg.libXfixes
        xorg.libXinerama
        xorg.libxcb
      ];

      qaTools = with pkgs; [
        geckodriver
        weston
        wayland-utils
        strace
        gdb
      ];

      devCli = pkgs.writeShellApplication {
        name = "vulpra-dev";
        runtimeInputs = with pkgs; [
          bash
          coreutils
          git
          gnugrep
          findutils
          jq
          util-linux
          python3
        ];
        text = builtins.readFile ./vulpra-dev.sh;
      };

      toolingShell = pkgs.mkShell {
        name = "vulpra-linux-developer";
        packages = coreTools ++ geckoTools ++ qaTools ++ [ devCli pkgs.nixfmt ];
        # Avoid PYTHONPATH/LD_LIBRARY_PATH overrides and avoid re-pointing
        # MOZCONFIG: the workstation has an already-tested WASI override.
        shellHook = ''
          export VULPRA_NIX_DEV=1
          export VULPRA_TOOLCHAIN_SYSTEM="x86_64-linux"
          printf 'Vulpra Nix toolchain active (Linux x86_64); use vulpra-dev help.\n'
          printf 'Firefox/Hyprland profiles and existing obj directories are untouched.\n'
        '';
      };
    in
    {
      devShells.${system}.default = toolingShell;
      packages.${system} = { default = devCli; vulpra-dev = devCli; };
      apps.${system} = {
        default = {
          type = "app";
          program = "${devCli}/bin/vulpra-dev";
        };
        vulpra-dev = {
          type = "app";
          program = "${devCli}/bin/vulpra-dev";
        };
      };
      formatter.${system} = pkgs.nixfmt;

      # Lightweight actual Nix derivation smoke gate (no Firefox build).
      checks.${system}.script-contract = pkgs.runCommand
        "vulpra-nix-script-contract"
        { nativeBuildInputs = [ pkgs.bash pkgs.shellcheck pkgs.gnugrep ]; }
        ''
          bash -n ${./vulpra-dev.sh}
          shellcheck -S warning ${./vulpra-dev.sh}
          grep -Fq 'VULPRA_NIX_DEV' ${./vulpra-dev.sh}
          grep -Fq 'ci/build-local.sh' ${./vulpra-dev.sh}
          mkdir -p "$out"
          echo 'PASS: syntax, shellcheck and native wrapper contracts' > "$out/report"
        '';
    };
}
