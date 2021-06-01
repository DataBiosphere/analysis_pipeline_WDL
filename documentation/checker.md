# Checker workflows
These scripts run pipelines on a known set of inputs, and validates them against expected outputs with a quick md5sum check. On Terra, both inputs and outputs are pulled from the UCSC-owned topmed_workflow_testing bucket. In all cases the expected inputs are provided in JSON files.

These workflows are not simply a copy of the check_gds/check_merged_gds steps found in vcf-to-gds and ld-pruning respectively. Instead, they perform a separate validation check using md5 sums.

Due to Cromwell limitations, workflows do not always execute in the order that tasks are written in a WDL file. Similarly, scattered tasks tend to execute their components in a somewhat random order; something like shard-6 --> shard-10 --> shard-20 --> shard-1 is possible even if you have your job concurrency set to 1. For this reason, your pipeline may error out later than you would expect. **Be prepared for the pipeline to run its full course even if you are expecting an error in one of the first md5sum checks!**

## vcf-to-gds-checker.wdl
Because the test inputs are known to not take very long in check_gds, this step is enabled *by default.* If you are replacing these files with your own sets of inputs and outputs, and that set is non-downsampled, modern TOPMed data, you may wish to consider skipping this step.

If relying on the truth files located in topmed_workflow_testing, make sure to run this on the full array of input VCF (vcf-to-gds-checker). If you do not run this on the full array of provided files, the resulting outputs will have unexpected variant IDs (vcf-to-gds), resulting in an md5sum mismatch. That does not mean the files are invalid, it just means their IDs are not exactly the same as they would be if you had generated them all together.

ChrX is not in the pipeline's JSON to prevent errors should the output of this pipeline be piped directly into ld-pruning-checker. However, an input file and truth file are found in the same buckets as the other input and truth buckets for chrX, so running on chrX is still possible.

## ld-pruning-checker.wdl
**Estimated cost on Terra: $1.39**  
Due to how variables in the original pipeline are accessed, ld-pruning is hardcoded to fail on non-autosomes. The provided test data is only autosomes.

This workflow checks ld-pruning twice, one with default inputs, and one with a variety of non-default inputs.

There appears to be a difference in how an Rscript running the CWL on SB versus the WDL on other platforms will order numbers. The output merged GDS file of the CWL on SB will order variants by chromosome in alphabetical order (`1 10 11 12 13 14 15 16 17 18 19 2 20...`) while the WDL running both locally and on Terra orders them numerically (`1 2 3 4 5 6 7 8 9 10 11...`). For this reason truth files for the merged output were generated on Terra using the WDL, unlike most of the other truth files for these checker pipelines. If you are running on another platform, though, there is a chance that your numbers will be ordered alphabetically. In that case it is best to check against `seven_bridges_merged_truth.gds` which is located in the same bucket as the other truth files for ld-pruning-checker. Please see #22 for more information.

