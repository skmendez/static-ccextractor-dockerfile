FROM alpine:3.9 as ccextractor

RUN mkdir -p -m a+rwx /tmp/cc

WORKDIR /tmp/cc

RUN echo 'http://dl-cdn.alpinelinux.org/alpine/v3.5/main' >| /etc/apk/repositories
RUN echo 'http://dl-cdn.alpinelinux.org/alpine/v3.5/community' >> /etc/apk/repositories
RUN apk update
RUN apk upgrade
RUN apk add --update bash zsh alpine-sdk perl

# (needed by various static builds below)
RUN apk add autoconf automake libtool

# Now comes the not-so-fun parts...  Many packages _only_ provide .so files in their distros -- not the .a
# needed files for building something with it statically.  Step through them now...


# libgif
RUN wget --no-check-certificate https://sourceforge.net/projects/giflib/files/giflib-5.1.4.tar.gz \
 && zcat giflib*tar.gz | tar xf - \
 && ( \
        cd giflib*/ \
        && ./configure --disable-shared --enable-static && make && make install \
    ) \
 && hash -r


# libwebp
RUN git clone https://github.com/webmproject/libwebp \
 && ( \
        cd libwebp \
        && ./autogen.sh \
        && ./configure --disable-shared --enable-static && make && make install \
    )


# ccextractor -- build static
RUN git clone https://github.com/CCExtractor/ccextractor \
 && ( \
        cd ccextractor/linux/ \
        && ./autogen.sh \
        && ./configure \
        && perl -i -pe 's/O3 /O3 -static /' Makefile \
        && perl -i -pe 's/(strchr|strstr)\(/$1((char *)/'  ../src/gpacmp4/url.c  ../src/gpacmp4/error.c \
        && set +e \
        && make ENABLE_OCR=no \
        && set -e \
        && gcc -Wno-write-strings -D_FILE_OFFSET_BITS=64 -DVERSION_FILE_PRESENT -O3 -std=gnu99 -s -DGPAC_CONFIG_LINUX -DENABLE_OCR -DPNG_NO_CONFIG_H -I/usr/local/include/tesseract -I/usr/local/include/leptonica $(find ../src -name '*.o') -o ccextractor \
            --static -lm \
            /usr/local/lib/libgif.a \
            /usr/local/lib/libwebp.a \
            /usr/lib/libgomp.a \
            -lstdc++ \
    )

RUN mv ccextractor/linux/ccextractor /
