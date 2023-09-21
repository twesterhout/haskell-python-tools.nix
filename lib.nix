{}:
let
  # An overlay to replace a given version of GHC with a custom one that has the
  # static RTS libraries compiled with -fPIC. This lets us use these static
  # libraries to build a self-contained shared library.
  doEnableRelocatedStaticLibs = ghcVersion: (final: prev:
    let
      ourGhc = prev.haskell.compiler.${ghcVersion}.override {
        enableRelocatedStaticLibs = true;
      };
    in
    lib.recursiveUpdate prev {
      haskell.compiler.${ghcVersion} = ourGhc;
      haskell.packages.${ghcVersion} =
        prev.haskell.packages.${ghcVersion}.override
          (old: {
            overrides = prev.lib.composeExtensions
              (old.overrides or (_: _: { }))
              (hfinal: hprev: {
                mkDerivation = args: (hprev.mkDerivation args).overrideAttrs (attrs: {
                  configureFlags = (attrs.configureFlags or [ ]) ++ [
                    "--ghc-option=-fPIC"
                    "--ghc-option=-fexternal-dynamic-refs"
                  ];
                });
              });
          })
        // { ghc = ourGhc; };
    });

  # Create a separate lib output for installing the foreign libraries.
  #
  # headers is a list of strings specifying files that should be installed in
  # the include/ directory. Make sure these are really strings rather than
  # paths, otherwise the resulting files may have weird names (i.e., contain
  # hashes).
  doInstallForeignLibs = { headers ? [ ] }: drv: drv.overrideAttrs (attrs: {
    # Add lib to the outputs
    outputs =
      let prev = attrs.outputs or [ ];
      in
      if lib.elem "lib" prev then prev else prev ++ [ "lib" ];
    postInstall = ''
      ${attrs.postInstall or ""}

      echo "Installing foreign libraries to $lib/lib ..."
      mkdir -p $lib/lib
      for f in $(find $out/lib/ghc-*/lib -maxdepth 1 -type f -regex '.*\.\(so\|dylib\)'); do
        install -v -Dm 755 "$f" $lib/lib/
      done

      echo "Installing include files to $lib/include ..."
      mkdir -p $out/include
      for f in ${lib.concatStringsSep " " headers}; do
        install -v -Dm 644 "$f" $out/include/
      done
    '';
  });


  lib = {
    inherit
      doEnableRelocatedStaticLibs
      doInstallForeignLibs;
  };
in
lib
