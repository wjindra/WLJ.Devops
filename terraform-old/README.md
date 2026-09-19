# terraform-old

Retired `larstobi/multipass`-based config, kept around to re-test once [larstobi/terraform-provider-multipass#30](https://github.com/larstobi/terraform-provider-multipass/pull/30) lands in a real release. The active config lives in `../terraform/` and uses `todoroff/multipass` instead — see the root `README.md`'s "Multipass provider — switched to `todoroff/multipass`" section for why.

`bridged = true` is already set on each resource so `apply.sh` actually exercises PR #30's fix once it's released.

## To re-test after #30 ships

1. Bump the `version` constraint in `main.tf` to the release that includes #30.
2. Remove the `dev_overrides` block from `~/.terraformrc` (or point it elsewhere) — this config no longer needs the locally patched build once the fix is released.
3. Run `./apply.sh`, then check `multipass info <name>` for a real LAN IP alongside the NAT one.
4. Run `./destroy.sh` when done.

No `.terraform/` or state files are committed here — `terraform init` will recreate them.
