#!/bin/bash

SRC_DIR="/tmp/src"
DEST_DIR="/home/tsc/opt"
# https://www.openssl.org/source/openssl-3.0.14.tar.gz
# openssl_package=openssl-3.0.14.tar.gz
# https://www.openssl.org/source/openssl-3.3.1.tar.gz
openssl_package=openssl-3.3.1.tar.gz
openssl_dir="${DEST_DIR}"/openssl

# https://cloudflare.cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-9.8p1.tar.gz
openssh_package=openssh-9.8p1.tar.gz
openssh_dir="${DEST_DIR}"/openssh

# https://zlib.net/zlib-1.3.1.tar.gz
zlib_package=zlib-1.3.1.tar.gz
zlib_dir="${DEST_DIR}"/zlib

# https://curl.se/download/curl-8.8.0.tar.gz
curl_package=curl-8.8.0.tar.gz
curl_dir="${DEST_DIR}"/curl

# https://musl.libc.org/releases/musl-1.2.5.tar.gz
musl_packages=musl-1.2.5.tar.gz
musl_dir="${DEST_DIR}"/musl

yum install -y \
    autoconf \
    gcc \
    make \
    patch \
    perl \
    perl-IPC-Cmd

unset CPPFLAGS LDFLAGS PKG_CONFIG_PATH CC

install_kernel-headers() {
    yum install -y --installroot="${DEST_DIR}" --releasever=7 \
        kernel-headers
    rm -rf "${DEST_DIR:?}"/{home,var}
    export CPPFLAGS="-I${DEST_DIR}/usr/include"
}

compile_musl() {
    rm -rf /tmp/musl_src/
    mkdir -p /tmp/musl_src
    tar xf "${SRC_DIR}/${musl_packages}" \
        -C /tmp/musl_src/ \
        --strip-components 1
    cd /tmp/musl_src/ || exit 99
    (
        ./configure --prefix="${musl_dir}" \
            -fPIC &&
            # --disable-shared
            make -j "$(($(nproc) + 1))" &&
            make install
    ) 2>&1 | tee /tmp/compile_musl.log
    export LDFLAGS="-L${musl_dir}/lib64 -L${musl_dir}/lib"
    export CPPFLAGS+=" -I${musl_dir}/include"
    export PKG_CONFIG_PATH="${musl_dir}/lib64/pkgconfig:${musl_dir}/lib/pkgconfig"
    export CC="${musl_dir}/bin/musl-gcc"
}

compile_zlib() {
    rm -rf /tmp/zlib_src/
    mkdir -p /tmp/zlib_src
    tar xf "${SRC_DIR}/${zlib_package}" \
        -C /tmp/zlib_src/ \
        --strip-components 1
    cd /tmp/zlib_src/ || exit 99
    (
        # --static
        ./configure --prefix="${zlib_dir}" &&
            make -j "$(($(nproc) + 1))" &&
            make install
    ) 2>&1 | tee /tmp/compile_zlib.log
    export LDFLAGS+=" -L${zlib_dir}/lib64 -L${zlib_dir}/lib -L${DEST_DIR}/lib"
    export CPPFLAGS+=" -I${zlib_dir}/include"
    export PKG_CONFIG_PATH+=":${zlib_dir}/lib/pkgconfig:${zlib_dir}/lib64/pkgconfig"
}

compile_openssl() {
    rm -rf /tmp/openssl_src/
    mkdir -p /tmp/openssl_src/
    tar xf "${SRC_DIR}/${openssl_package}" \
        -C /tmp/openssl_src/ \
        --strip-components 1
    cd /tmp/openssl_src/ || exit 99
    (
        ./config --prefix="${openssl_dir}" \
            no-sm2 no-sm3 no-sm4 \
            no-weak-ssl-ciphers no-deprecated no-legacy \
            zlib --with-zlib-include="${zlib_dir}"/include \
            shared -fPIC \
            -Wl,-rpath=${musl_dir}/lib/ \
            -Wl,-rpath=${zlib_dir}/lib/ \
            -Wl,-rpath=${openssl_dir}/lib64 &&
            make depend &&
            make -j "$(($(nproc) + 1))" &&
            make install_sw
    ) 2>&1 | tee /tmp/compile_openssl.log
    export LDFLAGS+=" -L${openssl_dir}/lib64 -L${openssl_dir}/lib -Wl,-rpath=${musl_dir}/lib -Wl,-rpath=${zlib_dir}/lib -Wl,-rpath=${openssl_dir}/lib64 "
    export CPPFLAGS+=" -I${openssl_dir}/include"
    export PKG_CONFIG_PATH+=":${openssl_dir}/lib/pkgconfig:${openssl_dir}/lib64/pkgconfig"
}

compile_curl() {
    rm -rf /tmp/curl_src/
    mkdir -p /tmp/curl_src/
    tar xf "${SRC_DIR}/${curl_package}" \
        -C /tmp/curl_src/ \
        --strip-components 1
    cd /tmp/curl_src/ || exit 99
    (
        # /etc/ssl/certs/ca-bundle.crt
        ./configure --prefix=${curl_dir} \
            --disable-libcurl-option \
            --disable-ldap \
            --disable-ldaps \
            --disable-rtsp \
            --disable-docs \
            --disable-ntlm \
            --with-ca-bundle=/etc/pki/tls/certs/ca-bundle.crt \
            --with-ca-path=/etc/pki/tls/certs/ \
            --with-ssl=${openssl_dir} \
            --with-zlib=${zlib_dir} \
            --disable-shared --enable-static &&
            make -j "$(($(nproc) + 1))" &&
            make install
    ) 2>&1 | tee /tmp/compile_curl.log
}

compile_openssh() {
    rm -rf /tmp/openssh_src/
    mkdir -p /tmp/openssh_src/
    tar xf "${SRC_DIR}/${openssh_package}" \
        -C /tmp/openssh_src/ \
        --strip-components 1
    cd /tmp/openssh_src/ || exit 99
    (
        # --with-pam --with-pam-service=sshd \
        # autoconf &&
        # LIBS="-lcrypto -ldl -lutil -lz -lcrypt -lresolv -lsystemd"
        CFLAGS+=" -Wall -Wextra" \
            ./configure --prefix=${openssh_dir} \
            --sysconfdir=/etc/ssh \
            --with-ssl-engine --with-ssl-dir=${openssl_dir}/include/openssl \
            --with-zlib=${zlib_dir} \
            --without-pam \
            --without-xauth \
            --without-bsd-auth \
            --with-lastlog=/var/log/lastlog \
            --with-audit=debug &&
            make -j "$(($(nproc) + 1))" &&
            make install
    ) 2>&1 | tee /tmp/compile_openssh.log
}

# pam wtmp btmp
