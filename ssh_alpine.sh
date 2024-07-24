#!/bin/ash

SRC_DIR="/tmp/src"
DEST_DIR=/opt/openssh_with_openssl_musl
openssl_package=openssl-3.0.14.tar.gz # https://github.com/openssl/openssl/releases/download/openssl-3.0.14/openssl-3.0.14.tar.gz
openssh_package=openssh-9.8p1.tar.gz  # https://cloudflare.cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-9.8p1.tar.gz
zlib_package=zlib-1.3.1.tar.gz        # https://zlib.net/zlib-1.3.1.tar.gz

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
        linux-pam-dev

compile_zlib() {
    rm -rf /tmp/zlib_src/
    mkdir -p /tmp/zlib_src
    tar xf "${SRC_DIR}/${zlib_package}" --strip-components 1 \
        -C /tmp/zlib_src/
    cd /tmp/zlib_src/ || exit 99
    ./configure --prefix="${DEST_DIR}" --static
    make -j "$(($(nproc) + 1))"
    make install
}

compile_openssl() {
    rm -rf /tmp/openssl_src/
    mkdir -p /tmp/openssl_src/
    tar xf "${SRC_DIR}/${openssl_package}" --strip-components 1 \
        -C /tmp/openssl_src/
    cd /tmp/openssl_src/ || exit 99
    ./config --prefix="${DEST_DIR}" \
        no-shared no-ssl3 no-weak-ssl-ciphers
    make depend
    make -j "$(($(nproc) + 1))"
    make install
}

compile_openssh() {
    rm -rf /tmp/openssh_src/
    mkdir -p /tmp/openssh_src/
    tar xf "${SRC_DIR}/${openssh_package}" --strip-components 1 \
        -C /tmp/openssh_src/
    cd /tmp/openssh_src/ || exit 99
    export CFLAGS="-static"
    export LDFLAGS="-static -L/${DEST_DIR}/lib64 -L/usr/lib -L/lib/security/ -L/${DEST_DIR}/lib  -L /lib -L${DEST_DIR}/lib/security"
    export CPPFLAGS="-I/${DEST_DIR}/include -I/usr/include/elogind/systemd/ -I/usr/include -I/usr/include/security/"
    export PKG_CONFIG_PATH=/usr/lib/pkgconfig/
    autoconf
    rm -f config.log
    ./configure --prefix=${DEST_DIR} \
        --sysconfdir=/etc/ssh \
        --with-ssl-dir=${DEST_DIR}/include/openssl \
        --with-zlib=${DEST_DIR} \
        --without-pam \
        --with-systemd \
        --enable-year2038 \
        --enable-utmp --enable-utmpx --enable-wtmp --enable-wtmpx --enable-lastlog
    # --with-pam=${DEST_DIR} --with-pam-service=sshd \
    make -j "$(($(nproc) + 1))"
    make install
}

# pam wtmp btmp
