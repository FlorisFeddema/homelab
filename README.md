# cloud-gitops

This repository will be used for the configuration of the feddema.dev Kubernetes Cluster. Different GitOps principles will be applied in this repository.

<!-- TOC -->
* [cloud-gitops](#cloud-gitops)
  * [Kubeseal](#kubeseal)
    * [Restore key in new cluster](#restore-key-in-new-cluster)
  * [PostgreSQL](#postgresql)
    * [Create user and database](#create-user-and-database)
    * [Upgrade](#upgrade)
  * [Upgrade kubernetes](#upgrade-kubernetes)
  * [Install ArgoCD applications by hand](#install-argocd-applications-by-hand)
  * [Node setup](#node-setup)
  * [Install load balancer](#install-load-balancer)
  * [Known issues](#known-issues)
<!-- TOC -->

## Kubeseal

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: database-credentials
  namespace: default
type: Opaque
stringData:
  username: admin
  password: p4ssw0rd
```

To create a new encrypted secret run the following command:

```shell
kubeseal --controller-namespace sealed-secrets -o yaml <INPUT.yaml >OUTPUT.yaml
```

To encrypt a single value run the following command:

```shell
echo -n <VALUE> | kubeseal --controller-namespace sealed-secrets --raw --namespace <NAMESPACE> --name <NAME>
```

### Restore key in new cluster

1. kubectl get secrets -n sealed-secrets -o yaml > out.yaml
2. !! UPDATE KEY AND CRT !!
3. kubectl apply -f out.yaml
4. rm out.yaml
5. kubectl rollout restart -n sealed-secrets deployment sealed-secrets-controller

## PostgreSQL

PostgreSQL can be assed via port 5432 on the following DNS name from withing the cluster:

```md
postgresql.postgresql.svc.cluster.local
```

Get the database password by running the following command:

```bash
export POSTGRES_PASSWORD=$(kubectl get secret --namespace postgresql postgresql-credentials -o jsonpath="{.data.postgres-password}" | base64 -d)
```

To connect to the database run the following command: 

```bash
kubectl run postgresql-client --rm --tty -i --restart='Never' --namespace postgresql --image docker.io/bitnami/postgresql:latest --env="PGPASSWORD=$POSTGRES_PASSWORD" --command -- psql --host postgresql -U postgres -d postgres -p 5432
```

Or the connect form outside the cluster run:

```bash
kubectl port-forward --namespace postgresql svc/postgresql 5432:5432 PGPASSWORD="$POSTGRES_PASSWORD" psql --host 127.0.0.1 -U postgres -d postgres -p 5432
```

### Create user and database

```psql
CREATE DATABASE <NAME>;
CREATE USER <NAME> WITH ENCRYPTED PASSWORD '<PASSWORD>';
GRANT ALL PRIVILEGES ON DATABASE <NAME> TO <NAME>;
ALTER DATABASE <NAME> OWNER TO <NAME>;
```

### Upgrade

```bash
k port-forward -n postgresql postgresql-0 5432:5432
pg_dumpall -U postgres -h localhost -p 5432 > dump.sql
```

Remove pvc from Longhorn and update the container to the ner Postgresql version.

```bash
psql -h localhost -p 5432 -U postgres < dump.sql
```

## Upgrade kubernetes

To upgrade the cluster to a new version, follow this steps.

**!!! Make sure to check whether all applications are compatible with the new Kubernetes version !!!**

Check which Kubernetes version you want to upgrade to.
Run the following commands on a node:

```bash
sudo apt update
sudo apt-cache madison kubeadm
```

Now upgrade the control plane nodes:

```bash
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm=<KUBE_VERSION>
sudo apt-mark hold kubeadm
```

Confirm that kubeadm is running on the new version and plan the upgrade:

```bash
sudo kubeadm version
sudo kubeadm upgrade plan <KUBE_VERSION>
```

When upgrading kubeadm automatically renews the API certificates, to opt out of this add `--certificate-renewal=false` to the command:

```bash
sudo kubeadm version
sudo kubeadm upgrade apply <KUBE_VERSION>
```

If u did renew the API certificates save them so you can connect to the cluster. It is located at `/etc/kubernetes/admin.conf`

Now upgrade the kubelet on the node:

```bash
kubectl drain <NODE_NAME> --ignore-daemonsets --delete-emptydir-data
sudo apt-mark unhold kubelet kubectl
sudo apt-get update
sudo apt-get install -y kubelet=<KUBE_VERSION> kubectl=<KUBE_VERSION>
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet
kubectl uncordon <NODE_NAME>
```

## Install ArgoCD applications by hand

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus-crds prometheus-community/prometheus-operator-crds
```

```bash
bash ./install.sh base external-dns
```

## Node setup

1. cat ~/.ssh/id_ed25519.pub | ssh localadmin@targon.feddema.dev -p 6022 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
0. passwd
0. sudo usermod -aG sudo localadmin
0. echo "localadmin ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/localadmin
0. sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y
0. sudo apt install curl gnupg2 software-properties-common apt-transport-https ca-certificates net-tools open-iscsi jq nfs-common -y
0. sudo swapoff -a && sudo sed -i '/swap.img/ s/^/#/' /etc/fstab
0. sudo rm -rf /etc/cloud/ && sudo rm -rf /var/lib/cloud/
0. echo "fs.inotify.max_user_instances=512" | sudo tee -a /etc/sysctl.conf
0. echo "fs.inotify.max_user_watches=204800" | sudo tee -a /etc/sysctl.conf
0. sudo install -m 0755 -d /etc/apt/keyrings
0. curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
0. sudo chmod a+r /etc/apt/keyrings/docker.gpg
0. echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
0. sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y
0. sudo apt install containerd.io 
0. cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
    EOF
0. sudo modprobe overlay && sudo modprobe br_netfilter
0. cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
    EOF
0. sudo sysctl --system
0. sudo containerd config default > /etc/containerd/config.toml
0. !! CHANGE SystemdCgroup = true IN \[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options] !!
0. sudo systemctl restart containerd
0. sudo systemctl enable containerd
0. curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
0. echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
0. sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y
0. sudo apt -y install kubelet=1.27.3-00 kubeadm=1.27.3-00 kubectl=1.27.3-00
0. sudo apt-mark hold kubelet kubeadm kubectl
0. nano config.yaml
0. sudo kubeadm init --config config.yaml --skip-phases=addon/kube-proxy --upload-certs
0. mkdir -p $HOME/.kube
0. sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
0. sudo chown $(id -u):$(id -g) $HOME/.kube/config
0. kubectl taint nodes --all node-role.kubernetes.io/control-plane-

## Install load balancer

1. apk add nginx
0. apk add nginx-mod-stream
0. rm /etc/nginx/nginx.conf
0. nano /etc/nginx/nginx.conf
0. service nginx start

## Known issues

- https://longhorn.io/kb/troubleshooting-volume-with-multipath/

## Sources

- [GPU Passthrough](https://3os.org/infrastructure/proxmox/gpu-passthrough/igpu-passthrough-to-vm/#linux-virtual-machine-igpu-passthrough-configuration)

## Disk install

sudo mkdir /mnt/ssd1
lsblk -f
sudo fdisk -l
sudo gdisk /dev/sdb
-> n
-> ENTER TILL THE END
-> w
sudo mkfs.ext4 /dev/sdb1
lsblk -f
echo "UUID=b5d85b8f-4860-4e31-a80c-53ce7d88840a /mnt/ssd1 ext4 defaults 0 0" >>/etc/fstab
sudo reboot
