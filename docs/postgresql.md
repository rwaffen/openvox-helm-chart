# PostgreSQL on OKD

The chart-native `customPostgresql` workload avoids Bitnami-specific entrypoints and runtime extension ConfigMaps.
Build `images/postgresql/Containerfile` and publish the image to your own registry before deployment.
The image contains `pg_trgm` and `pgcrypto`; its fixed initialization script enables them in the application database.
No packages or extension binaries are downloaded at startup.
The inherited PostgreSQL entrypoint supports arbitrary UIDs through NSS wrapper.

```sh
podman build -t REGISTRY/openvox-postgresql:16 -f images/postgresql/Containerfile images/postgresql
bash images/postgresql/test.sh REGISTRY/openvox-postgresql:16
podman push REGISTRY/openvox-postgresql:16
```

Create a secret containing `username`, `password` and `postgres-password` using your secret-management workflow.
The application role must differ from `postgres`; it owns the application database but is not a superuser.
Configure the following alongside `values-okd.yaml`:

```yaml
postgresql:
  enabled: false
customPostgresql:
  enabled: true
  image:
    repository: REGISTRY/openvox-postgresql
    tag: "16"
  auth:
    existingSecret: openvox-postgresql
```

Use a maintained, approved base image and rebuild regularly; `POSTGRES_IMAGE` can pin its digest at build time.
Database initialization runs only on an empty volume.
Password changes require database-side rotation as well as secret updates.
If initialization fails, inspect and recover the volume before retrying; do not assume init scripts rerun.
Migrating Bitnami data requires a tested backup/restore or PostgreSQL upgrade procedure, not an image swap.
SCC UID changes across namespaces likewise require a planned volume migration.

For external PostgreSQL, disable both database workloads and set `puppetdb.extraEnv.OPENVOXDB_POSTGRES_HOSTNAME`.
Use `global.postgresql.auth.database` and an existing credentials secret for the application connection.
Have the database administrator enable both extensions before starting OpenVoxDB.
