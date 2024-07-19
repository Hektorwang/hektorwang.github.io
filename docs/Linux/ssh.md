---
title: "ssh"
date: 2024-07-18 00:00:00 +0000
categories: Linux
author: Niko
---

## Opening Software on a Remote Server via X11

### On the server (X11-SERVER)

```bash
# Install necessary packages
yum install -y xorg-x11-xauth
# This is a rough implementation;
# Should use sed for a more precisec onfiguration.
echo "unset LIBGL_ALWAYS_INDIRECT" >> ~/.bashrc
echo "export DISPLAY=:0.0" >> ~/.bashrc
sudo bash -c "echo 'X11Forwarding yes
X11UseLocalhost no
X11DisplayOffset 10' >> /etc/ssh/sshd_config"
sudo systemctl restart sshd
```

### On the client (X11-CLIENT)

```bash
ssh -XYT "${X11-SERVER-IP}" xclock
```
