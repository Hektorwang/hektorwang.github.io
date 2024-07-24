#!/bin/bash
set -e

SRC_DIR="/tmp/src"
DEST_DIR=/opt/openssh_with_openssl_musl
# Prepare source packages in SRC_DIR
musl_package=musl-1.2.5.tar.gz        # https://musl.libc.org/releases/musl-1.2.5.tar.gz
openssl_package=openssl-3.0.14.tar.gz # https://github.com/openssl/openssl/releases/download/openssl-3.0.14/openssl-3.0.14.tar.gz
openssh_package=openssh-9.8p1.tar.gz  # https://cloudflare.cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-9.8p1.tar.gz
zlib_package=zlib-1.3.1.tar.gz        # https://zlib.net/zlib-1.3.1.tar.gz
pam_package=Linux-PAM-1.6.1.tar.xz    # https://github.com/linux-pam/linux-pam/releases

dnf install -y \
    autoconf \
    gcc \
    make \
    patch \
    perl \
    perl-IPC-Cmd

dnf install -y --installroot="${DEST_DIR}"/os --releasever=9 \
    kernel-headers \
    zlib-devel \
    pam-devel \
    systemd-devel

mkdir -p "${DEST_DIR}"/

function compile_musl {
    rm -rf /tmp/musl_src/
    mkdir -p /tmp/musl_src
    tar xf "${SRC_DIR}/${musl_package}" --strip-components 1 \
        -C /tmp/musl_src/
    cd /tmp/musl_src/ || exit 99
    ./configure --prefix="${DEST_DIR}"
    make -j "$(($(nproc) + 1))"
    make install
}

function compile_zlib {
    rm -rf /tmp/zlib_src/
    mkdir -p /tmp/zlib_src
    tar xf "${SRC_DIR}/${zlib_package}" --strip-components 1 \
        -C /tmp/zlib_src/
    cd /tmp/zlib_src/ || exit 99
    ./configure --prefix="${DEST_DIR}"
    make -j "$(($(nproc) + 1))"
    make install
}

function compile_pam {
    rm -rf /tmp/pam_src/
    mkdir -p /tmp/pam_src
    tar xf "${SRC_DIR}/${pam_package}" --strip-components 1 \
        -C /tmp/pam_src/
    cd /tmp/pam_src/ || exit 99
    ./configure --prefix="${DEST_DIR}" --sysconfdir=/etc --enable-openssl
    make -j "$(($(nproc) + 1))"
    make install
}

function compile_openssl {
    rm -rf /tmp/openssl_src/
    mkdir -p /tmp/openssl_src/
    tar xf "${SRC_DIR}/${openssl_package}" --strip-components 1 \
        -C /tmp/openssl_src/
    cd /tmp/openssl_src/ || exit 99
    ./config --prefix="${DEST_DIR}" \
        zlib --with-zlib-include="${DEST_DIR}"/include \
        -Wl,-rpath,"${DEST_DIR}"/lib \
        no-ssl no-tls1 no-tls1_1 no-ssl3-method no-tls1-method no-tls1_1-method \
        no-sm2 no-sm3 no-sm4 no-des no-dsa \
        no-weak-ssl-ciphers \
        no-deprecated no-legacy
    make depend
    make -j "$(($(nproc) + 1))"
    make install
}

function compile_openssh {
    rm -rf /tmp/openssh_src/
    mkdir -p /tmp/openssh_src/
    tar xf "${SRC_DIR}/${openssh_package}" --strip-components 1 \
        -C /tmp/openssh_src/
    cd /tmp/openssh_src/ || exit 99
    # export CFLAGS="-static"
    autoconf
    ./configure --prefix=${DEST_DIR} \
        --sysconfdir=/etc/ssh \
        --with-ssl-dir=${DEST_DIR}/include/openssl/ \
        --with-pam --with-pam-service=sshd \
        --without-zlib
    # --with-zlib=${DEST_DIR} \
    # --with-ssl-dir=${DEST_DIR}/include/openssl \
    #  --enable-utmp --enable-utmpx --enable-wtmp --enable-wtmpx --enable-lastlog
    # --with-pam=${DEST_DIR} --with-pam-service=sshd \
    make -j "$(($(nproc) + 1))"
    make install
}

compile_musl 2>&1 | tee "${DEST_DIR}/compile_musl.log"

export CC="${DEST_DIR}"/bin/musl-gcc
export LDFLAGS="-L${DEST_DIR}/lib64 -L${DEST_DIR}/lib -L${DEST_DIR}/os/lib64 -L${DEST_DIR}/os/lib"
export CPPFLAGS="-I${DEST_DIR}/include -I${DEST_DIR}/os/usr/include"
export PKG_CONFIG_PATH="${DEST_DIR}"/lib64/pkgconfig:"${DEST_DIR}"/lib/pkgconfig

compile_zlib 2>&1 | tee "${DEST_DIR}/compile_zlib.log"
compile_openssl 2>&1 | tee "${DEST_DIR}/compile_openssl.log"
compile_openssh 2>&1 | tee "${DEST_DIR}/compile_openssh.log"
