# The closed-beta archive is supplied by the user, not fetched with credentials.
{
  lib,
  stdenvNoCC,
  requireFile,
  autoPatchelfHook,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  gcc,
  glib,
  libxcb,
  libX11,
  libXcursor,
  libXi,
  libXrandr,
  libxkbcommon,
  wayland,
  vulkan-loader,
  libGL,
  fontconfig,
  freetype,
}:
stdenvNoCC.mkDerivation rec {
  pname = "tern";
  version = "0.9.8";

  src = requireFile {
    name = "Tern-${version}-linux-x86_64.tar.gz";
    hash = "sha256-TCCTx1UXTmAtT4bJeB5UOhVkrxrvI/NCFSLUNs9goFQ=";
    message = ''
      Download Tern ${version} for Linux x86_64 from https://tern.build/download,
      then run: nix-store --add-fixed sha256 Tern-${version}-linux-x86_64.tar.gz
    '';
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper copyDesktopItems ];
  buildInputs = [ gcc.cc.lib ];
  # These libraries are opened dynamically, so ELF dependency discovery misses them.
  runtimeDependencies = map lib.getLib [
    libxcb libX11 libXcursor libXi libXrandr libxkbcommon wayland
    vulkan-loader libGL fontconfig freetype
  ];
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 tern "$out/bin/tern"
    runHook postInstall
  '';
  postFixup = ''
    # Tern defaults to OpenGL on Intel; its swapchain is opaque on this host.
    wrapProgram "$out/bin/tern" \
      --prefix PATH : ${lib.makeBinPath [ glib ]} \
      --set-default WGPU_BACKEND vulkan
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "so.stencil.tern";
      desktopName = "Tern";
      exec = "tern";
      icon = "utilities-terminal";
      startupWMClass = "so.stencil.tern";
      categories = [ "System" "TerminalEmulator" ];
      extraConfig.X-TerminalArgExec = "-e";
    })
    (makeDesktopItem {
      name = "so.stencil.tern.url";
      desktopName = "Tern";
      exec = "tern --open-url %u";
      icon = "utilities-terminal";
      noDisplay = true;
      mimeTypes = [ "x-scheme-handler/tern" ];
    })
    (makeDesktopItem {
      name = "so.stencil.tern.open";
      desktopName = "Tern";
      exec = "tern --open-file %f";
      icon = "utilities-terminal";
      noDisplay = true;
      mimeTypes = [
        "text/plain" "text/markdown" "text/x-source" "image/png" "image/jpeg"
        "image/gif" "image/webp" "image/svg+xml" "application/x-sqbpro"
        "application/x-ipynb+json" "application/vnd.sqlite3" "application/x-sqlite3"
        "application/vnd.apache.parquet" "text/csv" "text/tab-separated-values"
      ];
    })
  ];

  meta = {
    description = "Multiplexing terminal";
    homepage = "https://tern.build";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "tern";
  };
}
