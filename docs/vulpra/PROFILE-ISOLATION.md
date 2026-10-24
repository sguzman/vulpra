# Profile isolation for Vulpra

The Linux launcher `packaging/vulpra` is intended to sit next to the Firefox executable in the built installation directory. It passes `--no-remote --new-instance --profile` with a Vulpra-private directory at `$XDG_DATA_HOME/vulpra/default` or `$HOME/.local/share/vulpra/default`.

The wrapper creates its own mode-0700 profile directory and rejects explicit profile-selection options, relative XDG directories and symlinked profile roots. It does not read or write `~/.mozilla/firefox`; normal URLs and browser arguments are forwarded. `packaging/test-launcher.sh` verifies this contract against a mock Firefox executable in CI.

**Not ready to distribute.** The wrapper is tested separately but has not yet been integrated into a fully built and independently branded browser. The internal binary is still named `firefox`; app ID, branding, packaged launcher identity, and real-browser tests remain explicit M2 acceptance gates.
