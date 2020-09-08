#################### DEVELOPMENT ####################
FROM alpine:latest as builder

# CONFIGURE SERVER
ENV SERVER_HOME="/mcpe" \
    SERVER_PATH="/mcpe/server" \
    SCRIPT_PATH="/mcpe/script" \
    DEFAULT_CONFIG_PATH="/mcpe/default-config" \
    DATA_PATH="/data" \
    BDS="/root/.bds"

RUN mkdir -p $SERVER_PATH && \
    mkdir -p $DATA_PATH/configs && \
    mkdir -p $DEFAULT_CONFIG_PATH

COPY ./configs $DEFAULT_CONFIG_PATH

RUN cp -R $DEFAULT_CONFIG_PATH $DATA_PATH/configs

COPY ./script $SCRIPT_PATH

#################### PRODUCTION ####################
FROM ubuntu:latest as production

# ARCH is only set to avoid repetition in Dockerfile since the binary download only supports amd64
ARG ARCH=amd64

# CONFIGURE TIMEZONE TO UTC
ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# INSTALL PACKAGES
RUN apt update && \
    DEBIAN_FRONTEND=noninteractive \
    apt install -y --no-install-recommends \
    curl \
    libcurl4 \
    nodejs \
    npm \
    tar \
    unzip \
    wine && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*

# INSTALL NPM PACKAGES
RUN npm install -g \
    dateformat \
    fs    

# CONFIGURE SERVER
ENV SERVER_HOME="/mcpe" \
    SERVER_PATH="/mcpe/server" \
    SCRIPT_PATH="/mcpe/script" \
    DEFAULT_CONFIG_PATH="/mcpe/default-config" \
    DATA_PATH="/data" \
    BDS="/root/.bds"

VOLUME [$DATA_PATH]

WORKDIR $SERVER_PATH

COPY --from=builder $SERVER_HOME $SERVER_HOME

ARG EASY_ADD_VERSION=0.7.0
ADD https://github.com/itzg/easy-add/releases/download/${EASY_ADD_VERSION}/easy-add_linux_${ARCH} /usr/local/bin/easy-add
RUN chmod +x /usr/local/bin/easy-add

RUN easy-add --var version=0.2.1 --var app=entrypoint-demoter --file {{.app}} --from https://github.com/itzg/{{.app}}/releases/download/{{.version}}/{{.app}}_{{.version}}_linux_${ARCH}.tar.gz

RUN easy-add --var version=0.1.1 --var app=set-property --file {{.app}} --from https://github.com/itzg/{{.app}}/releases/download/{{.version}}/{{.app}}_{{.version}}_linux_${ARCH}.tar.gz

RUN easy-add --var version=1.2.0 --var app=restify --file {{.app}} --from https://github.com/itzg/{{.app}}/releases/download/{{.version}}/{{.app}}_{{.version}}_linux_${ARCH}.tar.gz

RUN easy-add --var version=0.5.0 --var app=mc-monitor --file {{.app}} --from https://github.com/itzg/{{.app}}/releases/download/{{.version}}/{{.app}}_{{.version}}_linux_${ARCH}.tar.gz

RUN easy-add --var version=1.3.35 --var app=bdsx --file {{.app}} --from https://github.com/karikera/{{.app}}/releases/download/{{.version}}/{{.app}}-{{.version}}-linux.tar.gz --to $SERVER_PATH

WORKDIR $SERVER_PATH

EXPOSE  19132/udp \
        19133/udp \
        56772/udp \
        57863/udp 

EXPOSE  19132/tcp \
        19133/tcp \
        56772/tcp \
        57863/udp 

#ENTRYPOINT ["/bdsx/script/docker-entrypoint.sh"]
ENTRYPOINT ["/usr/local/bin/entrypoint-demoter", "--match", "/data", "--debug", "--stdin-on-term", "stop", "$SCRIPT_PATH/docker-entrypoint.sh"]

ENV VERSION=LATEST \
    SERVER_PORT=19132

HEALTHCHECK --start-period=1m CMD /usr/local/bin/mc-monitor status-bedrock --host 0.0.0.0 --port $SERVER_PORT

CMD ["./bdsx.sh"]