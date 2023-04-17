# cloud-gitops

This repository will be used for the configuration of the feddema.dev Kubernetes Cluster. Different GitOps principles will be applied in this repository.


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
kubectl run postgresql-client --rm --tty -i --restart='Never' --namespace postgresql --image docker.io/bitnami/postgresql:14.4.0-debian-11-r9 --env="PGPASSWORD=$POSTGRES_PASSWORD" --command -- psql --host postgresql -U postgres -d postgres -p 5432
```

Or the connect form outside the cluster run:

```bash
kubectl port-forward --namespace postgresql svc/postgresql 5432:5432 PGPASSWORD="$POSTGRES_PASSWORD" psql --host 127.0.0.1 -U postgres -d postgres -p 5432
```

### Create user and database

```psql
CREATE DATABASE <NAME>;
CREATE USER <NAME> WITH ENCRYPTED PASSWORD '<PASSWORD>';
GRANT ALL PRIVILEGES ON DATABASE <NAME> TO <NAME>
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

## Mysql

```bash
export MYSQL_ROOT_PASSWORD=$(kubectl get secret --namespace mysql mysql-credentials -o jsonpath="{.data.mysql-root-password}" | base64 -d)
```

```bash
kubectl run mysql-client --rm --tty -i --restart='Never' --image  docker.io/bitnami/mysql:8.0.30-debian-11-r15 --namespace mysql --env MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD --command -- bash
```

```bash
mysql -h mysql.mysql.svc.cluster.local -uroot -p "$MYSQL_ROOT_PASSWORD"
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

## Node setup

1. passwd
2. sudo usermod -aG sudo localadmin
3. echo "localadmin ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/localadmin
4. cat ~/.ssh/id_ed25519.pub | ssh localadmin@targon.feddema.dev -p 6022 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
5. sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y
6. sudo apt install curl gnupg2 software-properties-common apt-transport-https ca-certificates net-tools -y
7. sudo swapoff -a && sudo sed -i '/swap.img/ s/^/#/' /etc/fstab
8. sudo hostnamectl set-hostname targon
9. sudo curl -fsSLo /etc/apt/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
10. echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
11. sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y
12. sudo apt -y install kubelet=1.27.1-00 kubeadm=1.27.1-00 kubectl=1.27.1-00
13. sudo apt-mark hold kubelet kubeadm kubectl
14. cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
15. sudo modprobe overlay && sudo modprobe br_netfilter
16. cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
17. sudo sysctl --system
18. curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
19. echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
20. sudo apt update
21. sudo apt install containerd.io -y
22. sudo containerd config default > /etc/containerd/config.toml
23. sudo systemctl restart containerd
24. sudo systemctl enable containerd
25. sudo kubeadm config images pull
26. nano config.yaml
27. sudo kubeadm init --config config.yaml
28. mkdir -p $HOME/.kube
29. sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
30. sudo chown $(id -u):$(id -g) $HOME/.kube/config
31. kubectl taint nodes --all node-role.kubernetes.io/control-plane-
32. sudo apt install open-iscsi jq nfs-common -y
33. curl -sSfL https://raw.githubusercontent.com/longhorn/longhorn/v1.2.4/scripts/environment_check.sh | bash
