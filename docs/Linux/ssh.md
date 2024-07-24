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

## Compiling OpenSSH with musl

Updating OpenSSH on a Linux host is a common task. According to [CVE-2024-6387](https://nvd.nist.gov/vuln/detail/CVE-2024-6387), this security risk affects many openssh-server compiled with glibc. In this article, I will try to compile a static OpenSSH on Alpine Linux and see whether it can run properly on RHEL.

### Requirements

- musl, pre-installed on Alpine Linux.
- [openssh-9.8p1](https://cloudflare.cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-9.8p1.tar.gz)
- Other system packages: see below

### Steps

#### 1. Install Required System Packages

```sh
sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories
apk update && apk upgrade && apk add autoconf build-base linux-headers linux-pam-dev zlib-dev openssl-dev zlib-static musl-dev openssl-libs-static
```

#### 2. Download Source Code Packages

Download the source code packages to the /tmp/src/ directory.

#### 3. Compile openssh

```sh
rm -rf /tmp/openssh_src/
mkdir -p /tmp/openssh_src/
tar xf "${SRC_DIR}/${openssh_package}" \
   -C /tmp/openssh_src/ \
   --strip-components 1
cd /tmp/openssh_src/ || exit 99
(
   autoconf
   ./configure --prefix="${PREFIX_DIR}" \
      --sysconfdir=/etc/ssh \
      --with-zlib \
      --with-ssl-dir=/usr/include/openssl \
      --with-ldflags=-static
      make -j "$(($(nproc) + 1))" &&
      make install
) 2>&1 | tee /tmp/compile_openssh.log
```

#### 4. Something To be Improved

1. sshd won't log to wtmp and btmp file
2. no pam intergration
3. no gssapi support
4. no kerbros support
