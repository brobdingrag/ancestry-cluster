# Use Ubuntu 22.04 as the base image
FROM ubuntu:22.04

# Set environment to non-interactive to avoid prompts during apt-get
ENV DEBIAN_FRONTEND=noninteractive

# Set the working directory inside the container
WORKDIR /work

# Install system dependencies required for the script and binaries
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      wget \
      unzip \
      tar \
      coreutils \
      gawk \
      grep \
      sed \
      findutils \
      libgomp1 \
      libstdc++6 && \
    rm -rf /var/lib/apt/lists/*

# Install PLINK2 (default to latest AVX2 Intel build; override with --build-arg if needed)
ARG PLINK2_ZIP_URL="https://s3.amazonaws.com/plink2-assets/plink2_linux_avx2_20251205.zip"
RUN wget -O /tmp/plink2.zip "${PLINK2_ZIP_URL}" && \
    mkdir -p /tmp/plink2dir && \
    unzip /tmp/plink2.zip -d /tmp/plink2dir && \
    mv /tmp/plink2dir/plink2 /usr/local/bin/plink2 && \
    chmod +x /usr/local/bin/plink2 && \
    rm -rf /tmp/plink2.zip /tmp/plink2dir

# Install ADMIXTURE
ARG ADMIXTURE_TGZ_URL="https://dalexander.github.io/admixture/binaries/admixture_linux-1.3.0.tar.gz"
RUN wget -O /tmp/admixture.tar.gz "${ADMIXTURE_TGZ_URL}" && \
    mkdir -p /tmp/admixture && \
    tar -xzf /tmp/admixture.tar.gz -C /tmp/admixture && \
    mv /tmp/admixture/dist/admixture_linux-1.3.0/admixture /usr/local/bin/admixture && \
    chmod +x /usr/local/bin/admixture && \
    rm -rf /tmp/admixture /tmp/admixture.tar.gz

# Download pipeline files from GitHub raw URLs to locations that won't be overwritten by volume mounts
RUN wget -O /opt/high_quality_snps.txt "https://raw.githubusercontent.com/brobdingrag/ancestry-cluster/main/high_quality_snps.txt"
RUN wget -O /usr/local/bin/cluster.sh "https://raw.githubusercontent.com/brobdingrag/ancestry-cluster/main/cluster.sh" && \
    chmod +x /usr/local/bin/cluster.sh

# Create a non-root user for security (UID 1000)
RUN useradd -m -u 1000 runner && \
    chown -R runner:runner /work

# Switch to non-root user
USER runner

# Set the entrypoint to run the script and display outputs 
ENTRYPOINT ["/bin/bash", "-lc", "set -euo pipefail; /usr/local/bin/cluster.sh; echo; echo 'Outputs:'; ls -lh /work/data/global.5.Q /work/data/global.5.P; echo; echo 'Done. Results are in /work/data'"]
