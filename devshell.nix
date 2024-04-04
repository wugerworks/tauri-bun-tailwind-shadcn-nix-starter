{ pkgs, config }: with pkgs; let
  nodeTools = [
    bun
    deno
  ];
  androidTools = [
    config.packages.android-sdk
    gradle
  ];
  preCommit = [
    editorconfig-checker
    typos
    convco
  ];
  commonTools = [
    just
  ];
  tauriDeps = [
    curl
    wget
    pkg-config
    dbus
    openssl_3
    glib
    gtk3
    libsoup_3
    webkitgtk_4_1
    librsvg
    cargo-tauri
  ];
  tauriLibs = [
    webkitgtk
    gtk3
    cairo
    gdk-pixbuf
    glib
    dbus
    openssl_3
    librsvg
  ];
in pkgs.mkShell {
  name = "tauri-shell";
  shellHook = ''
    # For rust-analyzer 'hover' tooltips to work.
    export RUST_SRC_PATH=${pkgs.rustPlatform.rustLibSrc}
    # Links libraries for tauri front-end
    export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath tauriLibs}:$LD_LIBRARY_PATH
    ${config.pre-commit.installationScript}

    just -l
  '';
  packages = nodeTools ++ androidTools ++ preCommit ++ commonTools;
  buildInputs = tauriDeps;
  nativeBuildInputs = [
    rustup
    nodejs_20
  ];
  ANDROID_SDK_ROOT = "${config.packages.android-sdk}/share/andorid-sdk";
  ANDROID_HOME = "$ANDROID_SDK_ROOT";
  ANDROID_NDK_ROOT = "${config.packages.android-sdk}/share/andorid-sdk/ndk";
  JAVA_HOME = "${pkgs.jdk11.home}";
  WEBKIT_DISABLE_COMPOSITING_MODE = 1;
  RUST_BACKTRACE = 1;
}
