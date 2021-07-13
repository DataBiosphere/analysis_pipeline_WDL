# CWL vs WDL: A Comparison of Both Versions of these Programs
This document is intended for the following people:
* Those who have used the CWL versions of these programs who wish to know how the WDL version varies
* Those who seek to contribute to this repo
* Those who like to compare WDL and CWL for their own learning purposes

The [Algorithmic Differences](https://github.com/DataBiosphere/analysis_pipeline_WDL/blob/implement-null-model/_documentation_/cwl-vs-wdl.md#algorithmic-differences) section is only useful to the last two. Users of the CWL coming to the WDL are likely only interested in the [Significant Differences](https://github.com/DataBiosphere/analysis_pipeline_WDL/blob/implement-null-model/_documentation_/cwl-vs-wdl.md#significant-differences) section, as it contains everything which may have cost and output implications.

The typical user coming straight to this WDL from the Python versions, or who is entirely new to these programs, will be unlikely to find anything useful in this document.  

# Significant Differences
These are differences that have implications for cost or outputs.  

## All Workflows
The original CWLs allocate memory and CPUs on a workflow level, while the WDLs do it on a task level. In other words, the WDLs' runtime attributes are more granular. This was done because GCS has stricter requirements than AWS regarding storage. Doing it this way also allows resource-heavy tasks (such as check_gds in vcf-to-gds-wf) to only use the large number of resources they need in their respective task, instead of the whole workflow.

In line with workflow inputs: The original CWL does not have an option for disk space, but the WDL does, as it is a soft requirement for running on Terra. If not defined by the user, it will fall back on an estimate. Should that estimate prove inappropriate, the user will need to override it on a task level.

##### *The twice-localized workaround*
Due to a workaround involving file inputs, some WDL tasks require up to twice as much disk space as their CWL equivalent tasks would require. Exactly which files must be duplicated depends on the workflow. Be aware that sometimes the size of the files that need to be duplicated will scale with the size of your inputs. Cost-related implications for users are discussed for each workflow below; algorithmic explainations beyond what the typical user needs to know can be found in the [Algorithmic Differences](https://github.com/DataBiosphere/analysis_pipeline_WDL/blob/implement-null-model/_documentation_/cwl-vs-wdl.md#algorithmic-differences) section.

## ld-pruning-wf.wdl
* The twice-localized workaround duplicates a series of intermediate files (specifically in the merge_gds task). **The size of these intermediate files scale with the size of your input GDS files.** However, they have already been pruned by a previous task, so you can assume they will be smaller than you input files.
* The CWL appears to contain a bug where `exclude_PCA_cor` being set to false is not respected ([#14](https://github.com/DataBiosphere/analysis_pipeline_WDL/issues/14)). The WDL avoids this. 
* The output of merge_gds across the CWL and WDL do not md5 to the same value, but should be functionally equivalent. See [#22](https://github.com/DataBiosphere/analysis_pipeline_WDL/issues/22) for more information.   

## null-model-wf.wdl
The majority of input files are affected by the twice-localized workaround in both tasks. As such, we recommend allocating about double the amount of disk space as the size of your inputs.

The CWL includes a function which is designed to have an output phenotype file inherit metadata from the required input phenotype file. It is specific to the Seven Bridges platform and therefore has not been included in the WDL. We have tested the workflow extensively and have not found a situation where the phenotype output file from the WDL varies from what the phenotype output from the CWL is; ie, in spite of this deletion the two outputs md5 across workflows.

Be aware that the original CWL gives different output for null_model_file depending on whether the Seven Bridges backend selected at workspace creation time is AWS (default) or Google. To clarify:

|                    	| WDL, local 	| WDL, Terra 	| CWL, 7B via AWS 	| CWL, 7B via Google 	|
|--------------------	|------------	|------------	|-----------------	|--------------------	|
| WDL, local         	| pass       	| pass       	| fail            	| pass               	|
| WDL, Terra         	| pass       	| pass       	| fail            	| pass               	|
| CWL, 7B via AWS    	| fail       	| fail       	| pass            	| fail               	|
| CWL, 7B via Google 	| pass       	| pass       	| fail            	| pass               	|


## vcf-to-gds-wf.wdl   
* The twice-localized workaround duplicates a series of intermediate files (specifically in the unique_variant_ids task). **The size of these intermediate files scale with the size of your input VCFs.** However, they are GDS files, which are more heavily compressed than VCFs, so you can assume they will be smaller than you input files.

----------

# Algorithmic Differences
These differences are likely only of interest to maintainers of this repo or those seeking to fully understand the CWL --> WDL conversion process, besides basics of the WDL or removal of things related to the Seven Bridges API.  

## All Workflows 
The CWL generates config files using an InlineJavascriptRequirement, which is run before the CWL equivivalent of a task's command section begins. The WDL generates them using an inline Python script during the beginning of a task's command section.  

The CWL is set up such that there is a "main" CWL file for the overall workflow, which imports one additional CWL file per task. A WDL equivalent to this setup exists, but was not used for security reasons. The current recommended best practice is to avoid using imports in workflows except in checker workflows.

##### *The chromosome file workaround*
A few R scripts require chromosome numbers to be passed in on the command line rather than in the configuration file. In order to do this, chromosome number is written to a file (completely separate from the configuration file) in the task's inline Python section. Upon exiting the Python block, this extra file is read in BASH and then passed to the Rscript call as an argument (as opposed to being in the configuration file). Although the actual call to the R script is identical as the CWL also passes the chr number as an argument, the CWL is able to rely on its inline Javascript to do this, while the WDL must use this workaround to pass the chr number out of the Python scope. As this only involves writing a tiny file that doesn't scale with inputs, it does not have cost implications.

## null-model-wf.wdl
The twice-localized workaround is used for a slightly different reason that it is in other workflows. The null model workflow generates a parameters file in its first task, which must use a general path, because the next tasks that same parameters file to generate its own output. If it used absolute paths, the path would point to the first task's inputs directory, which is not available in the second task. This is because, when running on Terra, each task is running inside of a Docker container. (The local version of Cromwell technically does not need Docker, but for Terra it is a hard requirement.) Files that are not explictly passed in or out of that container cannot be accessed by other tasks. In other words, in the WDL context, each task has its own file system. Additionally, the input directory's name is not consistent across tasks even if they are based upon the same Docker image, nor can it be predicted before runtime. Therefore, we must use relative paths in the params file, and we additionally must duplicate files from the input directory to the working directory for these relative paths to function with the R scripts.

## ld-pruning-wf.wdl
* The twice-localized workaround is used for the same reason as it is in unique_variant_ids; it is taking in an input array of files from more than one input directory.
* WDL does not have an equivalent to ScatterMethod:DotProduct so it instead scatters using zip().
* check_merged_gds uses the chromosome file workaround.

### vcf-to-gds-wf.wdl     
* The twice-localized workaround is used in unique_variant_ids due to the fact the R script requires an array of GDS files and uses a config file which can only support an array of GDS files if each GDS file is in the same parent directory. As the GDS files are generated from a scattered task, they are sometimes given unique input directories on some file systems. As such, they first need to be pulled from all of their input directories and placed in the working directory before the config file is generated. This is explained more in-depth as the example case for [#2](https://github.com/DataBiosphere/analysis_pipeline_WDL/issues/2).
* The WDL will not start the check_gds task if check_gds is false. The CWL will start the check_gds task regardless and generate a config file, and the true/false only applies to calling the  script.
	* Reasoning: The way GCS billing works, this has the potential of being cheaper. Otherwise we would spend for having a powerful non-preemptible compute designed for an intense task, then only using that compute for making a text file.
* The WDL can correctly handle a mixture of file extensions, not so much by design, but due to the specifics of implementation. The CWL will handle such a mixture incorrectly in check_gds (but can correctly handle a homogenous group, such as all being bcf files).
* check_gds uses the chromosome file workaround.
