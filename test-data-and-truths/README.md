# Test Data
From UWGAC:
> The data in this directory are from [the 1000 Genomes project](http://www.internationalgenome.org/). This is a small subset of the data available [here](http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502/). The variants are in genome build hg19.  

The lineage of these files is as follows:

the chr1-chr22+chrX vcf.gz files in `vcfs/`  
              ↓  
the chr1-chr22 gds files in `gds/a_vcf2gds` †  
              ↓  
the merged gds file in `gds/b_ldpruning`  

† chrX is among the files in `gds/a_vcf2gds`, but it is not among the files used to generate the file in `gds/b_ldpruning` due to [#8](https://github.com/DataBiosphere/analysis_pipeline_WDL/issues/8).

Unless otherwise noted, all files here were generated with default settings for the pipeline. 

## gds/
GDS files included in the gds/ folder are NOT mirrors of the files included in the original UWGAC repo. They were instead created using an up-to-date version of the pipeline.

### gds/a_vcf2gds
GDS files created as the output of the unique_variant_IDs task. They were instead created using the current (v1.0.1) WDL version of this pipeline, which runs in uwgac/topmed-master:2.10.0.

### gds/b_ldpruning
The merged GDS file as the output of the merge_gds task, which also underwent LD pruning on the default settings.

## vcfs/
These are the same vcf.gz files as can be found in the UWGAC, with the exception of chrX. This repo's chrX is filtered as some of the lines on the original repo's chrX are invalid and will error out. See https://github.com/UW-GAC/analysis_pipeline/issues/46.

### vcfs/alternative_vcfs/
In addition to the vcf.gz files stored in `vcfs/`, the following additional test files are also included for testing alternative file types.
* 1KG_phase3_subset_chr1.bcf
* 1KG_phase3_subset_chr1.vcf
* 1KG_phase3_subset_chr2.vcf
* 1KG_phase3_subset_chr2.vcf.bgz
* 1KG_phase3_subset_chr3.vcf.bgz
* 1KG_phase3_subset_chrX.vcf
* unfiltered1KG_phase3_subset_chrX.vcf.gz -- the original chrX in the UWGAC repo
* unfiltered1KG_phase3_subset_chrX.vcf -- the original chrX in the UWGAC repo, unzipped