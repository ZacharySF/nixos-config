# ECE coursework stack: math, circuit simulation, HDL/FPGA, embedded
# development, lab instruments, and one combined scientific Python 3.13
# environment (cocotb upstream does not support Python 3.14+ yet). This also
# carries the quant-finance packages (pandas, polars, scikit-learn, ipython)
# that used to live in dev.nix's own pythonForQuant -- only one full
# python3.withPackages closure can live in home.packages at once without
# colliding on shared paths (bin/pydoc3, share/gdb/*), so it was merged here.
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

        # Quant finance (moved from dev.nix's pythonForQuant)
        pandas
        polars
        scikit-learn
        ipython

        # Two upstream/nixpkgs bugs on this snapshot, neither ours to fix:
        # 1. skrf's test suite fails because numpy now raises ComplexWarning
        #    as an error where skrf's eigendecomposition code
        #    (mathFunctions.py) discards an imaginary part into a real
        #    array -- skip the check phase.
        # 2. nixpkgs' derivation is missing typing-extensions, which skrf's
        #    own METADATA declares as a runtime dependency, tripping
        #    pythonRuntimeDepsCheckHook -- add it back.
        (scikit-rf.overridePythonAttrs (old: {
          doCheck = false;
          dependencies = old.dependencies ++ [ typing-extensions ];
        }))

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
