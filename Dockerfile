# ====================================================================================
# FreeSWITCH Golden Master Image - Full Build on Debian 12 (Bookworm)
# Author: hl
# Date: 2025-10-28
# ====================================================================================

# ------------------------------------------------------------------------------------
# STAGE 1: The "Factory" - Compiling everything from source on Debian Bookworm
# ------------------------------------------------------------------------------------

FROM debian:bookworm-slim AS builder

RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources

ENV DEBIAN_FRONTEND=noninteractive

COPY packages.txt /tmp/packages.txt
RUN apt-get update && \
    xargs -a /tmp/packages.txt apt-get install -y --no-install-recommends && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ARG FS_PREFIX=/opt/freeswitch
WORKDIR /usr/src

COPY swig-4.0.2 /usr/src/swig-4.0.2
WORKDIR /usr/src/swig-4.0.2
RUN ./autogen.sh && ./configure && make -j $(nproc) && make install
WORKDIR /usr/src

COPY libks /usr/src/libks
WORKDIR /usr/src/libks
RUN cmake -DCMAKE_INSTALL_PREFIX=${FS_PREFIX} . && make -j $(nproc) && make install
WORKDIR /usr/src

COPY sofia-sip /usr/src/sofia-sip
WORKDIR /usr/src/sofia-sip
RUN ./bootstrap.sh && \
    ./configure --prefix=${FS_PREFIX} && \
    make -j $(nproc) && make install
WORKDIR /usr/src

COPY spandsp /usr/src/spandsp
WORKDIR /usr/src/spandsp
RUN ./bootstrap.sh && \
   ./configure --prefix=${FS_PREFIX} && \
    make -j $(nproc) && make install
WORKDIR /usr/src

ENV PKG_CONFIG_PATH="${FS_PREFIX}/lib/pkgconfig"

COPY freeswitch-src /usr/src/freeswitch-src
WORKDIR /usr/src/freeswitch-src

RUN ./bootstrap.sh

RUN echo "languages/mod_lua" >> modules.conf
RUN sed -i '/mod_signalwire/s/^/#/' modules.conf
RUN sed -i '/mod_av/s/^/#/' modules.conf
RUN sed -i '/mod_spandsp/s/^/#/' modules.conf

RUN ./configure --prefix=${FS_PREFIX} \
                --enable-core-pgsql-support

RUN make -j $(nproc) && make install 
# && make sounds-install && make moh-install
WORKDIR /usr/src

COPY mod_audio_stream /usr/src/mod_audio_stream
WORKDIR /usr/src/mod_audio_stream/build
RUN cmake -DCMAKE_BUILD_TYPE=Release .. && \
    make && make install

# ====================================================================================
# STAGE 2: The "Final Product" - A clean, minimal Bookworm runtime image
# ====================================================================================

FROM debian:bookworm-slim

RUN groupadd -r freeswitch --gid=999 && useradd -r -g freeswitch --uid=999 freeswitch

RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    libuuid1 libpcre3 libsqlite3-0 zlib1g libedit2 libcurl4 libssl3 \
    libevent-core-2.1-7 libevent-pthreads-2.1-7 libpq5 libopus0 \
    libspeex1 libspeexdsp1 libsndfile1 libtiff6 libjpeg62-turbo \
    libldns3 liblua5.2-0 libpng16-16 procps wget \
    libavformat59 libswscale6 libavcodec59 libavutil57 libswresample4 \
    ca-certificates gosu \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ARG FS_PREFIX=/opt/freeswitch

COPY --from=builder ${FS_PREFIX} ${FS_PREFIX}

RUN cp -r ${FS_PREFIX}/etc/freeswitch ${FS_PREFIX}/default_freeswitch_conf

COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

EXPOSE 8021/tcp
EXPOSE 5060/tcp 5060/udp 5080/tcp 5080/udp
EXPOSE 5061/tcp 5061/udp 5081/tcp 5081/udp
EXPOSE 7443/tcp
EXPOSE 5070/udp 5070/tcp
EXPOSE 64535-65535/udp
EXPOSE 16384-32768/udp

ENTRYPOINT ["/docker-entrypoint.sh"]
