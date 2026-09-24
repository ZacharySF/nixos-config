# Development toolchain, aimed at quantitative finance + computer architecture.
#
# This is the heaviest module. Everything is grouped so you can comment out a
# whole section you are not using. For project-specific toolchains prefer a
# per-project flake + `.envrc` (`use flake`) over adding more here — see
# ../README.md "Per-project dev environments".
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # ---------------------------------------------------------------
    # AI coding assistants
    # ---------------------------------------------------------------
    codex             # OpenAI Codex CLI
    claude-code       # Claude Code CLI

    # ---------------------------------------------------------------
    # General development
    # ---------------------------------------------------------------
    gh
    git-lfs
    just              # command runner (Makefile replacement)
    helix             # terminal editor, zero-config
    tmux
    hyperfine         # benchmark CLI commands
    tokei             # count lines of code
    difftastic        # structural diffs

    # ---------------------------------------------------------------
    # C / C++  — the core language for low-latency / HFT-style work
    # ---------------------------------------------------------------
    gcc               # default C/C++ compiler (`cc`, `g++`)
    clang-tools       # clang-format, clang-tidy, clangd (the LSP editors use)
    # NOTE: the `clang` *compiler* is intentionally NOT here — it collides with
    # gcc's `ld` in a single environment. If you want to build with clang, do it
    # in a per-project devshell (`nix shell nixpkgs#clang`) or `nix-shell -p clang`.
    cmake
    ninja
    gnumake
    m4                # GNU macro processor
    bison             # parser generator; provides both `bison` and `yacc`
    pkg-config
    gdb
    lldb
    valgrind
    # common numeric / concurrency libraries, so `#include <Eigen/...>` etc.
    # work without per-project setup:
    eigen
    boost
    tbb

    # ---------------------------------------------------------------
    # Rust
    # ---------------------------------------------------------------
    rustup            # run `rustup default stable` once after first switch

    # ---------------------------------------------------------------
    # Python — scientific / quant
    # ---------------------------------------------------------------
    # The interpreter itself (pandas, polars, scikit-learn, ipython, etc.)
    # lives in the combined python313 environment in ece.nix — only one
    # full python3.withPackages closure can live in home.packages at once
    # without colliding on shared paths (bin/pydoc3, share/gdb/*).
    uv                # fast project/venv manager for per-project deps
    ruff              # linter/formatter

    # ---------------------------------------------------------------
    # Computer architecture / hardware
    # ---------------------------------------------------------------
    verilator         # Verilog/SystemVerilog simulator (compiles HDL to C++)
    yosys             # RTL synthesis
    gtkwave           # waveform viewer for simulation dumps
    qemu              # full-system emulation (run other ISAs)
    # RISC-V bare-metal GCC is a large build — uncomment when you actually
    # need cross-compilation:
    # pkgsCross.riscv64-embedded.buildPackages.gcc
  ];
}
