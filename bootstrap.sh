#!/bin/bash

darwin=false;
linux=false;

case "$(uname)" in
    Linux*)
        linux=true
        ;;
    Darwin*)
        darwin=true
        ;;
esac

echo -e "\033[1;39mVagrant...is it present?"

if ! command -v vagrant &> /dev/null; then
    echo -e "\033[1;31mVagrant not present...\n\033[1;39mInstalling..."
    if $linux; then
        version_vg=$(curl -s https://releases.hashicorp.com/vagrant/ | grep href | grep -v '\.\.' | head -1 | awk -F/ '{ print $3 }')
        curl -SLO https://releases.hashicorp.com/vagrant/${version_vg}/vagrant_${version_vg}_linux_amd64.zip
        curl -sSLO https://releases.hashicorp.com/vagrant/${version_vg}/vagrant_${version_vg}_SHA256SUMS
        checksum_vg=$(sha256sum -c vagrant_${version_vg}_SHA256SUMS 2>&1 | grep OK | awk -F:' ' '{ print $2 }')
        if [ "$checksum_vg" != "OK" ]; then
            exit 1
        fi
        unzip vagrant_${version_vg}_linux_amd64.zip && rm vagrant_${version_vg}_linux_amd64.zip vagrant_${version_vg}_SHA256SUMS
        sudo mv vagrant /usr/bin/vagrant
    elif $darwin; then
        brew install vagrant
    else
        echo -e "\033[1;31mOS not supported"
        exit 1
    fi
    echo -e "\033[1;32mDone!"
else
    echo -e "\033[1;32mVagrant is present!"
fi

echo -e "\033[1;39mProvider..."

if ! command -v virtualbox &> /dev/null; then
    echo -e "\033[1;31mVirtualBox not present...\nPlease, install a stable version of Oracle VirtualBox"
    exit 1
else
    echo -e "\033[1;32mVirtualBox is present!"
fi

echo -e "\033[1;39mInitializing...\nPlease, be aware this could take several minutes."

vagrant up --provider=virtualbox

until [ $(vagrant status | sed 1,2d | head -n3 | grep -o 'running' | wc -l) == 3 ]
do
    sleep 3 && echo "...wait for status: running"
done

echo -e "\033[1;32mUp and Running!"

echo -e "\033[1;39mkubectl...is it present?"

if ! command -v kubectl &> /dev/null; then
    echo -e "\033[1;31mkubectl not present\n\033[1;39mInstalling..."
    if $linux; then
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
        checksum_kctl=$(echo "$(<kubectl.sha256) kubectl" | sha256sum --check | awk -F:' ' '{ print $2 }')
        if [ "$checksum_kctl" != "OK" ]; then
            exit 1
        fi
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl kubectl.sha256
    elif $darwin; then
        brew install kubectl
    else
        echo -e "\033[1;31mOS not supported"
        exit 1
    fi
    echo -e "\033[1;32mDone!"
else
    echo -e "\033[1;32mkubectl is present!"
fi

echo -e "\033[1;39mConfiguring..."

if [ ! -d ~/.kube ]; then mkdir ~/.kube; fi

vagrant ssh master -- -t 'sudo cat /etc/kubernetes/admin.conf' > ~/.kube/config

echo -e "\033[1;32mDone!\033[1;39m"

while true; do
    read -r -p "Enable Dashboard UI (y/n): " answer
    case $answer in
        [Yy]* )
            kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.2.0/aio/deploy/recommended.yaml
            kubectl apply -f dashboard-adminuser.yaml
            echo -e ""
            kubectl -n kubernetes-dashboard get secret $(kubectl -n kubernetes-dashboard get sa/admin-user -o jsonpath="{.secrets[0].name}") -o go-template="{{.data.token | base64decode}}"
            echo -e "\033[1;39m\nPlease, use the token above to log into Dashboard UI."
            kubectl proxy &> /dev/null &
            echo -e "\033[1;39mTo access Dashboard UI, click the next URL:"
            echo -e "\033[1;33mhttp://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
            echo -e "\033[1;39mIn case of error, please open a new terminal session and type \033[1;33mkubectl proxy"; break;;
        [Nn]* ) exit;;
        * ) echo -e "\033[1;39mPlease, answer Y or N.";;
    esac
done
