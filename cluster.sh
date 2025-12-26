#!/bin/bash

set -euo pipefail

# Set up working directory
echo "Setting up 'data/' directory..."
mkdir -p data
cd data

# Download input data files
echo "Downloading input genotype and sample metadata files..."
wget https://www.dropbox.com/s/j72j6uciq5zuzii/all_hg38.pgen.zst
wget https://www.dropbox.com/scl/fi/fn0bcm5oseyuawxfvkcpb/all_hg38_rs.pvar.zst?rlkey=przncwb78rhz4g4ukovocdxaz
wget https://www.dropbox.com/scl/fi/u5udzzaibgyvxzfnjcvjc/hg38_corrected.psam?rlkey=oecjnk4vmbhc8b1p202l0ih4x
wget https://www.dropbox.com/s/4zhmxpk5oclfplp/deg2_hg38.king.cutoff.out.id
wget -O samples.txt https://ftp.1000genomes.ebi.ac.uk/vol1/ftp/data_collections/1000G_2504_high_coverage/20130606_g1k_3202_samples_ped_population.txt

# Clean up and decompress downloaded files
echo "Renaming and decompressing downloaded files..."
mv all_hg38_rs.pvar.zst?rlkey=przncwb78rhz4g4ukovocdxaz all_hg38.pvar.zst
mv hg38_corrected.psam?rlkey=oecjnk4vmbhc8b1p202l0ih4x all_hg38.psam
plink2 --zst-decompress all_hg38.pvar.zst > all_hg38.pvar
plink2 --zst-decompress all_hg38.pgen.zst > all_hg38.pgen

# Remove related individuals from genotype data
echo "Removing related individuals from genotype dataset and filtering SNPs..."
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

# Filter by minor allele frequency (MAF)
echo "Filtering variants by MAF >= 0.01..."
plink2 --bfile global_before_qc \
  --maf 0.01 \
  --make-bed \
  --out global_qc_maf \
  --memory 12000 \
  --threads 6

# LD pruning
echo "LD pruning SNPs (window 50, step 10, r2 0.1)..."
plink2 --bfile global_qc_maf \
  --indep-pairwise 50 10 0.1 \
  --out global_ldprune \
  --memory 12000 \
  --threads 6

# Make the pruned dataset for ADMIXTURE
echo "Constructing LD-pruned dataset for ADMIXTURE..."
plink2 --bfile global_qc_maf \
  --extract global_ldprune.prune.in \
  --make-bed \
  --out global \
  --memory 12000 \
  --threads 6

# Clean up intermediate and temporary files
echo "Cleaning up intermediate and temporary files..."
rm -f \
  all_hg38.pgen.zst \
  all_hg38.pvar.zst \
  all_hg38.pgen \
  all_hg38.pvar \
  all_hg38.psam \
  deg2_hg38.king.cutoff.out.id

rm -f \
  global_before_qc* \
  global_qc_maf* \
  global_ldprune*

# Run ADMIXTURE
echo "Running ADMIXTURE (K=5, threads=6, seed=12345)..."
admixture -j6 --seed=12345 global.bed 5

# Remove ADMIXTURE input and log files
echo "Removing ADMIXTURE input and log files..."
rm -f \
  global.bed \
  global.log 

