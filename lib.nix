{ lib }:
let
  # An overlay to replace a given version of GHC with a custom one that has the
  # static RTS libraries compiled with -fPIC. This lets us use these static
  # libraries to build a self-contained shared library.
  doEnableRelocatedStaticLibs = ghcVersion: (final: prev:
    let
      ourGhc = prev.haskell.compiler.${ghcVersion}.override {
        # Needed to be able to create standalone shared libraries from Haskell code
        enableRelocatedStaticLibs = true;
        # Getting rid of as many dependencies as possible to lower the closure
        # size of the generated shared libraries...
        enableDwarf = false;
        # enableTerminfo = false; # NOTE: ghc 9.6.4 doesn't compile with enableTerminfo=false 😭
        enableDocs = false; # TODO: this shouldn't actually affect the closure size, but may speed up the compilation of GHC
      };
      addConfigureFlag = flag: old:
        if lib.findFirst (f: f == flag) null old != null then
          old
        else
          old ++ [ flag ];
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
                  configureFlags =
                    # (attrs.configureFlags or [ ]) ++ [
                    #   "--ghc-option=-fPIC"
                    #   "--ghc-option=-fexternal-dynamic-refs"
                    # ];
                    addConfigureFlag "--ghc-option=-fPIC"
                      (addConfigureFlag "--ghc-option=-fexternal-dynamic-refs"
                        (attrs.configureFlags or [ ]));
                  # NOTE: disable everything except for tests
                  doBenchmark = false;
                  doHoogle = false;
                  doHaddock = false;
                  enableLibraryProfiling = false;
                  enableExecutableProfiling = false;
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
      let addOutput = output: prev: if lib.elem output prev then prev else prev ++ [ output ];
      in addOutput "dev" (addOutput "lib" (attrs.outputs or [ ]));

    postInstall = ''
      ${attrs.postInstall or ""}

      echo "Installing foreign libraries to $lib/lib ..."
      mkdir -p $lib/lib
      for f in $(find $out/lib/ghc-*/lib -maxdepth 1 -type f -regex '.*\.\(so\|dylib\)'); do
        install -v -Dm 755 "$f" $lib/lib/
      done

      echo "Installing include files to $dev/include ..."
      mkdir -p $dev/include
      for f in ${lib.concatStringsSep " " headers}; do
        install -v -Dm 644 "$f" $dev/include/
      done
    '';
  });
in
{
  inherit
    doEnableRelocatedStaticLibs
    doInstallForeignLibs;
}
