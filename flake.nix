{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay.url = "github:oxalica/rust-overlay";
    systems.url = "github:nix-systems/default";
    android = {
      url = "github:tadfisher/android-nixpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = import inputs.systems;
      ## Flake-Parts modules
      imports = [
        inputs.pre-commit-hooks.flakeModule
      ];
      perSystem = {
        config,
        self',
        pkgs,
        lib,
        system,
        ...
      }: {
        ## Overlays for existing packages
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [
            inputs.fenix.overlays.default
          ];
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };
        # Rust dev environment
        devShells.default = with pkgs; let
          ############
          # Toolchains
          ############
          androidComposition = pkgs.androidenv.composeAndroidPackages {
            includeEmulator = true;
            includeNDK = true;
            emulatorVersion = "34.1.9";
            platformToolsVersion = "33.0.3";
            buildToolsVersions = ["30.0.3"];
            ndkVersions = ["26.1.10909125"];
            abiVersions = ["armeabi-v7a" "arm64-v8a" "x86" "x86_64"];
            platformVersions = ["34" "33" "31"];
            useGoogleAPIs = false;
            extraLicenses = [
              "android-googletv-license"
              "android-sdk-arm-dbt-license"
              "android-sdk-license"
              "android-sdk-preview-license"
              "google-gdk-license"
              "intel-android-extra-license"
              "intel-android-sysimage-license"
              "mips-android-sysimage-license"
            ];
          };
          rust-toolchain = (pkgs.fenix.fromToolchainFile { file = ./rust-toolchain.toml; });
          ##########
          # Packages
          ##########
          node = [
            nodejs_20
            bun
            # deno
          ];
          android = [
            android-studio
            android-tools
            gradle_6
          ];
          rust = [
            rust-toolchain
            # not in use, just to appease tauri info
            rustup
            rust-analyzer
            cargo
            cargo-tauri
          ];
          preCommit = [
            editorconfig-checker
            typos
            convco
          ];
          packages = node ++ android ++ rust ++ preCommit;
          ###########
          # Libraries
          ###########
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
          ##############
          # Build Inputs
          ##############
          buildInputs = [
            curl
            wget
            pkg-config
            dbus
            openssl_3
            glib
            grcov
            gtk3
            libsoup_3
            webkitgtk_4_1
            librsvg
          ];
          nativeBuildInputs = [
            androidComposition.androidsdk
            androidComposition.ndk-bundle
            jetbrains.jdk
          ];
        in pkgs.mkShell {
          name = "tauri-shell";
          inherit packages buildInputs nativeBuildInputs;
          ANDROID_SDK_ROOT = "${androidComposition.androidsdk}/libexec/android-sdk";
          ANDROID_HOME = "${androidComposition.androidsdk}/libexec/android-sdk";
          ANDROID_NDK_ROOT = "${androidComposition.androidsdk}/libexec/android-sdk/ndk-bundle";
          NDK_HOME = "${androidComposition.androidsdk}/libexec/android-sdk/ndk-bundle";
          NDK_LIBS = "${androidComposition.androidsdk}/libexec/android-sdk/ndk-bundle/toolchains/llvm/prebuilt/linux-x86_64/lib";
          JAVA_HOME = "${pkgs.jetbrains.jdk}";
          WEBKIT_DISABLE_COMPOSITING_MODE = 1;
          RUST_BACKTRACE = 1;
          RUST_SRC_PATH = "${rust-toolchain}/lib/rustlib/src/rust/library";
          NO_RUSTUP = "1";
          shellHook = ''
            export LD_LIBRARY_PATH=$NDK_LIBS:${pkgs.lib.makeLibraryPath tauriLibs}:$LD_LIBRARY_PATH
            ${config.pre-commit.installationScript}            
            if [ ! -f "./src-tauri/gen/android/local.properties" ]; then
              echo android.aapt2FromMavenOverride=$ANDROID_SDK_ROOT/build-tools/30.0.3/aapt2 >>./src-tauri/gen/android/local.properties local.properties
            fi
          '';
        };
        pre-commit.settings = {
          excludes = ["flake.lock"];
          hooks = {
            typos.enable = true;
            editorconfig-checker.enable = true;
            convco.enable = true;
            clippy = {
              enable = true;
              settings.allFeatures = true;
            };
            # denofmt.enable = true;
            # denolint.enable = true;
          };
        };
      };
    };
}
