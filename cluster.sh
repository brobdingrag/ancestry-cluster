#!/bin/bash

set -euo pipefail

# Create and enter the 'data/' directory for all intermediate and output files
mkdir -p data
cd data

# Download input genotype files
wget https://www.dropbox.com/s/j72j6uciq5zuzii/all_hg38.pgen.zst
wget https://www.dropbox.com/scl/fi/fn0bcm5oseyuawxfvkcpb/all_hg38_rs.pvar.zst?rlkey=przncwb78rhz4g4ukovocdxaz
wget https://www.dropbox.com/scl/fi/u5udzzaibgyvxzfnjcvjc/hg38_corrected.psam?rlkey=oecjnk4vmbhc8b1p202l0ih4x
wget https://www.dropbox.com/s/4zhmxpk5oclfplp/deg2_hg38.king.cutoff.out.id

# Rename files as needed and decompress genotype files
mv all_hg38_rs.pvar.zst?rlkey=przncwb78rhz4g4ukovocdxaz all_hg38.pvar.zst
mv hg38_corrected.psam?rlkey=oecjnk4vmbhc8b1p202l0ih4x all_hg38.psam
plink2 --zst-decompress all_hg38.pvar.zst > all_hg38.pvar
plink2 --zst-decompress all_hg38.pgen.zst > all_hg38.pgen

# Remove related individuals and extract high-quality autosomal biallelic SNPs
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

# Filter variants to keep only those with MAF >= 0.01
plink2 --bfile global_before_qc \
  --maf 0.01 \
  --make-bed \
  --out global_qc_maf \
  --memory 12000 \
  --threads 6

# Perform linkage disequilibrium (LD) pruning
plink2 --bfile global_qc_maf \
  --indep-pairwise 50 10 0.1 \
  --out global_ldprune \
  --memory 12000 \
  --threads 6

# Create the final LD-pruned dataset as input for ADMIXTURE
plink2 --bfile global_qc_maf \
  --extract global_ldprune.prune.in \
  --make-bed \
  --out global \
  --memory 12000 \
  --threads 6

# Remove intermediate and temporary files to save space
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

# Run ADMIXTURE with K=5 populations (threads=6, random seed=12345)
admixture -j6 --seed=12345 global.bed 5

# Remove the bed file after completion
rm global.bed

# Download the population labels AFTER the (unsupervised) clustering is complete
wget -O samples.txt https://ftp.1000genomes.ebi.ac.uk/vol1/ftp/data_collections/1000G_2504_high_coverage/20130606_g1k_3202_samples_ped_population.txt
wget -O populations.tsv https://ftp.1000genomes.ebi.ac.uk/vol1/ftp/phase3/20131219.populations.tsv
wget -O superpopulations.tsv https://ftp.1000genomes.ebi.ac.uk/vol1/ftp/phase3/20131219.superpopulations.tsv

cd ..

python analyze_clusters.py


