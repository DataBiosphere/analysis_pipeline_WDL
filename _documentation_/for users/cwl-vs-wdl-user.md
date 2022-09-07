# CWL vs WDL: Significant Differences
This document is intended for the following users of the CWL versions of these programs who wish to know how the WDL version varies. It is focused on differences that may change outputs or require different inputs. The typical user coming straight to this WDL from the Python versions, or who is entirely new to these programs, will be unlikely to find anything useful in this document. Developers may also wish to read about more the [algorithmic differences](https://github.com/DataBiosphere/analysis_pipeline_WDL/tree/main/_documentation_/for%20developers/cwl-vs-wdl-dev.md).  

## All Workflows -- different runtime attributes (memory, cores, etc)
The original CWLs allocate memory and CPUs on a workflow level, while the WDLs do it on a task level. In other words, the WDLs' runtime attributes are more granular. This was done because GCS has stricter requirements than AWS regarding storage. Doing it this way also allows resource-heavy tasks (such as check_gds in vcf-to-gds-wf) to only use the large number of resources they need in their respective task, instead of the whole workflow.

The original CWL pipelines had arguments relating to runtime such as `ncores` and `cluster_type` that do not apply to WDL. Please familiarize yourself with the [runtime attributes of WDL](https://cromwell.readthedocs.io/en/stable/RuntimeAttributes/) if you are unsure how your settings may transfer. 

The original CWL does not have an option for disk space, but the WDL does, as an estimation of disk size is a soft requirement for running on Terra. If not defined by the user, each task will fall back on an estimate based on the size of the input files. Should that estimate prove inappropriate, the user can supplement the estimate using the `addldisk` argument, which adds gigabytes of storage (not memory!) on top of the estimate.

## ld-pruning.wdl
* The CWL appears to contain a bug where `exclude_PCA_cor` being set to false is not respected ([#14](https://github.com/DataBiosphere/analysis_pipeline_WDL/issues/14)). The WDL avoids this. 
* The output of merge_gds across the CWL and WDL do not md5 to the same value, but should be functionally equivalent. See [#22](https://github.com/DataBiosphere/analysis_pipeline_WDL/issues/22) for more information. 
* Due to [how](https://github.com/zhengxwen/SeqArray/blob/828cbb5d06d85581119aaf9ab854e1d2497c65c5/R/UtilsMerge.R#L282) [SeqArray](https://github.com/zhengxwen/SeqArray/blob/828cbb5d06d85581119aaf9ab854e1d2497c65c5/R/UtilsMerge.R#L299) [works](https://github.com/zhengxwen/SeqArray/blob/828cbb5d06d85581119aaf9ab854e1d2497c65c5/R/UtilsMerge.R#L358), the CWL pipeline will (likely incorrectly) claim that you have repeating variants IDs and/or repeating sample IDs. The WDL pipeline avoids this issue by skipping the merge and check merge steps if you have only one GDS file input.

## null-model.wdl
The CWL includes a function which is designed to have an output phenotype file inherit metadata from the required input phenotype file. It is specific to the Seven Bridges platform and therefore has not been included in the WDL. We have tested the workflow extensively and have not found a situation where the phenotype output file from the WDL varies from what the phenotype output from the CWL is; ie, in spite of this deletion the two outputs md5 across workflows.

Be aware that the original CWL gives significantly different output for null_model_file depending on whether the Seven Bridges backend selected at workspace creation time is AWS (default) or Google [(#3 on CWL)](https://github.com/UW-GAC/analysis_pipeline_cwl/issues/3). This naturally carries over when comparing the output of the original CWL on an AWS backend to the output of this WDL on a non-AWS backend. Rather than relying on an md5sum, we define "significantly different output" to mean the outputs in question do not pass when the R function `all.equal()` is run at default values. By these criteria:

|                    	| WDL, local 	| WDL, Terra 	| CWL, 7B via AWS 	| CWL, 7B via Google 	|
|--------------------	|------------	|------------	|-----------------	|--------------------	|
| WDL, local         	| pass       	| pass       	| fail            	| pass               	|
| WDL, Terra         	| pass       	| pass       	| fail            	| pass               	|
| CWL, 7B via AWS    	| fail       	| fail       	| pass            	| fail               	|
| CWL, 7B via Google 	| pass       	| pass       	| fail            	| pass               	|


## vcf-to-gds.wdl   
The twice-localized workaround duplicates a series of intermediate files (specifically in the unique_variant_ids task). **The size of these intermediate files scale with the size of your input VCFs.** However, they are GDS files, which are more heavily compressed than VCFs, so you can assume they will be smaller than your input files.
