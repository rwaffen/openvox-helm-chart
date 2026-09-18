# OKD deployment

Apply `values-okd.yaml` after merging the security-context and rootless-initialization changes.
The profile targets `restricted-v2`, leaves UID/GID allocation to admission, and uses dedicated service accounts.
It does not create or modify cluster-wide SCCs.
Select a StorageClass and database configuration appropriate for the target cluster.

For an administrator-provided SCC, set `global.openshift.sccName` to grant `use` through namespace-scoped RBAC.
The installer must already be allowed to grant that permission.
Use `global.securityContexts.overrides` for settings required by that SCC.
Standard restricted installations need no additional SCC binding.

Standalone r10k and CRL jobs use the server service account; backup uses its own account.
Pre-install SCC bindings remain after the hook finishes and must be cleaned up when removing a hook-based release.
Legacy PSP creation fails explicitly on Kubernetes 1.25 and later.
