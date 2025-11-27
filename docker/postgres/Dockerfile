FROM ghcr.io/kayjay-madman/postgres-combo:latest

USER root

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    curl \
    pkg-config \
    libssl-dev \
    postgresql-server-dev-16 \
    postgresql-16-cron \
    ca-certificates \
    gnupg \
    lsb-release \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Add TimescaleDB repository
RUN echo "deb https://packagecloud.io/timescale/timescaledb/debian/ $(lsb_release -c -s) main" | tee /etc/apt/sources.list.d/timescaledb.list
RUN wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | apt-key add -

# Install TimescaleDB and PostGIS
RUN apt-get update && apt-get install -y --no-install-recommends \
    timescaledb-2-postgresql-16 \
    postgresql-16-postgis-3 \
    && rm -rf /var/lib/apt/lists/*

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Install cargo-pgrx
# pg_graphql requires 0.16.1
RUN cargo install --locked cargo-pgrx --version 0.16.1
RUN cargo pgrx init --pg16 /usr/lib/postgresql/16/bin/pg_config

# Install pg_graphql
RUN cd /tmp && \
    git clone https://github.com/supabase/pg_graphql.git && \
    cd pg_graphql && \
    cargo pgrx install --release --features pg16 --no-default-features && \
    cd .. && rm -rf pg_graphql

# Install pgmq
RUN cd /tmp && \
    git clone https://github.com/tembo-io/pgmq.git && \
    cd pgmq/pgmq-extension && \
    make && \
    make install && \
    cd ../.. && rm -rf pgmq

# Install libsodium dependencies
RUN apt-get update && apt-get install -y --no-install-recommends libsodium-dev

# Install pgsodium
RUN cd /tmp && \
    git clone https://github.com/michelp/pgsodium.git && \
    cd pgsodium && \
    make && \
    make install && \
    cd .. && rm -rf pgsodium

# Install supabase/vault
RUN cd /tmp && \
    git clone https://github.com/supabase/vault.git && \
    cd vault && \
    make && \
    make install && \
    cd .. && rm -rf vault

# Install hypopg
RUN cd /tmp && \
    git clone https://github.com/HypoPG/hypopg.git && \
    cd hypopg && \
    make && \
    make install && \
    cd .. && rm -rf hypopg

# Install index_advisor
RUN cd /tmp && \
    git clone https://github.com/supabase/index_advisor.git && \
    cd index_advisor && \
    make install && \
    cd .. && rm -rf index_advisor

# Create pgsodium key script
RUN echo "#!/bin/sh" > /usr/share/postgresql/16/extension/pgsodium_getkey && \
    echo "echo 0000000000000000000000000000000000000000000000000000000000000000" >> /usr/share/postgresql/16/extension/pgsodium_getkey && \
    chmod +x /usr/share/postgresql/16/extension/pgsodium_getkey

# Cleanup build dependencies to keep image small
RUN apt-get purge -y --auto-remove \
    build-essential \
    git \
    curl \
    pkg-config \
    libssl-dev \
    postgresql-server-dev-16 \
    && rm -rf /root/.cargo

USER postgres
