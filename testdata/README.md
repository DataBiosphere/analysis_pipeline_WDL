# UWGAC Notes
The data in this directory are from the 1000 Genomes project:
http://www.internationalgenome.org/

This is a small subset of the data available here:
http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502/

The variants are in genome build hg19.

Test data for king.wdl is about 149.9 Mb and available as ALL.pruned.gds here: https://console.cloud.google.com/storage/browser/_details/topmed_workflow_testing/UWGAC_WDL/ALL.pruned.gds
# WDL Fork Notes
chrX varies from what is currently (as of April 9th 2021) is on the UWGAC repo. This repo's chrX is filtered as some of the lines on the original repo's chrX are invalid and will error out. See https://github.com/UW-GAC/analysis_pipeline/issues/46

In addition to the vcf.gz files stored here, the following additional test files are also included for testing alternative file types.
* 1KG_phase3_subset_chr1.bcf
* 1KG_phase3_subset_chr1.vcf
* 1KG_phase3_subset_chr2.vcf
* 1KG_phase3_subset_chr2.vcf.bgz
* 1KG_phase3_subset_chr3.vcf.bgz
* 1KG_phase3_subset_chrX.vcf
* unfiltered1KG_phase3_subset_chrX.vcf.gz -- the original chrX in the UWGAC repo
* unfiltered1KG_phase3_subset_chrX.vcf -- the original chrX in the UWGAC repo, unzipped
