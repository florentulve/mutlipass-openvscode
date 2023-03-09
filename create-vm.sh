#! /bin/bash

./gum format --theme dracula < hello

set -o allexport; source ./config/.env; set +o allexport

USER="ubuntu"

echo "+-----------------------------------------------+"
echo "🖥️ Creating ${VM_NAME}"
echo "+-----------------------------------------------+"

#multipass delete "${VM_NAME}" && multipass purge

#sleep 5

multipass -vvv launch --name "${VM_NAME}" \
        --cloud-init ./cloud-init.yaml \
        --cpus "${VM_CPUS}" \
        --memory "${VM_MEM}" \
        --disk "${VM_DISK}" \

VM_IP=$(multipass info "${VM_NAME}" | grep IPv4 | awk '{print $2}')

multipass info "${VM_NAME}"

echo "${VM_IP} ${VM_DOMAIN}" > config/${VM_NAME}.vm.hosts.config

echo "+-----------------------------------------------+"
echo "💾 Pushing config "
echo "+-----------------------------------------------+"

# share the directories 
multipass transfer ~/.gitconfig "${VM_NAME}":/home/${USER}/.gitconfig
multipass transfer .tool-versions "${VM_NAME}":/home/${USER}/.tool-versions
multipass transfer ./asdf-install-plugins "${VM_NAME}":/home/${USER}/asdf-install-plugins

echo "+-----------------------------------------------+"
echo "💾 Installing ASDF "
echo "+-----------------------------------------------+"

multipass exec myvm -- bash <<EOF
git -c advice.detachedHead=false clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.11.1
echo -e "\nsource ~/.asdf/asdf.sh" >> ~/.bashrc
echo -e "\nsource ~/.asdf/completions/asdf.bash" >> ~/.bashrc
source ~/.asdf/asdf.sh
chmod +x ~/asdf-install-plugins && ~/asdf-install-plugins && asdf install
EOF

echo "+-----------------------------------------------+"
echo "💾 Installing fnm, sdkman "
echo "+-----------------------------------------------+"
multipass exec myvm -- bash <<EOF

curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "./.fnm" --skip-shell
printf '\nexport PATH="~/.fnm:$PATH"\n\
eval "\$(fnm env --use-on-cd)"\n\
eval "\$(fnm completions --shell bash)"\n' >> ~/.bashrc
~/.fnm/fnm install 19
curl -s "https://get.sdkman.io" | bash
EOF

echo "+-----------------------------------------------+"
echo "💾 Installing Starship "
echo "+-----------------------------------------------+"

multipass exec myvm -- bash <<EOF
curl -sS https://starship.rs/install.sh | sudo sh -s -- -y
echo -e '\neval "\$(starship init bash)"' >> ~/.bashrc
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
ln -s openvscode-server-v${OPENVSCODE_SERVER_VERSION}-${OPENVSCODE_SERVER_OS}-${OPENVSCODE_SERVER_ARCH} openvscode-server
cd openvscode-server
systemd-run --user --unit openvscode-server ./bin/openvscode-server --port ${OPENVSCODE_SERVER_PORT} --host ${VM_IP} --without-connection-token
echo "🌍 http://${VM_IP}:${OPENVSCODE_SERVER_PORT}/?folder=/home/${USER}/workspace"
EOF

multipass --verbose exec "${VM_NAME}" -- bash <<EOF

echo "+-----------------------------------------------+"
echo "🚀 Configuring OpenVSCode Server"
echo "+-----------------------------------------------+"

~/openvscode-server/bin/openvscode-server --install-extension sgtsquiggs.vscode-active-file-status
~/openvscode-server/bin/openvscode-server --install-extension annsk.alignment
~/openvscode-server/bin/openvscode-server --install-extension dracula-theme.theme-dracula
~/openvscode-server/bin/openvscode-server --install-extension EditorConfig.EditorConfig
~/openvscode-server/bin/openvscode-server --install-extension usernamehw.errorlens
~/openvscode-server/bin/openvscode-server --install-extension dbaeumer.vscode-eslint
~/openvscode-server/bin/openvscode-server --install-extension donjayamanne.githistory
~/openvscode-server/bin/openvscode-server --install-extension eamodio.gitlens
~/openvscode-server/bin/openvscode-server --install-extension exiasr.hadolint
~/openvscode-server/bin/openvscode-server --install-extension ms-kubernetes-tools.vscode-kubernetes-tools
~/openvscode-server/bin/openvscode-server --install-extension timonwong.shellcheck
~/openvscode-server/bin/openvscode-server --install-extension SonarSource.sonarlint-vscode
~/openvscode-server/bin/openvscode-server --install-extension webhint.vscode-webhint
~/openvscode-server/bin/openvscode-server --install-extension redhat.vscode-yaml

EOF


multipass transfer ~/.config/Code/User/settings.json "${VM_NAME}":/home/${USER}/.openvscode-server/data/Machine/settings.json

echo "+-----------------------------------------------+"
echo "🖐️ Update your /etc/hosts file with:"
cat config/${VM_NAME}.vm.hosts.config
echo "+-----------------------------------------------+"
