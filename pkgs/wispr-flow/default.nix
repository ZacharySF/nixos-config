# Wispr Flow voice dictation, via the unofficial Linux port
# (github:wispr-flow-linux/wispr-flow-linux).
#
# Wraps the port's prebuilt release AppImage rather than its flake: the flake
# needs a hand-supplied Windows installer (--impure) and skips the native
# sqlite rebuild, so DB-backed features are broken there. The release AppImage
# ships the rebuilt natives and the clean-room text-injection helper.
#
# Bump: pick a release at
#   https://github.com/wispr-flow-linux/wispr-flow-linux/releases
# set `version`/`portVersion`, and paste the asset's sha256 digest as SRI:
#   nix hash convert --hash-algo sha256 --to sri <hex digest>
{
  lib,
  appimageTools,
  callPackage,
  fetchurl,
  wl-clipboard,
}:
let
  pname = "wispr-flow";
  version = "1.6.1209"; # upstream Wispr Flow app
  portVersion = "1.0.5"; # wispr-flow-linux packaging (helper 0.1.3: keyboard hotplug)

  src = fetchurl {
    url = "https://github.com/wispr-flow-linux/wispr-flow-linux/releases/download/v${portVersion}%2Bwispr${version}/wispr-flow-${version}-${portVersion}-x86_64.AppImage";
    hash = "sha256-pPXPVkO3i2Adqdmny7sbyDpchl6EvGAojby+xOSDz8Q=";
  };

  helper = callPackage ./helper.nix { };
  contents = appimageTools.extract {
    inherit pname version src;
    postExtract = ''
      rm $out/usr/lib/wispr-flow/resources/Release/wispr-flow-linux-helper
      ln -s ${helper}/bin/wispr-flow-linux-helper $out/usr/lib/wispr-flow/resources/Release/wispr-flow-linux-helper
    '';
  };
in
appimageTools.wrapAppImage {
  inherit pname version src contents;

  # Hard runtime dependency on Wayland: clipboard paste + selection reads.
  extraPkgs = _: [ wl-clipboard ];

  extraInstallCommands = ''
    install -Dm644 ${contents}/ai.wisprflow.WisprFlow.desktop -t $out/share/applications
    substituteInPlace $out/share/applications/ai.wisprflow.WisprFlow.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=wispr-flow'
    cp -r ${contents}/usr/share/icons $out/share/icons

    # Same rule the port's deb/rpm install: the active session user may write
    # /dev/uinput (typing the transcript into the focused app) and read
    # /dev/input/event* (the global push-to-talk hotkey). Numbered below
    # 73-seat-late.rules so logind applies the uaccess ACL.
    install -Dm444 /dev/stdin $out/lib/udev/rules.d/70-wispr-flow-uinput.rules <<'EOF'
    KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess", GROUP="input", MODE="0660"
    SUBSYSTEM=="input", KERNEL=="event*", TAG+="uaccess", GROUP="input", MODE="0660"
    EOF
  '';

  meta = {
    description = "Wispr Flow voice dictation (unofficial Linux port)";
    homepage = "https://github.com/wispr-flow-linux/wispr-flow-linux";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "wispr-flow";
  };
}
