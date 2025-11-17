#!/bin/bash
set -e

echo "Installing Apache AGE..."

# Install AGE via package manager (if available) or compile from source
apt-get update && apt-get install -y \
    wget \
    gnupg \
    build-essential \
    git \
    cmake \
    postgresql-server-dev-all \
    libboost-graph-dev \
    libboost-system-dev \
    libboost-regex-dev \
    libboost-program-options-dev \
    libssl-dev

# Install Apache AGE from pre-built packages if available
if wget -q --spider http://packages.age.org/apt/age/gpgkey 2>/dev/null; then
    echo "Installing AGE from packages..."
    wget -O - http://packages.age.org/apt/age/gpgkey | apt-key add -
    echo "deb http://packages.age.org/apt/age/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/age.list
    apt-get update
    apt-get install -y postgresql-15-age
else
    echo "Compiling AGE from source..."
    cd /tmp
    git clone --branch v1.5.0 https://github.com/apache/age.git
    cd age
    mkdir build && cd build
    cmake ..
    make install
    ldconfig
fi

echo "Apache AGE installation completed"