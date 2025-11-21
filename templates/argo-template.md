# Argo Template

Within this folder there is another folder called *manifests* which contains all the deployments for the services that are required for a basic deployment of ArgoCD.

The primary documentation for the setup can be found in [Argo Setup Documentation](../docs/setup/argo.md).

There are some additional configuration setups that need to be completed. The primary one, is updating the *<domain>* reference to a domain, as failing to do this will result in no access to the ArgoCD dashboard / UI.

## Access Issues - SSL Certificate Status and HTTP Route

An additional step to this, is that all the SSL certificates that are issued by Cert-Manager need to be *Ready = True* when running *kubectl get certificates -A* command. If the certificates are not *ready* Gateway API will not create the relevant HTTP Routes to provide access to the services such as ArgoCD's UI.
