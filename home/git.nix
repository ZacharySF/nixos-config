# Git identity and GitHub CLI.
#
# NOTE: name + email below are the ONLY personal identifiers in this repo.
# They are already public on every commit you have pushed, so keeping them
# here is fine. Change them if you migrate to a different identity.
{ ... }:
{
  programs.git = {
    enable = true;
    settings = {
      user.name = "Zachary";
      user.email = "zachary.sf.stubbs@gmail.com";
      init.defaultBranch = "main";
      push.autoSetupRemote = true; # `git push` on a new branch just works
      pull.rebase = true;
      rerere.enabled = true;       # remember conflict resolutions
    };
  };

  # GitHub CLI — `gh auth login` once per machine (token is stored by gnome-keyring,
  # never in this repo).
  programs.gh.enable = true;
}
