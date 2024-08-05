#!/bin/ash

SRC_DIR="/tmp/src"

# https://www.openssl.org/source/openssl-3.0.14.tar.gz
# openssl_package=openssl-3.0.14.tar.gz
# https://www.openssl.org/source/openssl-3.3.1.tar.gz
openssl_package=openssl-3.3.1.tar.gz
openssl_dir=/opt/openssl

# https://cloudflare.cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-9.8p1.tar.gz
openssh_package=openssh-9.8p1.tar.gz
openssh_dir=/opt/openssh

# https://zlib.net/zlib-1.3.1.tar.gz
zlib_package=zlib-1.3.1.tar.gz
zlib_dir=/opt/zlib

# https://curl.se/download/curl-8.8.0.tar.gz
curl_package=curl-8.8.0.tar.gz
curl_dir=/opt/curl

# https://musl.libc.org/releases/musl-1.2.5.tar.gz
musl_packages=musl-1.2.5.tar.gz
musl_dir=/opt/musl

sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories
apk update && apk upgrade &&
    apk add \
        autoconf \
        bash \
        curl \
        linux-headers \
        ncurses-dev \
        perl \
        build-base \
        elogind-dev \
        ca-certificates ca-certificates-bundle

compile_musl() {
    rm -rf /tmp/musl_src/
    mkdir -p /tmp/musl_src
    tar xf "${SRC_DIR}/${musl_packages}" \
        -C /tmp/musl_src/ \
        --strip-components 1
    cd /tmp/musl_src/ || exit 99
    (
        ./configure --prefix="${musl_dir}" \
            --disable-shared -fPIC
        make -j "$(($(nproc) + 1))"
        make install
    ) 2>&1 | tee /tmp/compile_musl.log
    export LDFLAGS="-L${musl_dir}/lib64 -L${musl_dir}/lib"
    export CPPFLAGS="-I${musl_dir}/include"
    export PKG_CONFIG_PATH="${musl_dir}/lib64/pkgconfig:${musl_dir}/lib/pkgconfig"
}

compile_zlib() {
    rm -rf /tmp/zlib_src/
    mkdir -p /tmp/zlib_src
    tar xf "${SRC_DIR}/${zlib_package}" \
        -C /tmp/zlib_src/ \
        --strip-components 1
    cd /tmp/zlib_src/ || exit 99
    (
        ./configure --prefix="${zlib_dir}" --static
        make -j "$(($(nproc) + 1))"
        make install
    ) 2>&1 | tee /tmp/compile_zlib.log
    export LDFLAGS="${LDFLAGS} -L${zlib_dir}/lib64 -L${zlib_dir}/lib"
    export CPPFLAGS="${CPPFLAGS} -I${zlib_dir}/include"
    export PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:${zlib_dir}/lib/pkgconfig:${zlib_dir}/lib64/pkgconfig"
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
            zlib --with-zlib-include="${zlib_dir}"/include \
            no-sm2 no-sm3 no-sm4 \
            no-weak-ssl-ciphers \
            no-deprecated no-legacy \
            no-shared -fPIC
        make depend
        make -j "$(($(nproc) + 1))"
        make install_sw
    ) 2>&1 | tee /tmp/compile_openssl.log
    export LDFLAGS="${LDFLAGS} -L${openssl_dir}/lib64 -L${openssl_dir}/lib"
    export CPPFLAGS="${CPPFLAGS} -I${openssl_dir}/include"
    export PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:${openssl_dir}/lib/pkgconfig:${openssl_dir}/lib64/pkgconfig"
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
            --disable-shared --enable-static
        make -j "$(($(nproc) + 1))"
        make install
    ) 2>&1 | tee /tmp/compile_curl.log
}

compile_openssh() {
    rm -rf /tmp/openssh_src/
    mkdir -p /tmp/openssh_src/
    tar xf "${SRC_DIR}/${openssh_package}" --strip-components 1 \
        -C /tmp/openssh_src/
    cd /tmp/openssh_src/ || exit 99
    export CFLAGS="-static"
    export LDFLAGS="-static -L/${PREFIX_DIR}/lib64 -L/usr/lib -L/lib/security/ -L/${PREFIX_DIR}/lib  -L /lib -L${PREFIX_DIR}/lib/security"
    export CPPFLAGS="-I/${PREFIX_DIR}/include -I/usr/include/elogind/systemd/ -I/usr/include -I/usr/include/security/"
    export PKG_CONFIG_PATH=/usr/lib/pkgconfig/
    autoconf
    ./configure --prefix=${PREFIX_DIR} \
        --sysconfdir=/etc/ssh \
        --with-ssl-dir=${PREFIX_DIR}/include/openssl \
        --with-zlib=${PREFIX_DIR} \
        --without-pam \
        --with-systemd \
        --enable-year2038 \
        --enable-utmp --enable-utmpx --enable-wtmp --enable-wtmpx --enable-lastlog
    # --with-pam=${PREFIX_DIR} --with-pam-service=sshd \
    make -j "$(($(nproc) + 1))"
    make install
}

# pam wtmp btmp
