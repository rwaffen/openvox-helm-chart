# OpenShift routes

Enable `route.enabled` and set `route.host` on masters, compilers, Puppetboard or OpenVox View.
Disable the corresponding ingress; enabling both fails rendering.
Routes require the `route.openshift.io/v1` API and an enabled backend.
Pass `--api-versions route.openshift.io/v1` when rendering offline.

Server routes use TLS passthrough to preserve Puppet client authentication.
Agents connect to port 443; the service continues using port 8140.
Set both `serverport` and `ca_port` as appropriate, with separate server and CA hosts when using compilers.
Route hosts are added to requested server certificate SANs.
Existing certificates are not regenerated automatically; renew certificates before changing public hostnames.
Passthrough routes do not support path routing.

UI routes use edge TLS and the router's default certificate.
Use route annotations for router timeouts and operational settings.
Keep UI access limited to trusted users; a route does not add application authentication.
