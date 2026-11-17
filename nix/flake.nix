{
  description = "Vulpra's isolated, Linux-first Firefox development toolchain (not a browser release)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      lib = pkgs.lib;
      # WASI cross Clang includes target compiler-rt builtins missing from
      # host unwrapped Clang. Use this for WebAssembly only.
      wasiCc = pkgs.pkgsCross.wasi32.stdenv.cc;
      # The cross C++ libraries used by Mozilla's WASI probes belong only
      # on the wasm32 linker search path, never in native NIX_LDFLAGS.
      wasiLibcxx = pkgs.pkgsCross.wasi32.llvmPackages.libcxx;
      wasiCxx = pkgs.writeShellScript "vulpra-wasi-cxx" ''
        exec "${wasiCc}/bin/${wasiCc.targetPrefix}clang++" \
          -L"${wasiLibcxx}/lib" "$@"
      '';

      # Fontconfig's *Nixpkgs-generated* fonts.conf explicitly includes
      # /etc/fonts/conf.d even when FONTCONFIG_FILE points into the store.
      # On newer Arch, this imports XML unsupported by pinned Fontconfig
      # 2.17 (xsi:nil and new family constants). Create a private config
      # that uses the matching pinned rule set, but still indexes physical
      # system fonts and XDG user fonts. No /etc/fonts edits.
      fontconfigConfig = pkgs.runCommand "vulpra-fontconfig-config" { } ''
        mkdir -p "$out/etc/fonts"
        cp "${pkgs.fontconfig.out}/etc/fonts/fonts.conf" "$out/etc/fonts/fonts.conf"
        substituteInPlace "$out/etc/fonts/fonts.conf" \
          --replace-fail "/etc/fonts/conf.d" "${pkgs.fontconfig.out}/etc/fonts/conf.d"
        # Nix's upstream config otherwise scans only bundled DejaVu
        # and XDG fonts. Keep fonts installed by Arch visible without
        # importing Arch's newer rule XML.
        substituteInPlace "$out/etc/fonts/fonts.conf" \
          --replace-fail "</fontconfig>" \
          "<dir>/usr/share/fonts</dir>
           <dir>/usr/local/share/fonts</dir>
           </fontconfig>"
      '';

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
        autoconf
        clang
        # Mozilla's WebAssembly configure probes must bypass Nix's host
        # cc-wrapper (its hardening flags are invalid for wasm32-wasi).
        llvmPackages.clang-unwrapped
        # Gecko bindgen needs the *shared* libclang, not just clang++.
        llvmPackages.libclang.lib
        # Do not put the WASI cross CC in mkShell packages: its setup inputs
        # leak wasm32 libgcc into native x86_64 linker flags. The absolute
        # WASM_CC/WASM_CXX references in shellHook below keep it realized.
        sccache
        llvmPackages.lld
        llvmPackages.llvm
        bintools
        rustc
        cargo
        rustfmt
        clippy
        rust-analyzer
        rust-cbindgen
        nasm
        yasm
        nodejs-slim
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
        libx11
        libxext
        libxrender
        libxcomposite
        libxdamage
        libxt
        libxi
        libxrandr
        libxcursor
        libxfixes
        libxinerama
        libxcb
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
          # Mozilla's bindgen configure checks use --with-libclang-path, and
          # Rust bindgen uses LIBCLANG_PATH; both target LLVM 21 from this pin.
          export VULPRA_NIX_LIBCLANG_PATH="${pkgs.llvmPackages.libclang.lib}/lib"
          export LIBCLANG_PATH="$VULPRA_NIX_LIBCLANG_PATH"
          # Gecko runs assembler sources through a C compiler driver so
          # -Wa,--noexecstack, -fPIC and -include are interpreted correctly.
          # Nix otherwise exposes clang-wrapper/bin/as, which is a *raw*
          # assembler and fails with 'invalid listing option ,'.
          # Match the Nix native GCC C compiler selected by mach configure.
          export AS="${pkgs.stdenv.cc}/bin/gcc"
          # The Nixpkgs fonts.conf explicitly imports /etc/fonts/conf.d,
          # even when used by absolute path! Use our pinned, version-matched
          # overlay that replaces that import with Nix Fontconfig rules and
          # includes host font directories, not host rule XML.
          # Respect an explicit user FONTCONFIG_FILE override.
          if [ -z "''${FONTCONFIG_FILE:-}" ]; then
            export FONTCONFIG_FILE="${fontconfigConfig}/etc/fonts/fonts.conf"
          fi
          # Mozilla checks WASM_CC/WASM_CXX separately from native CC/CXX.
          # Target-aware compiler-rt comes from the pinned WASI cross CC.
          # Its C++ standard libraries are provided to WASM_CXX *only* via
          # the isolated wrapper above, not native linker setup hooks.
          # Preserve explicit user overrides and the existing host WASI sysroot.
          if [ -z "''${WASM_CC:-}" ]; then
            export WASM_CC="${wasiCc}/bin/${wasiCc.targetPrefix}clang"
          fi
          if [ -z "''${WASM_CXX:-}" ]; then
            export WASM_CXX="${wasiCxx}"
          fi
          export VULPRA_NIX_DEV=1
          export VULPRA_TOOLCHAIN_SYSTEM="x86_64-linux"
          printf 'Vulpra Nix toolchain active (Linux x86_64); use vulpra-dev help.\n'
          printf 'Firefox/Hyprland profiles and existing obj directories are untouched.\n'
        '';
      };
    in
    {
      devShells.${system}.default = toolingShell;
      packages.${system} = {
        default = devCli;
        vulpra-dev = devCli;
        # Opt-in host-level nom, pinned to the same nixpkgs as this toolchain.
        # Not in devShell packages: the outer nom executable must start
        # *before* nix develop realizes the shell closure.
        nom = pkgs.nix-output-monitor;
      };
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
          bash -n ${./verify-preserved-browser.sh}
          shellcheck -S warning ${./verify-preserved-browser.sh}
          bash -n ${./vulpra}
          shellcheck -S warning ${./vulpra}
          bash -n ${./test-vulpra-launcher.sh}
          shellcheck -S warning ${./test-vulpra-launcher.sh}
          sh -n ${./mozconfig-overlay.sh}
          bash -n ${./test-mozconfig-overlay.sh}
          shellcheck -S warning ${./test-mozconfig-overlay.sh}
          bash -n ${./test-wasm-compiler.sh}
          shellcheck -S warning ${./test-wasm-compiler.sh}
          bash -n ${./test-native-assembler.sh}
          shellcheck -S warning ${./test-native-assembler.sh}
          bash -n ${./test-native-linker.sh}
          shellcheck -S warning ${./test-native-linker.sh}
          bash -n ${./test-fontconfig-compat.sh}
          shellcheck -S warning ${./test-fontconfig-compat.sh}
          bash -n ${./test-xsum-warning-flags.sh}
          shellcheck -S warning ${./test-xsum-warning-flags.sh}
          # No deprecated xorg.* compatibility aliases in our pinned shell.
          if grep -Eq 'xorg[.]lib' ${./flake.nix}; then
            echo 'ERROR: deprecated xorg.* Nixpkgs attributes remain in nix/flake.nix' >&2
            exit 1
          fi
          bash ${./test-mozconfig-overlay.sh} ${./mozconfig-overlay.sh}
          bash ${./test-vulpra-launcher.sh} ${./vulpra}
          grep -Fq 'VULPRA_NIX_DEV' ${./vulpra-dev.sh}
          grep -Fq 'ci/build-local.sh' ${./vulpra-dev.sh}
          mkdir -p "$out"
          echo 'PASS: syntax, shellcheck and native wrapper contracts' > "$out/report"
        '';
    };
}
