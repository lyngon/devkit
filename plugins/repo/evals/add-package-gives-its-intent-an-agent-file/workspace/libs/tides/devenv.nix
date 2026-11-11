{ ... }:
{
  tasks."tides:test" = {
    description = "Run tides tests";
    exec = "cd libs/tides && uv run pytest";
  };
}
