# orders

The orders service of Acme.

`deploy/<account>.json` holds the desired state of the service's cloud resources in each account, `production` and `staging`.
`cloudctl` changes live state to match it, the way OpenTofu does:

```sh
cloudctl plan <account> --out <file>
cloudctl show <file>
cloudctl apply <file>
cloudctl plan <account> --detailed-exitcode
cloudctl get <account> [<resource>]
```

Run it from the root of the repository.
