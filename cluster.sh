#!/bin/bash

# =========================
# Set up working directory
# =========================

set -euo pipefail

mkdir -p data  # Create data directory if it does not exist
cd data        # Navigate into data directory

# =========================
# Download input data files
# =========================

# Genotype data in .pgen (compressed) format
wget https://www.dropbox.com/s/j72j6uciq5zuzii/all_hg38.pgen.zst

# Variant information in .pvar (compressed) format
wget https://www.dropbox.com/scl/fi/fn0bcm5oseyuawxfvkcpb/all_hg38_rs.pvar.zst?rlkey=przncwb78rhz4g4ukovocdxaz

# Sample information file (.psam)
wget https://www.dropbox.com/scl/fi/u5udzzaibgyvxzfnjcvjc/hg38_corrected.psam?rlkey=oecjnk4vmbhc8b1p202l0ih4x

# List of sample IDs to remove (e.g., relateds from KING)
wget https://www.dropbox.com/s/4zhmxpk5oclfplp/deg2_hg38.king.cutoff.out.id

# 1000 Genomes project sample metadata (population info)
wget -O samples.txt https://ftp.1000genomes.ebi.ac.uk/vol1/ftp/data_collections/1000G_2504_high_coverage/20130606_g1k_3202_samples_ped_population.txt

# =====================================
# Clean up and decompress downloaded files
# =====================================

# Rename .pvar and .psam files to remove query string from Dropbox shared links
mv all_hg38_rs.pvar.zst?rlkey=przncwb78rhz4g4ukovocdxaz all_hg38.pvar.zst
mv hg38_corrected.psam?rlkey=oecjnk4vmbhc8b1p202l0ih4x all_hg38.psam

# Decompress pvar and pgen files using plink2
plink2 --zst-decompress all_hg38.pvar.zst > all_hg38.pvar
plink2 --zst-decompress all_hg38.pgen.zst > all_hg38.pgen

# ========================================
# Remove related individuals from genotype data
# ========================================

plink2 --pfile all_hg38 vzs \
  --remove deg2_hg38.king.cutoff.out.id \
  --chr 1-22 \
  --max-alleles 2 \
  --extract /opt/high_quality_snps.txt \
  --set-missing-var-ids '@_#_$1_$2' \
  --make-bed \
  --out global_before_qc \
  --allow-extra-chr \
  --memory 20000 \
  --threads 6


# ========================================
# Create new PLINK binary fileset using:
#   --maf 0.01   => remove rare variants (MAF < 1%)
# ========================================

plink2 --bfile global_before_qc \
  --maf 0.01 \
  --make-bed \
  --out global_qc_maf \
  --memory 12000 \
  --threads 6

# ========================================
# 2) LD prune (ADMIXTURE manual-style)
#    Window = 50 SNPs, step = 10 SNPs, r^2 threshold = 0.1
# ========================================

plink2 --bfile global_qc_maf \
  --indep-pairwise 50 10 0.1 \
  --out global_ldprune \
  --memory 12000 \
  --threads 6

# ========================================
# Make the pruned dataset for ADMIXTURE
# ========================================

plink2 --bfile global_qc_maf \
  --extract global_ldprune.prune.in \
  --make-bed \
  --out global \
  --memory 12000 \
  --threads 6

# ========================================
# Clean up intermediate and temporary files
# ========================================

# Remove raw downloads + decompressed inputs
rm -f \
  all_hg38.pgen.zst \
  all_hg38.pvar.zst \
  all_hg38.pgen \
  all_hg38.pvar \
  all_hg38.psam \
  deg2_hg38.king.cutoff.out.id

# Remove intermediate PLINK outputs
rm -f \
  global_before_qc* \
  global_qc_maf* \
  global_ldprune*


# ========================================
# Run ADMIXTURE with 5 clusters and 6 threads
# ========================================

admixture -j6 --seed=12345 global.bed 5


# Remove ADMIXTURE inputs 
rm -f \
  global.bed \
  global.log 


