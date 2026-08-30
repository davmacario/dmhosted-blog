---
date: "2026-08-24T18:49:44+02:00"
draft: false
title: Tailscale and Kubernetes
summary: "Exposing Kubernetes workloads via Tailscale, using custom domain names and valid TLS certs"
tags:
  - kubernetes
  - tailscale
  - homelab
  - networking
---

I've been using Tailscale since 2020 now, and I've recently migrated all (most) of my homelab applications to a Kubernetes cluster I put together (God bless [Marktplaats](https://marktplaats.nl) and the time SSDs and RAM were cheaper).
As I'm the only user of most applications I run, and I want to be able to reach these services from outside of my home network, I pretty soon landed on the [Tailscale Kubernetes Operator](https://tailscale.com/docs/kubernetes-operator) as the way to securely achieve this.

As much as I love Tailscale, though, I am not a huge fan of having to use the Magic DNS domain names they provide out of the box when using their operator.

In this article, I will go through my current setup, which allows me to achieve secure and private access to applications running on my homelab, using my custom domain, and valid TLS certificates.

## Setup description

### Requirements

- A Kubernetes cluster (ARM is supported!)
- [Helm](https://helm.sh/)
- A domain name (I got mine, `dmhosted.com`, through [Cloudflare](https://www.cloudflare.com/products/registrar/))
- [cert-manager](https://cert-manager.io/) installed on your cluster
- A [Tailscale](https://tailscale.com/) account
- One (or more) custom DNS server for your Tailnet (see [how to](https://tailscale.com/docs/reference/dns-in-tailscale))
- The Tailscale Kubernetes Operator installed on your cluster; I followed the [official guide](https://tailscale.com/docs/kubernetes-operator/install-operator), using Helm

Extras (optional):

- [ExternalDNS](https://kubernetes-sigs.github.io/external-dns/v0.15.0/) - nice to have, allows to automatically create DNS records on your server; the setup is out of the scope of this article and depends on what your DNS server runs on

Additionally, this guide assumes that an instance of Traefik is already deployed on the cluster, as this was my case.

### Rationale

The Tailscale Kubernetes Operator provides the `ProxyGroup` CRD which is used to define Tailscale proxies routing traffic from your Tailnet to a specific K8s Service.

`ProxyGroup`s can be used to expose workloads in 2 ways:

- Defining an `Ingress` using the tailscale `IngressClass`, fronting an existing `Service` of type `ClusterIP`, so at [level 7](https://tailscale.com/docs/kubernetes-operator/ingress/expose-workload-to-tailnet-l7); this happens by referencing the `ProxyGroup` from the `Ingress`
- Defining a `Service` of `type: LoadBalancer`, using `loadBalancerClass: tailscale`, so at [level 3](https://tailscale.com/docs/kubernetes-operator/ingress/expose-workload-to-tailnet-l3); this is achieved by referencing the `ProxyGroup` from the `Service`

The issue with just exposing each app using the first method is that it makes it impossible to assign custom domains, and fills up the Tailscale dashboard with several entries associated with each `ProxyGroup`.
Using the 2nd method to expose each app, instead, is cumbersome, as it does not handle TLS termination or domain names out of the box.

The solution is to deploy an(other) instance of Traefik, and expose it to Tailscale using the second method.
Then, it will be possible to use `Ingress` (or better, Traefik's own `IngressRoute`) resources to route traffik over this new Traefik instance.

This allows to only expose one single `Service` to Tailscale (Traefik's), while having the ability to use custom domain names (tied to the `IngressRoute` routing rules), achieving maximum freedom.

### Implementation

#### Configuring Tailscale (`ProxyGroup`)

In order to allow Traefik to accept traffic over Tailscale, we need to define the proper resources via the Tailscale Operator.

First, we need to define a `ProxyGroup` to proxy Tailscale traffic towards Traefik.
To reliably expose `Service`s, we would like to avoid single points of failure in the networking setup, and as such it would be preferred to have at least 2 proxy containers defined, i.e., a `ProxyGroup` with `replicas: 2` (or more - having 2 allows to avoid downtime when performing rolling reboots and tolerating up to 1 node failure).

Manifest:

```yaml
apiVersion: tailscale.com/v1alpha1
kind: ProxyGroup
metadata:
  name: ingress-proxies-traefik
spec:
  type: ingress
  replicas: 2
```

#### Installing Traefik (via Helm)

Since in my cluster there is already an `IngressController` named `traefik`, the name of the new instance will be `traefik-tailscale`.

Following the [Tailscale Operator docs](https://tailscale.com/docs/kubernetes-operator/ingress/expose-workload-to-tailnet-l3#expose-the-service-with-l3-ingress),
in order to use the `ProxyGroup` created in the [previous section](#configuring-tailscale-proxygroup),
we need to:

1. Set the service type to `LoadBalancer`
2. Set the load balancer class to `tailscale`
3. Set the following _annotations_ on the `Service`:

   ```yaml
   # Links the Service to the ProxyGroup
   tailscale.com/proxy-group: ingress-proxies-traefik
   # Sets the MagicDNS hostname for the Tailscale Service
   tailscale.com/hostname: traefik-tailscale
   ```

Translated to Helm values for Traefik (tested with chart version 41.3.0):

```yaml
global:
  checkNewVersion: false
  sendAnonymousUsage: false
additionalArguments:
  - "--serversTransport.insecureSkipVerify=true" # Skip cert validation of internal services
deployment:
  enabled: true
  replicas: 1
  annotations: {}
  podAnnotations: {}
  additionalContainers: []
  initContainers: []
ports:
  web:
    port: 80
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
          permanent: true
  websecure:
    port: 443
    http:
      tls:
        enabled: true
ingressClass:
  enabled: true
  isDefaultClass: false
  name: traefik-tailscale # IMPORTANT: avoid collision with existing instance
ingressRoute:
  dashboard: # Dashboard enabled separately
    enabled: false
providers:
  kubernetesCRD:
    enabled: true
    # Allows to specify `ingressClassName: traefik-tailscale` in IngressRoutes
    ingressClass: traefik-tailscale
  kubernetesIngress:
    enabled: true
rbac:
  enabled: true
service:
  enabled: true
  type: LoadBalancer
  spec:
    loadBalancerClass: tailscale
  annotations:
    # Links the Service to the ProxyGroup
    tailscale.com/proxy-group: ingress-proxies-traefik
    # Sets the MagicDNS hostname for the Tailscale Service
    tailscale.com/hostname: traefik-tailscale
  labels: {}
  loadBalancerSourceRanges: []
  externalIPs: []
```

Install using these values as follows:

```bash
helm install traefik-tailscale traefik/traefik \
  --namespace traefik-tailscale \
  --create-namespace \
  -f ./kubernetes/traefik-tailscale/values.yaml
```

or via your GitOps tool of choice.

#### DNS configuration

In order to route traffic directed to our (sub-) domain towards the new Traefik instance, we need to grab the Tailscale IP of the `Service`, provided by the `tailscale` `LoadBalancerClass`.

To display information about the `LoadBalancer` service, run:

```bash
kubectl get svc -n traefik-tailscale
```

For example:

```text
NAME                           TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)                      AGE
traefik-tailscale              LoadBalancer   10.43.240.238   100.84.247.181   80:32446/TCP,443:31390/TCP   176d
```

This confirms that the Tailscale IP was assigned correctly.

This means that any service exposed over this Traefik instance will use this IP "underneath".
In other words, to successfully expose services over Tailscale (with Traefik), we need to configure our DNS server to respond to queries for our custom domains with that IP.

In my case, I decided to allocate the `*.internal.dmhosted.com` subdomain to services exposed via VPN only.
Thus, in my DNS server, I have configured a rewrite rule mapping the subdomain to the IP shown above (`100.84.247.181`).

> [!TIP]
>
> This can also be achieved via external-dns on a per-domain basis (each time a new `IngressRoute` is defined, external-dns will create the record).

#### Testing

The new Traefik instance can be tested by deploying a dummy Nginx pod and exposing it via an `IngressRoute`.

In manifest (replace `mydomain.com` with your domain):

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: nginx
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: nginx
  labels:
    app: nginx
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 1
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          imagePullPolicy: IfNotPresent
          resources:
            limits:
              cpu: 100m
              memory: 100Mi
          ports:
            - containerPort: 80
              name: http
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
  namespace: nginx
spec:
  type: ClusterIP
  selector:
    app: nginx
  ports:
    - port: 80
      targetPort: http
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: nginx-ingressroute-certificate-internal
  namespace: nginx
spec:
  secretName: nginx-certificate-secret-prod-internal
  issuerRef:
    name: cloudflare-clusterissuer
    kind: ClusterIssuer
  dnsNames:
    - nginx.mydomain.com
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: nginx-ingressroute-tailscale
  namespace: nginx
spec:
  ingressClassName: traefik-tailscale
  entryPoints:
    - websecure
  routes:
    - match: Host(`nginx.mydomain.com`)
      kind: Rule
      services:
        - name: nginx
          port: 80
  tls:
    secretName: nginx-certificate-secret-prod-internal
```

> [!NOTE]
>
> This assumes a cert-manager `ClusterIssuer` named `cloudflare-clusterissuer` exists.

## Added Benefits of This Setup

As stated before, this setup allows customizing domain names of Kubernetes worloads exposed within Tailscale.

Being essentially a different Traefik installation than the "main" one (which can be used to expose services publicly), this allows to provide a secure method to access resources that should remain "internal".
In my case, for example, even though my cluster runs some public services, this method allows me to keep things such as internal dashboards (Longhorn, Traefik) internal to my VPN.

---

## Links and Credits

- [Private kubernetes ingress with tailscale operator, cert-manager and external-dns](https://medium.com/@mattiaforc/zero-trust-kubernetes-ingress-with-tailscale-operator-cert-manager-and-external-dns-8f42272f8647)
- [Tailscale Kubernetes Operator](https://tailscale.com/docs/kubernetes-operator)
