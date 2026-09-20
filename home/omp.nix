# Oh My Pi / OMP coding agent CLI (github:can1357/oh-my-pi), via its Home
# Manager module.
{ inputs, ... }:
{
  imports = [ inputs.oh-my-pi.homeManagerModules.default ];

  programs.omp.enable = true;
}
