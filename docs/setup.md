# Setup

First you will need the following:

- 1Password
- An AWS Account
- An IAM User with *Programmatic Access* configuration, and the Access Key and Secret Access Key from that user.
- A Domain that has been setup with Route53
- A Virtual Machine with a Public IPv4 Address

## 1Password Credentials

- Create a vault called `Homelab`
- Follow https://developer.1password.com/docs/connect/get-started/#step-1-set-up-a-secrets-automation-workflow 1Password.com tab for generating 1password-credentials.json and save into bootstrap directory.
- Follow https://developer.1password.com/docs/connect/get-started/#step-1-set-up-a-secrets-automation-workflow 1Password CLI tab for generating a 1password connect token and save as 1password-token.secret in bootstrap directory.

```shell
export domain=mydomain.tld
export ip=0.0.0.0/32
export hcloudsecret=""

kubectl create namespace 1passwordconnect
kubectl create secret generic 1passwordconnect --namespace 1passwordconnect --from-literal 1password-credentials.json=$(cat 1password-credentials.json | base64 )

kubectl create namespace external-secrets
kubectl create secret generic 1passwordconnect --namespace external-secrets --from-file=token=1password-token.secret

kubectl create namespace argocd
kubectl create secret generic stringreplacesecret --namespace argocd --from-literal domain=$domain --from-literal ip=$ip --from-literal hcloudsecret=$hcloudsecret
```

## Argocd Install

```
export argocd_applicationyaml=$(curl -sL "https://raw.githubusercontent.com/mattkgwhite/home-ops/main/manifests/argocd.yaml" | yq eval-all '. | select(.metadata.name == "argocd" and .kind == "Application")' -)
export argocd_name=$(echo "$argocd_applicationyaml" | yq eval '.metadata.name' -)
export argocd_chart=$(echo "$argocd_applicationyaml" | yq eval '.spec.source.chart' -)
export argocd_repo=$(echo "$argocd_applicationyaml" | yq eval '.spec.source.repoURL' -)
export argocd_namespace=$(echo "$argocd_applicationyaml" | yq eval '.spec.destination.namespace' -)
export argocd_version=$(echo "$argocd_applicationyaml" | yq eval '.spec.source.targetRevision' -)
export argocd_values=$(curl -sL "https://raw.githubusercontent.com/mattkgwhite/home-ops/main/bootstrap/argocd-values.yaml")

# install
echo "$argocd_values" | helm template $argocd_name $argocd_chart --repo $argocd_repo --version $argocd_version --namespace $argocd_namespace --values - | kubectl apply -n $argocd_namespace -f -

# configure
kubectl apply -f https://raw.githubusercontent.com/mattkgwhite/home-ops/main/bootstrap/argocd-config.yaml
```

## Argo Install - New Way

```
export argocd_applicationyaml=$(curl -sL "https://raw.githubusercontent.com/mattkgwhite/home-ops/main/manifests/argocd.yaml" | yq eval-all '. | select(.metadata.name == "argocd" and .kind == "Application")' -)
export argocd_name=$(echo "$argocd_applicationyaml" | yq eval '.metadata.name' -)
export argocd_chart=$(echo "$argocd_applicationyaml" | yq eval '.spec.source.chart' -)
export argocd_repo=$(echo "$argocd_applicationyaml" | yq eval '.spec.source.repoURL' -)
export argocd_namespace=$(echo "$argocd_applicationyaml" | yq eval '.spec.destination.namespace' -)
export argocd_version=$(echo "$argocd_applicationyaml" | yq eval '.spec.source.targetRevision' -)
# removing .configs.cm from bootstrap requires argovaultplugin variables
export argocd_values=$(echo "$argocd_applicationyaml" | yq eval '.spec.source.helm.values' - | yq eval 'del(.configs.cm)' -)
export argocd_config=$(curl -sL "https://raw.githubusercontent.com/mattkgwhite/home-ops/main/manifests/argocd.yaml" | yq eval-all '. | select(.kind == "AppProject" or .kind == "ApplicationSet")' -)

# install
echo "$argocd_values" | helm template $argocd_name $argocd_chart --repo $argocd_repo --version $argocd_version --namespace $argocd_namespace --values - | kubectl apply --namespace $argocd_namespace --filename -

# configure
echo "$argocd_config" | kubectl apply --filename -
```


### Troubleshooting

#### Removing CRDs that are stuck on troubleshooting

kubectl patch crd/appprojects.argoproj.io -p '{"metadata":{"finalizers":[]}}' --type=merge