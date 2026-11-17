# POSIX shell mozconfig shim used only by Vulpra's guarded Nix native commands.
# Keep the original workstation configuration authoritative (including WASI).
# This file does not change or overwrite the original mozconfig.
: "${VULPRA_MOZCONFIG_SOURCE:?Nix wrapper requires original MOZCONFIG path}"
: "${VULPRA_NIX_LIBCLANG_PATH:?Nix wrapper requires libclang path}"
. "$VULPRA_MOZCONFIG_SOURCE"
ac_add_options "--with-libclang-path=$VULPRA_NIX_LIBCLANG_PATH"
