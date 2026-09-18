#!/usr/bin/env python3
"""Render supported OKD variants and check admission and resource invariants."""
import copy
import os
from pathlib import Path
import subprocess
import tempfile

import yaml

ROOT = Path(__file__).resolve().parents[1]
HELM = os.environ.get("HELM", "helm")


class UniqueLoader(yaml.SafeLoader):
    pass


def unique_mapping(loader, node, deep=False):
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in result:
            raise ValueError(f"Duplicate YAML key: {key}")
        result[key] = loader.construct_object(value_node, deep=deep)
    return result


UniqueLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, unique_mapping)


def merge(base, override):
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(base.get(key), dict):
            merge(base[key], value)
        else:
            base[key] = copy.deepcopy(value)
    return base


def render(values, upgrade=False):
    with tempfile.NamedTemporaryFile(mode="w", suffix=".yaml") as config:
        yaml.safe_dump(values, config)
        config.flush()
        command = [HELM, "template", "okd-test", str(ROOT), "--namespace", "openvox-test",
                   "--kube-version", "1.32.0", "--api-versions", "route.openshift.io/v1",
                   "--api-versions", "security.openshift.io/v1", "-f", str(config.name)]
        if upgrade:
            command.append("--is-upgrade")
        result = subprocess.run(command, check=True, capture_output=True, text=True)
    if os.environ.get("KUBECONFORM"):
        command = [os.environ["KUBECONFORM"], "-strict", "-summary", "-kubernetes-version", "1.32.0",
                   "-skip", "Route,ServiceMonitor", "-cache", os.environ.get("SCHEMA_CACHE", "/tmp/openvox-schema-cache")]
        Path(command[-1]).mkdir(parents=True, exist_ok=True)
        subprocess.run(command, input=result.stdout, check=True, capture_output=True, text=True)
    return [doc for doc in yaml.load_all(result.stdout, Loader=UniqueLoader) if doc]


def podspec(resource):
    if resource["kind"] in ("Deployment", "StatefulSet", "Job"):
        return resource["spec"]["template"]["spec"]
    if resource["kind"] == "CronJob":
        return resource["spec"]["jobTemplate"]["spec"]["template"]["spec"]
    return None


def validate(resources):
    identities = [(r["kind"], r["metadata"]["name"]) for r in resources]
    assert len(identities) == len(set(identities)), "Duplicate resource names"
    assert not any(r["kind"] in ("PodSecurityPolicy", "SecurityContextConstraints") for r in resources)
    services = {r["metadata"]["name"]: r for r in resources if r["kind"] == "Service"}
    workloads = 0
    for resource in resources:
        name = resource["metadata"]["name"]
        if resource["kind"] == "Route":
            service = services[resource["spec"]["to"]["name"]]
            assert resource["spec"]["port"]["targetPort"] in [p["name"] for p in service["spec"]["ports"]]
        spec = podspec(resource)
        if spec is None:
            continue
        workloads += 1
        pod_context = spec.get("securityContext", {})
        for field in ("runAsUser", "runAsGroup", "fsGroup", "seLinuxOptions"):
            assert field not in pod_context, (name, field)
        volumes = {v["name"] for v in spec.get("volumes", [])}
        volumes.update(v["metadata"]["name"] for v in resource.get("spec", {}).get("volumeClaimTemplates", []))
        for container in (spec.get("initContainers") or []) + spec["containers"]:
            context = container.get("securityContext", {})
            label = f"{name}/{container['name']}"
            assert "runAsUser" not in context and "runAsGroup" not in context, label
            assert context.get("runAsNonRoot", pod_context.get("runAsNonRoot")) is True, label
            assert context.get("allowPrivilegeEscalation") is False, label
            assert context.get("capabilities", {}).get("drop") == ["ALL"], label
            assert not context.get("capabilities", {}).get("add"), label
            assert context.get("seccompProfile", pod_context.get("seccompProfile")) == {"type": "RuntimeDefault"}, label
            command = " ".join(container.get("command", []) + container.get("args", []))
            assert "chown " not in command, label
            for mount in container.get("volumeMounts", []):
                assert mount["name"] in volumes, (label, mount["name"])
    assert workloads >= 2


def main():
    base = yaml.safe_load((ROOT / "values-okd.yaml").read_text())
    merge(base, {"puppetdb": {"extraEnv": {"OPENVOXDB_POSTGRES_HOSTNAME": "database.example.test"}},
                 "global": {"postgresql": {"auth": {"existingSecret": "database-credentials"}}}})
    variants = {
        "master": {},
        "compiler-deployment": {"puppetserver": {"compilers": {"enabled": True, "kind": "Deployment"}}},
        "compiler-statefulset": {"puppetserver": {"compilers": {"enabled": True, "kind": "StatefulSet"}}},
        "r10k-sidecars": {"puppetserver": {"puppeturl": "https://example.test/control.git"},
                          "hiera": {"hieradataurl": "https://example.test/hiera.git"}},
        "r10k-standalone": {"puppetserver": {"puppeturl": "https://example.test/control.git"},
                            "r10k": {"asSidecar": False}},
        "metrics-and-backup": {"metrics": {"prometheus": {"puppetdb": {"enabled": True, "serviceMonitor": {"enabled": False}},
                                                              "jmx": {"enabled": True, "serviceMonitor": {"enabled": False}}}},
                               "puppetserver": {"masters": {"backup": {"enabled": True}}}},
        "single-ca": {"singleCA": {"enabled": True, "crl": {"url": "https://ca.example.test/crl.pem"}, "certificates": {"existingSecret": {"puppetserver": "server-certs", "puppetdb": "db-certs"}}}},
        "crl-job": {"singleCA": {"enabled": True, "crl": {"asSidecar": False, "url": "https://ca.example.test/crl.pem"},
                                  "certificates": {"existingSecret": {"puppetserver": "server-certs", "puppetdb": "db-certs"}}}},
        "routes": {"puppetserver": {"masters": {"route": {"enabled": True, "host": "ca.example.test"}},
                                     "compilers": {"enabled": True, "route": {"enabled": True, "host": "puppet.example.test"}}},
                   "openvoxview": {"route": {"enabled": True, "host": "view.example.test"}},
                   "puppetboard": {"enabled": True, "route": {"enabled": True, "host": "board.example.test"}}},
        "custom-postgresql": {"customPostgresql": {"enabled": True, "image": {"repository": "example.test/openvox-postgresql", "tag": "16"},
                                                     "auth": {"existingSecret": "database-credentials"}},
                              "puppetdb": {"extraEnv": {"OPENVOXDB_POSTGRES_HOSTNAME": None}}},
    }
    variants["statefulset-single-ca"] = merge(copy.deepcopy(variants["single-ca"]), variants["compiler-statefulset"])
    variants["statefulset-r10k"] = merge(copy.deepcopy(variants["r10k-sidecars"]), variants["compiler-statefulset"])
    variants["custom-scc-postgresql"] = merge(copy.deepcopy(variants["custom-postgresql"]),
                                              {"global": {"openshift": {"sccName": "site-restricted"}}})
    failures = []
    for name, overrides in variants.items():
        values = merge(copy.deepcopy(base), overrides)
        if name in ("custom-postgresql", "custom-scc-postgresql"):
            values["puppetdb"]["extraEnv"].pop("OPENVOXDB_POSTGRES_HOSTNAME", None)
        if name == "routes":
            merge(values, yaml.safe_load((ROOT / "ci/okd-network.yaml").read_text()))
        try:
            for upgrade in (False, True):
                resources = render(values, upgrade)
                validate(resources)
                if name == "routes":
                    for resource in resources:
                        if resource["kind"] == "NetworkPolicy":
                            dns = resource["spec"]["egress"][0]["to"][0]
                            assert dns["podSelector"]["matchLabels"] == {"dns.operator.openshift.io/daemonset-dns": "default"}
            print(f"PASS {name}: install and upgrade")
        except Exception as error:
            failures.append(name)
            print(f"FAIL {name}: {error}")
            if isinstance(error, subprocess.CalledProcessError):
                print(error.stderr)
    if failures:
        raise SystemExit(f"Failed variants: {', '.join(failures)}")


if __name__ == "__main__":
    main()
