# ssh

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

## Compiling OpenSSH with musl on AlmaLinux 9.4

Updating OpenSSH on a Linux host is a common task. According to [CVE-2024-6387](https://nvd.nist.gov/vuln/detail/CVE-2024-6387), this security risk affects many openssh-server compiled with glibc. In this article, we'll demonstrate how to compile OpenSSH with musl on AlmaLinux 9.4.

### Prerequisites

- Compile OpenSSH requires an SSL library like OpenSSL. We'll use [openssl-3.0.14](https://github.com/openssl/openssl/releases/download/openssl-3.0.14/openssl-3.0.14.tar.gz.asc)
- We'll also need the musl libc library: [musl-1.2.5](https://musl.libc.org/releases/musl-1.2.5.tar.gz)
- Finally, [openssh-9.8p1](https://cloudflare.cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-9.8p1.tar.gz)

### Note

Since the official OpenSSH doesn't support RHEL's systemd notify function, the systemd-devel package will be required for compiling OpenSSH on AlmaLinux.

### Steps

1. Install systemd-devel and other requirements

   ```bash
   dnf install -y systemd-devel pam pam-devel zlib zlib-devel perl-IPC-Cmd perl make gcc patch

   ```

2. Install musl

3. Compile and install openssl

4. Compile and install openssh
