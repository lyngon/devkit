# orders

The orders service of Acme.

`infra/staging` is the OpenTofu root of the service's resources in the staging account.
Run OpenTofu on it from the root of the repository:

```sh
tofu -chdir=infra/staging plan
```
