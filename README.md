# myuen_inception
documentation and files for ft_inception @ 42

1. downloaded debian-12.9.0-amd64-netinst (bookworm), as latest Debian is version 13 (trixie).
2. set up vm using vituralbox -
  [X] XFCE (Check this for your lightweight GUI).
  [X] SSH server (Check this so you can terminal into the VM from the school host).
  [X] standard system utilities (Check this for basic commands like curl or git).
3. Enable Sudo and Add me as User
```
su - <password>
apt update && apt install sudo -y
usermod -aG sudo myuen
```
4. update system
```
   sudo apt update && sudo apt full-upgrade -y
```
5. Install the Docker Engine

### Add Docker's official GPG key:
```
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

### Add the repository to Apt sources:
```
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
```

### Install Docker components:
```
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```
