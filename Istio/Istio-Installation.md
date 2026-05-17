# Installation:
---

## Install Istio
```bash
curl -L https://istio.io/downloadIstio | sh -

cp istio-1.28.2/bin/istioctl /usr/local/bin                          

# export PATH=$PWD/bin:$PATH
# istioctl install -f samples/bookinfo/demo-profile-no-gateways.yaml -y

istioctl install -f istio-1.28.2/samples/bookinfo/demo-profile-no-gateways.yaml -y 

kubectl label namespace default istio-injection=enabled
```
## Install K8s CRDs
```bash
kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || \
{ kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v1.4.0" | kubectl apply -f -; }
```

