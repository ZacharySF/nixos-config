# Hermes Agent CLI (github:NousResearch/hermes-agent), via its Home Manager
# module. CLI only — no background gateway service is enabled here. Run
# `hermes setup` once to configure a provider/API key, then `hermes --tui`.
{ inputs, ... }:
{
  imports = [ inputs.hermes-agent.homeManagerModules.default ];

  programs.hermes-agent.enable = true;
}
