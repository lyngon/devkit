# orders

The orders service of Acme.

`infra/staging` is the OpenTofu root of the service's resources in the staging account.
Run OpenTofu on it from the root of the repository:

```sh
tofu -chdir=infra/staging plan
```

## Checking

The full check fails on an OpenTofu root that is not formatted or not valid, and reads no live state:

```sh
scripts/check.sh
```
