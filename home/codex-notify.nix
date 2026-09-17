# Desktop notification when Codex CLI (OpenAI's coding agent) finishes a
# turn. Codex's `notify` config option (~/.codex/config.toml, not
# home-manager-managed) points at this script and invokes it with a single
# JSON argument describing the event.
{ ... }:
{
  home.file.".local/bin/codex-notify.sh" = {
    source = ./codex-notify.sh;
    executable = true;
  };
}
