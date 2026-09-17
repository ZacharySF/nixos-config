# ECE coursework stack: math, circuit simulation, HDL/FPGA, embedded
# development, lab instruments, and one combined scientific Python 3.13
# environment (cocotb upstream does not support Python 3.14+ yet).
#
# verilator, yosys, gtkwave stay out of this list — already in dev.nix.
#
# `mathematica` is deliberately absent: it is a paid, requireFile package (it
# cannot build until you add the licensed installer to the store) and it is
# not in the Texas A&M software store. sage covers the CAS work, with sympy
# in the python env below. To add it later, put `mathematica` back and run
#   nix hash file <installer>            # confirm which nixpkgs entry matches
#   nix-store --add-fixed sha256 <installer>
# nixpkgs 15.0.0 expects Wolfram_15.sh
# (sha256-5GulP3FM7p/RBKJskVzywPGJMS90GNATpczcceKmUKo=), or Wolfram_15_LIN.sh
# with `mathematica.override { webdoc = true; }`. `wolfram-engine` (free for
# developers, no notebook GUI) needs the same manual store add.
{
  pkgs,
  lib,
  ...
}:

{
  home.packages = with pkgs; [
    # --------- Mathematics ---------
    sage
    elan # Lean 4 via the version manager; Mathlib stays project-local through Lake

    # --------- Circuit Simulation ---------
    ngspice
    qucs-s

    # --------- HDL / FPGA ---------
    nextpnr
    sby
    surfer
    openfpgaloader

    # --------- Embedded Development ---------
    # Deprioritised: this toolchain ships share/gdb/python/gdb/*.py and
    # share/man/man7/gpl.7.gz, colliding with the host gdb (dev.nix) and
    # gcc (dev.nix) in the home-manager buildEnv. nixpkgs already ships
    # gcc-wrapper at priority 10, and equal priorities are a hard collision,
    # so this must sit strictly below. The arm-none-eabi-* binaries are
    # uniquely named and unaffected.
    (lib.setPrio 20 gcc-arm-embedded)
    pyocd
    probe-rs-tools
    can-utils

    # --------- Lab Instruments ---------
    pulseview

    # --------- Relocated from dev.nix ---------
    arduino-ide
    kicad
    spyder

    # --------- Scientific Python (single combined env) ---------
    (python313.withPackages (
      ps: with ps; [
        # Mathematics / scientific computing
        numpy
        scipy
        sympy
        matplotlib
        control
        scikit-rf

        # HDL verification
        cocotb

        # Instrumentation / serial communication (pyvisa-py is the open
        # backend; pyusb supplies its USB transport)
        pyvisa
        pyvisa-py
        pyserial
        pyusb
      ]
    ))
  ];
}
