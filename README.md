# Ancestry Cluster Pipeline

This repository provides a Dockerized pipeline for running an ADMIXTURE-based ancestry clustering analysis on high-coverage 1000 Genomes Project data (hg38). It processes genotype data, filters SNPs, performs LD pruning, and runs ADMIXTURE with K=5 populations to generate ancestry proportion files (`.P` and `.Q`).

## Key Files
- `cluster.sh`: The main Bash script that downloads data, processes it with PLINK2, and runs ADMIXTURE.
- `high_quality_snps.txt`: A list of high-quality SNPs for filtering.
- `Dockerfile`: Builds the container image with dependencies (Ubuntu, PLINK2, ADMIXTURE).

The pre-built image is available on GitHub Container Registry (GHCR) for easy use.

## Prerequisites
- Docker installed on your system.
- Stable internet connection (downloads ~6GB+ of genetic data).
- Sufficient disk space (~10GB+ for data and outputs).

## Quick Start
1. Pull the image:
   ```
   docker pull ghcr.io/brobdingrag/ancestry-cluster:latest
   ```

2. Run the pipeline (outputs will appear in a `./data` folder in your current directory):
   ```
   docker run --rm -it -v "$PWD:/work" ghcr.io/brobdingrag/ancestry-cluster:latest
   ```

   - This will download and process data, then output `global.5.P` and `global.5.Q` in `./data`.
   - The process may take 30-60 minutes depending on your hardware and network.

## Building Locally (Optional)
If you want to customize or rebuild the image:
1. Clone the repo:
   ```
   git clone https://github.com/brobdingrag/ancestry-cluster.git
   cd ancestry-cluster
   ```

2. Build the image:
   ```
   docker build -t ghcr.io/brobdingrag/ancestry-cluster:latest .
   ```

   - For non-AVX2 systems (e.g., older CPUs or ARM-based like Apple Silicon), use:
     ```
     docker build --build-arg PLINK2_ZIP_URL="https://s3.amazonaws.com/plink2-assets/plink2_linux_x86_64_20251205.zip" -t ghcr.io/brobdingrag/ancestry-cluster:latest .
     ```

3. Run as above.

## Outputs
- `global.5.P`: Population allele frequencies.
- `global.5.Q`: Individual ancestry proportions.
- Other intermediates are cleaned up, but you can modify `cluster.sh` to keep them if needed.

## Troubleshooting
- **AVX2 Error**: If PLINK2 complains about missing AVX2 instructions, rebuild with the non-AVX2 arg as shown above.
- **Download Issues**: Ensure Dropbox URLs in `cluster.sh` work; add `?dl=1` to ends if wget fetches HTML instead of files (e.g., `https://www.dropbox.com/s/j72j6uciq5zuzii/all_hg38.pgen.zst?dl=1`).
- **Permissions**: Outputs are owned by UID 1000; use `chown` on host if needed.
- **Large Data**: Be patient with downloads; retry if network fails.
- For errors, check container logs or run with `--entrypoint /bin/bash` for interactive debugging.


## Contact
For issues or suggestions, open a GitHub issue in this repo.

