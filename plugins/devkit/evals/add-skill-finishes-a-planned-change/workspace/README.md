# devkit

A small stand-in for the Lyngon devkit: the plugin marketplace `lyngon`, with the bundle `all` and the plugin `writing`.
Third-party skills enter through `/devkit:add-skill`, and the record of what was vendored from an upstream lives under `catalog/vendored/`.

## Checking

The full check:

```sh
devenv test
```

A pull request follows the Lyngon baseline, so `check-pull-request` checks its title and its body.

## Evals

An eval case is a directory `plugins/<plugin>/evals/<case>/` that holds a `prompt.md` and its graders under `graders/`.
Score a case at a base commit and in the working tree:

```sh
compare-evals <base commit> --case <case>
```
