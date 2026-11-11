{ ... }:
{
  lyngon.enable = true;
  lyngon.structure.enable = true;

  languages.python = {
    enable = true;
    uv.enable = true;
    uv.sync.enable = true;
  };

  git-hooks.hooks = {
    ruff-format.enable = true;
    ruff.enable = true;
  };
}
