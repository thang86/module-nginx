# Use an official build image with necessary tools
FROM ubuntu:22.04 AS builder

# Set up environment variables
ENV OPENSSL_VERSION=3.4.0
ENV NGINX_VERSION=1.27.2

# Install dependencies and build tools in a single layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    wget \
    curl \
    git \
    libpcre3-dev \
    zlib1g-dev \
    pkg-config \
    cmake \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Download and compile OpenSSL
RUN wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz && \
    tar -xzf openssl-${OPENSSL_VERSION}.tar.gz && \
    cd openssl-${OPENSSL_VERSION} && \
    ./config --prefix=/usr/local/openssl --openssldir=/usr/local/openssl && \
    make && make install && \
    cd .. && rm -rf openssl-${OPENSSL_VERSION}*

# Download and extract Nginx
RUN wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
    tar -xzf nginx-${NGINX_VERSION}.tar.gz && \
    rm nginx-${NGINX_VERSION}.tar.gz

# Clone ngx_aws_auth module
RUN git clone -b AuthV2 https://github.com/anomalizer/ngx_aws_auth.git /ngx_aws_auth

# Build Nginx with the module
WORKDIR /nginx-${NGINX_VERSION}
RUN ./configure \
    --prefix=/usr/local/nginx \
    --add-dynamic-module=/ngx_aws_auth \
    --with-http_ssl_module \
    --with-openssl=/usr/local/openssl && \
    make && make install

# Final image
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y --no-install-recommends libpcre3 zlib1g openssl && apt-get clean && rm -rf /var/lib/apt/lists/*
COPY --from=builder /usr/local/nginx/modules/ngx_http_aws_auth_module.so /etc/nginx/modules/ngx_http_aws_auth_module.so