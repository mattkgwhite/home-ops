# Envoy Gateway Setup Runbook

## Overview

This document covers the steps taken to deploy Envoy Gateway `v1.7.2` on a K3s single-node cluster (Ubuntu 24.04) managed via ArgoCD GitOps. The goal was to reach a `Synced` and `Healthy` state in ArgoCD.

---

## Prerequisites

- K3s installed with `--cluster-init --disable=traefik,servicelb`
- ArgoCD running in the `argocd` namespace
- `kubectl` configured on local machine with kubeconfig from the VPS
- GitHub repo with ApplicationSet pointing to `kubernetes/argo/manifests/`

---

## Step 1 — Split `envoy-gateway.yaml` and `gateway.yaml`

The original `envoy-gateway.yaml` contained the `GatewayClass` and `EnvoyProxy` resources inline alongside the ArgoCD `Application`. This caused an immediate failure on first apply because the `EnvoyProxy` CRD did not exist yet when `kubectl apply` processed the file.

**Fix:** Split the file into two:

- `envoy-gateway.yaml` — Namespace + ArgoCD Application (Helm chart install) only
- `gateway.yaml` — `GatewayClass` + `EnvoyProxy` resources (applied after CRDs exist)

---

## Step 2 — Fix the Helm `repoURL`

The original `repoURL` was set to `mirror.gcr.io/envoyproxy` without the `oci://` prefix, and later attempts to use `oci://docker.io/envoyproxy` resulted in `401 Unauthorized` errors from Docker Hub when ArgoCD tried to resolve the chart digest.

**Root cause:** Docker Hub requires authentication for OCI manifest requests. The GCR mirror does not.

**Fix:** Use `mirror.gcr.io/envoyproxy` as the `repoURL` without an `oci://` prefix. ArgoCD treats this as a standard Helm HTTP repo and can reach it without credentials.

```yaml
source:
  repoURL: mirror.gcr.io/envoyproxy
  chart: gateway-helm
  targetRevision: v1.7.2
```

> **Note:** `global.imageRegistry: mirror.gcr.io` in the `valuesObject` is a separate setting — it controls where the Envoy Gateway **container images** are pulled from at runtime. This remains correct and unchanged.

---

## Step 3 — Install Missing CRDs via `install.yaml`

After ArgoCD synced the Helm chart, the `EnvoyProxy` CRD (`envoyproxies.gateway.envoyproxy.io`) was missing. The Helm chart's CRD installation was silently failing because `installCRDs: true` is not a valid values key for `gateway-helm`.

The controller logs confirmed this:

```
EnvoyProxy CRD not found, skipping EnvoyProxy watch
failed to find envoyproxy envoy-gateway/argo for GatewayClass envoygateway-argo
```

**Fix:** Apply the official Envoy Gateway `install.yaml` directly to install all missing CRDs:

```bash
kubectl apply --server-side -f https://github.com/envoyproxy/gateway/releases/download/v1.7.2/install.yaml
```

**Expected errors (non-fatal):** The following errors were returned and can be safely ignored. They occur because K3s already has the standard channel Gateway API CRDs installed and the `install.yaml` attempts to replace them with experimental channel versions, which the `ValidatingAdmissionPolicy` blocks:

```
customresourcedefinitions.apiextensions.k8s.io "gatewayclasses.gateway.networking.k8s.io" is forbidden:
ValidatingAdmissionPolicy 'safe-upgrades.gateway.networking.k8s.io' denied request:
Installing experimental CRDs on top of standard channel CRDs is prohibited by default.
```

The CRDs that matter (`envoyproxies.gateway.envoyproxy.io` and other Envoy-specific CRDs) were installed successfully.

---

## Step 4 — Delete the Competing `envoy-gateway-system` Namespace

The `install.yaml` apply created a **second** Envoy Gateway deployment in a new `envoy-gateway-system` namespace, alongside the ArgoCD-managed deployment in `envoy-gateway`. This caused a leader election conflict — the unmanaged deployment in `envoy-gateway-system` was acquiring the lease and reconciling instead of the ArgoCD-managed one.

**Fix:** Delete the competing namespace entirely:

```bash
kubectl delete namespace envoy-gateway-system
```

Then restart the ArgoCD-managed deployment to force it to re-acquire the leader lease:

```bash
kubectl rollout restart deployment/envoy-gateway -n envoy-gateway
```

**Verification:** Confirm only one Envoy Gateway pod exists across all namespaces:

```bash
kubectl get pods -A | grep envoy
```

Expected output — pods in `envoy-gateway` namespace only:

```
envoy-gateway   envoy-gateway-xxxxxxxxx-xxxxx   1/1   Running   0   Xm
```

---

## Step 5 — Apply `gateway.yaml`

With the CRDs now installed, apply `gateway.yaml` which contains the `GatewayClass` and `EnvoyProxy` resources:

```bash
kubectl apply -f gateway.yaml
```

Wait for the `EnvoyProxy` CRD to be fully established first if applying immediately after Step 3:

```bash
kubectl wait --for=condition=established \
  crd/envoyproxies.gateway.envoyproxy.io --timeout=120s
```

**Verification:**

```bash
kubectl get gatewayclass envoygateway-argo
```

Expected:

```
NAME                CONTROLLER                                      ACCEPTED   AGE
envoygateway-argo   gateway.envoyproxy.io/gatewayclass-controller   True       Xm
```

---

## Step 6 — Fix ArgoCD Sync — Gateway API CRD Conflicts

ArgoCD was showing `OutOfSync` because the `gateway-helm` chart includes the Gateway API CRDs (`gatewayclasses`, `gateways`, `httproutes`, `referencegrants`, `grpcroutes`, `backendtlspolicies`) in its desired state, but K3s owns these CRDs and the `ValidatingAdmissionPolicy` blocks any attempt to replace them.

**Fix:** Add `skipCrds: true` to the Helm source in `envoy-gateway.yaml`. This tells ArgoCD not to include any CRDs from the chart in its desired state comparison, since the Envoy-specific CRDs were already installed in Step 3 and the Gateway API CRDs are owned by K3s.

```yaml
source:
  repoURL: mirror.gcr.io/envoyproxy
  chart: gateway-helm
  targetRevision: v1.7.2
  helm:
    skipCrds: true
    valuesObject:
      ...
```

> **Important:** The field name is `skipCrds` (lowercase `d`, lowercase `s`). `skipCRDs` is not a valid ArgoCD Application field and will cause a strict decoding error on apply.

---

## Step 7 — Fix ArgoCD Sync Options

The `syncOptions` block had incorrect values that were either invalid or causing issues:

- `serversideApply=true` — incorrect casing, must be `ServerSideApply=true`
- `force-conflicts=true` — not a valid ArgoCD sync option, removed
- `Replace=true` — caused `metadata.annotations: Too long` errors on large CRDs, removed

**Final correct `syncOptions`:**

```yaml
syncPolicy:
  automated:
    allowEmpty: true
    prune: true
    selfHeal: true
  syncOptions:
    - ServerSideApply=true
    - CreateNamespace=true
```

---

## Final `envoy-gateway.yaml`

```yaml
kind: Namespace
apiVersion: v1
metadata:
  name: envoy-gateway
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: envoy-gateway
  namespace: argocd
spec:
  destination:
    namespace: envoy-gateway
    server: https://kubernetes.default.svc
  project: default
  source:
    repoURL: mirror.gcr.io/envoyproxy
    chart: gateway-helm
    targetRevision: v1.7.2
    helm:
      skipCrds: true
      valuesObject:
        global:
          imageRegistry: mirror.gcr.io
        config:
          envoyGateway:
            provider:
              type: Kubernetes
              kubernetes:
                deploy:
                  type: GatewayNamespace
  syncPolicy:
    automated:
      allowEmpty: true
      prune: true
      selfHeal: true
    syncOptions:
      - ServerSideApply=true
      - CreateNamespace=true
```

---

## Final `gateway.yaml`

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: envoygateway-argo
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
  parametersRef:
    group: gateway.envoyproxy.io
    kind: EnvoyProxy
    name: argo
    namespace: envoy-gateway
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyProxy
metadata:
  name: argo
  namespace: envoy-gateway
spec:
  logging:
    level:
      default: info
  shutdown:
    drainTimeout: 180s
  provider:
    type: Kubernetes
    kubernetes:
      envoyService:
        externalTrafficPolicy: Local
```

---

## Verification — Final State

```bash
kubectl get application envoy-gateway -n argocd
```

```
NAME            SYNC STATUS   HEALTH STATUS
envoy-gateway   Synced        Healthy
```

```bash
kubectl get gatewayclass envoygateway-argo
```

```
NAME                CONTROLLER                                      ACCEPTED   AGE
envoygateway-argo   gateway.envoyproxy.io/gatewayclass-controller   True       Xm
```

```bash
kubectl get pods -A | grep envoy
```

```
envoy-gateway   envoy-gateway-xxxxxxxxx-xxxxx   1/1   Running   0   Xm
```

---

## Key Lessons

| Issue | Root Cause | Fix |
|---|---|---|
| `EnvoyProxy` CRD not found on first apply | `GatewayClass` and `EnvoyProxy` were in same file as the ArgoCD Application | Split into `envoy-gateway.yaml` and `gateway.yaml` |
| ArgoCD `Unknown` sync status | `oci://docker.io/envoyproxy` requires auth for OCI manifest requests | Use `mirror.gcr.io/envoyproxy` without `oci://` prefix |
| Missing `envoyproxies` CRD | `installCRDs: true` is not a valid `gateway-helm` values key | Apply `install.yaml` directly then use `skipCrds: true` in ArgoCD |
| Competing deployment conflict | `install.yaml` created second deployment in `envoy-gateway-system` | Delete `envoy-gateway-system` namespace |
| Persistent `OutOfSync` on Gateway API CRDs | Helm chart desired state conflicts with K3s-owned CRDs | `skipCrds: true` in Helm source |
| `skipCRDs` strict decoding error | Incorrect field name casing | Use `skipCrds` not `skipCRDs` |
| Annotation too large error | `Replace=true` sync option stores full manifest in annotations | Remove `Replace=true`, use `ServerSideApply=true` only |