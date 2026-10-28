{ lib, rustPlatform, fetchFromGitHub }:
rustPlatform.buildRustPackage {
  pname = "wispr-flow-linux-helper-niri";
  version = "0.1.3";

  src = fetchFromGitHub {
    owner = "wispr-flow-linux";
    repo = "helper";
    rev = "3dbc620315835821d1bd5b1e175e9d14aae6b8df";
    hash = "sha256-6yImRj0KCgoj6TCnIKSY94jF84ZGF2oz4CKpiBuJIJU=";
  };
  cargoHash = "sha256-GLTLbY+7s0YfM3bknAT93WBxfV39cMt3pY29LUOLZBE=";
  patches = [ ./niri-terminal-paste.patch ];

  meta = {
    description = "Wispr Flow helper with terminal-aware paste on niri";
    license = lib.licenses.unlicense;
    platforms = [ "x86_64-linux" ];
  };
}
