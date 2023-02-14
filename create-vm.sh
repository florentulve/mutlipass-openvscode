#! /bin/bash

set -o allexport; source ./config/.env; set +o allexport

USER="ubuntu"

echo "+-----------------------------------------------+"
echo "🖥️ Creating ${VM_NAME}"
echo "+-----------------------------------------------+"

multipass -vvv launch --name "${VM_NAME}" \
        --cloud-init ./cloud-init.yaml \
        --cpus "${VM_CPUS}" \
        --memory "${VM_MEM}" \
        --disk "${VM_DISK}" \


VM_IP=$(multipass info "${VM_NAME}" | grep IPv4 | awk '{print $2}')

multipass info "${VM_NAME}"

echo "${VM_IP} ${VM_DOMAIN}" > config/vm.hosts.config

echo "+-----------------------------------------------+"
echo "💾 Pushing config "
echo "+-----------------------------------------------+"
# share the directories 
multipass transfer ~/.gitconfig "${VM_NAME}":/home/${USER}/.gitconfig
multipass transfer .tool-versions "${VM_NAME}":/home/${USER}/.tool-versions
multipass transfer ./asdf-install-plugins "${VM_NAME}":/home/${USER}/asdf-install-plugins
multipass transfer ~/.config/Code/User/settings.json "${VM_NAME}":/home/${USER}/asdf-install-plugins

echo "+-----------------------------------------------+"
echo "💾 Installing Stuffs "
echo "+-----------------------------------------------+"

multipass exec myvm -- bash <<EOF
curl -sS https://starship.rs/install.sh | sudo sh -s -- -y
echo -e "\neval \"\$(starship init bash)\"" >> ~/.bashrc
echo -e "\nstarship init fish | source" >> ~/.config/fish/config.fish
EOF

echo "+-----------------------------------------------+"
echo "💾 Installing ASDF "
echo "+-----------------------------------------------+"

multipass exec myvm -- bash <<EOF
git -c advice.detachedHead=false clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.11.1
echo -e "\nsource ~/.asdf/asdf.sh" >> ~/.bashrc
echo -e "\nsource ~/.asdf/completions/asdf.bash" >> ~/.bashrc
source ~/.asdf/asdf.sh
env
~/asdf-install-plugins
asdf install
EOF

echo echo "+-----------------------------------------------+"
echo "💾 Mounting directory"
echo "+-----------------------------------------------+"


multipass mount ./ "${VM_NAME}":/home/${USER}/workspace

# Install and Start OpenVSCode Server
multipass --verbose exec "${VM_NAME}" -- bash <<EOF
echo "+-----------------------------------------------+"
echo "💾 Installing OpenVSCode Server"
echo "+-----------------------------------------------+"
cd ~
wget -q https://github.com/gitpod-io/openvscode-server/releases/download/openvscode-server-v${OPENVSCODE_SERVER_VERSION}/openvscode-server-v${OPENVSCODE_SERVER_VERSION}-${OPENVSCODE_SERVER_OS}-${OPENVSCODE_SERVER_ARCH}.tar.gz
tar -xzf openvscode-server-v${OPENVSCODE_SERVER_VERSION}-${OPENVSCODE_SERVER_OS}-${OPENVSCODE_SERVER_ARCH}.tar.gz
rm openvscode-server-v${OPENVSCODE_SERVER_VERSION}-${OPENVSCODE_SERVER_OS}-${OPENVSCODE_SERVER_ARCH}.tar.gz

echo "+-----------------------------------------------+"
echo "🚀 Start OpenVSCode Server"
echo "+-----------------------------------------------+"
cd openvscode-server-v${OPENVSCODE_SERVER_VERSION}-${OPENVSCODE_SERVER_OS}-${OPENVSCODE_SERVER_ARCH}
./bin/openvscode-server --port ${OPENVSCODE_SERVER_PORT} --host ${VM_IP} --without-connection-token &
echo "🌍 http://${VM_IP}:${OPENVSCODE_SERVER_PORT}/?folder=/home/${USER}/workspace"
EOF

echo "+-----------------------------------------------+"
echo "🖐️ Update your /etc/hosts file with:"
cat config/"${VM_NAME}".hosts.vm.config
echo "+-----------------------------------------------+"
