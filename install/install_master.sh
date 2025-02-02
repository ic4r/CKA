#!/bin/sh

# Source: http://kubernetes.io/docs/getting-started-guides/kubeadm/
# source : https://raw.githubusercontent.com/killer-sh/cks-course-environment/master/cluster-setup/latest/install_master.sh

### setup terminal
apt-get update
apt-get install -y bash-completion binutils
echo 'colorscheme ron' >> ~/.vimrc
echo 'set tabstop=2' >> ~/.vimrc
echo 'set shiftwidth=2' >> ~/.vimrc
echo 'set expandtab' >> ~/.vimrc
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'alias c=clear' >> ~/.bashrc
echo 'complete -F __start_kubectl k' >> ~/.bashrc
sed -i '1s/^/force_color_prompt=yes\n/' ~/.bashrc

### disable linux swap and remove any existing swap partitions
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

### install k8s and docker
apt-get remove -y docker.io kubelet kubeadm kubectl kubernetes-cni
apt-get autoremove -y
apt-get install -y etcd-client vim build-essential

systemctl daemon-reload
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
KUBE_VERSION=1.21.0
apt-get update
apt-get install -y docker.io kubelet=${KUBE_VERSION}-00 kubeadm=${KUBE_VERSION}-00 kubectl=${KUBE_VERSION}-00 kubernetes-cni=0.8.7-00

cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "storage-driver": "overlay2"
}
EOF
mkdir -p /etc/systemd/system/docker.service.d

# Restart docker.
systemctl daemon-reload
systemctl restart docker

# start docker on reboot
systemctl enable docker

docker info | grep -i "storage"
docker info | grep -i "cgroup"

systemctl enable kubelet && systemctl start kubelet


### init k8s
rm /root/.kube/config
kubeadm reset -f
kubeadm init --kubernetes-version=${KUBE_VERSION} --ignore-preflight-errors=NumCPU --skip-token-print

mkdir -p ~/.kube
sudo cp -i /etc/kubernetes/admin.conf ~/.kube/config
sudo cp ~/.kube/config ~ubuntu/kubeconfig
sudo chown ubuntu:ubuntu ~ubuntu/kubeconfig

sudo cp -R ~root/.kube ~ubuntu
sudo chown -R ubuntu:ubuntu ~ubuntu/.kube

KUBECTL_ENCODING=$(/usr/bin/kubectl version | /usr/bin/base64 | /usr/bin/tr -d '\n')
echo "KUBECTL_ENCODING=$KUBECTL_ENCODING" > ~/kubectl_ver
sudo /usr/bin/kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=${KUBECTL_ENCODING}"

echo
echo "### COMMAND TO ADD A WORKER NODE ###"
kubeadm token create --print-join-command --ttl 0 > ~/join_token
