
# =========================
# Set up working directory
# =========================

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
       --make-pgen \
       --out all_hg38_unrelated \
       --allow-extra-chr \
       --memory 12000 \
       --threads 4

# ========================================
# Filter, deduplicate, and convert genotype data to BED files
# ========================================

plink2 --pfile all_hg38_unrelated \
       --chr 1-22 \
       --max-alleles 2 \
       --rm-dup exclude-mismatch \
       --set-missing-var-ids '@_#_$1_$2' \
       --make-bed \
       --out autosomes \
       --allow-extra-chr \
       --memory 12000 \
       --threads 4

# ========================================
# Clean up intermediate and temporary files
# ========================================

rm all_hg38.pgen.zst
rm all_hg38.pgen
rm all_hg38.pvar.zst
rm all_hg38.pvar
rm all_hg38.psam
rm deg2_hg38.king.cutoff.out.id
rm all_hg38_unrelated.psam
rm all_hg38_unrelated.pvar
rm all_hg38_unrelated.pgen
rm all_hg38_unrelated.log
rm autosomes.log

# ========================================
# Build a SampleID list from the autosomes.fam file
# ========================================

awk '{ print $1, $2 }' autosomes.fam > unrelated_keep.txt

# ========================================
# Create new PLINK binary fileset using:
#   - --keep sample list
#   - --extract high-quality SNP list (one rsID per line)
# ========================================

plink2 --bfile autosomes \
       --keep unrelated_keep.txt \
       --extract /opt/high_quality_snps.txt \
       --make-bed \
       --out global_before_qc \
       --memory 12000 \
       --threads 4

# ========================================
# Create new PLINK binary fileset using:
#   --maf 0.01   => remove rare variants (MAF < 1%)
# ========================================

plink2 --bfile global_before_qc \
  --maf 0.01 \
  --make-bed \
  --out global_qc_maf \
  --memory 12000 \
  --threads 4

# ========================================
# 2) LD prune (ADMIXTURE manual-style)
#    Window = 50 SNPs, step = 10 SNPs, r^2 threshold = 0.1
# ========================================

plink2 --bfile global_qc_maf \
  --indep-pairwise 50 10 0.1 \
  --out global_ldprune \
  --memory 12000 \
  --threads 4

# ========================================
# Make the pruned dataset for ADMIXTURE
# ========================================

plink2 --bfile global_qc_maf \
  --extract global_ldprune.prune.in \
  --make-bed \
  --out global \
  --memory 12000 \
  --threads 4

# ========================================
# Clean up intermediate and temporary files
# ========================================

rm -rf autosomes*
rm -rf global_before_qc*
rm -rf global_qc_maf*
rm -rf non_amr_non_sas_no_fin_no_acb_asw_ids*
rm -rf global_ldprune*
rm global.log

# ========================================
# Run ADMIXTURE with 5 clusters and 4 threads
# ========================================

admixture -j4 --seed=12345 global.bed 5

rm global.bed  # No longer needed


