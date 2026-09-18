# OKD validation

The six topic branches must be merged before running the combined checks.
Run `helm dependency build`, `helm lint .`, `helm unittest .` and `python3 ci/validate-okd.py` (requires PyYAML).
The matrix checks install and upgrade manifests, security contexts, routes and volume references.
Set `KUBECONFORM` to a kubeconform binary to also validate native resources against Kubernetes 1.32 schemas.
Route and ServiceMonitor schemas are excluded from that optional check.
It does not replace admission or runtime tests on OKD.

## Deployment

1. Build and publish the PostgreSQL image from `docs/postgresql.md`, or prepare an external database.
2. Create credentials and choose UID-compatible application image tags in a private `site-values.yaml`.
3. Set route hosts and a StorageClass supporting the selected topology.
4. Render and install into a dedicated test project:

```sh
helm dependency build
helm template openvox . -n openvox-test -f values-okd.yaml -f ci/okd-network.yaml \
  -f site-values.yaml --api-versions route.openshift.io/v1 > /tmp/openvox-okd.yaml
helm upgrade --install openvox . -n openvox-test -f values-okd.yaml -f ci/okd-network.yaml \
  -f site-values.yaml --wait --timeout 15m
oc -n openvox-test get pods,pvc,route
oc -n openvox-test get pods -o custom-columns=NAME:.metadata.name,SCC:.metadata.annotations.openshift\\.io/scc
```

Review pod admission events and verify that the intended SCC is selected.
A server-side dry run of Deployments alone does not exercise pod SCC admission.
Check the cluster's DNS backend ports and namespace labels before applying `ci/okd-network.yaml`.
Add scoped egress rules for Git, external databases, CRL URLs, metrics or backup destinations as needed.
Router namespaces must match `global.networkPolicy.routerNamespaceSelector`.

## Storage and functional checks

Use RWX for volumes shared across nodes by masters, deployment compilers or standalone r10k.
RWO works only where the selected placement and storage driver permit all consumers.
Certificate-import pre-install hooks require bound existing PVCs or an Immediate-binding StorageClass.
Do not use unbound WaitForFirstConsumer PVCs for those hooks.
Verify CSI fsGroup handling and SELinux labeling; existing volumes must already permit the assigned identity.
Never change CA ownership or migrate PostgreSQL data without a backup.

Test certificate enrollment, catalog compilation, report storage and UI queries through the routes.
Restart each workload and repeat the checks to verify CA, code and database persistence.
Run r10k, CRL updates and a backup/restore using their actual service accounts.
Verify `pg_trgm` and `pgcrypto` in the application database and confirm the application role is not a superuser.
Repeat `helm upgrade` and test a second release in the same project for resource-name collisions.
