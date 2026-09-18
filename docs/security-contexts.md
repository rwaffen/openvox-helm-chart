# Security contexts

Set `global.securityContexts.profile: restricted` to omit fixed identities and drop all container capabilities.
This selects non-root execution, `RuntimeDefault` seccomp and no privilege escalation.
Images and initialization must support the assigned UID; this setting alone does not remove root-dependent commands.

Use `global.securityContexts.pod` and `.container` for shared defaults.
Use `.overrides.<component>` for explicit component overrides, applied after the selected profile.
Use `.omit` to omit entire contexts when an admission policy supplies them.
Existing component security settings remain the defaults under the `legacy` profile.

Container components: `server-init`, `server`, `certificate-init`, `database-init`, `database`, `pgchecker`,
`wait-server`, `r10k`, `r10k-hiera`, `crl`, `jmx`, `puppetdb-exporter`, `puppetboard`, `openvoxview`, `backup`.
Pod components: `server-pod`, `database-pod`, `r10k-pod`, `preinstall-pod`, `crl-pod`, `backup-pod`.
Overrides must satisfy the SCC granted to the workload's service account.
