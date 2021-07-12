# CWL vs WDL: A Comparison of Both Versions of these Programs
This document is intended for the following people:
* Those who have used the CWL versions of these programs who wish to know how the WDL version varies
* Those who seek to contribute to this repo
* Those who like to compare WDL and CWL for their own learning purposes

The typical user coming straight to this WDL from the Python versions, or who is new to these programs, will be unlikely to find anything useful.

# Significant CWL/WDL Differences
These are differences that have implications for cost or outputs.  

### All Workflows
The original CWLs allocate memory and CPUs on a workflow level, while the WDLs do it on a task level. In other words, the WDLs' runtime attributes are more granular. This was done because GCS has stricter requirements than AWS regarding storage. Doing it this way also allows resource-heavy tasks (such as check_gds in vcf-to-gds-wf) to only use the large number of resources they need in their respective task, instead of the whole workflow.  

### ld-pruning-wf.wdl
* The CWL appears to contain a bug where `exclude_PCA_cor` being set to false is not respected ([#14](https://github.com/DataBiosphere/analysis_pipeline_WDL/issues/14)). The WDL avoids this. 
* The output of merge_gds across the CWL and WDL do not md5 to the same value, but should be functionally equivalent. See [#22](https://github.com/DataBiosphere/analysis_pipeline_WDL/issues/22) for more information.   

### null-model-wf.wdl
The CWL includes a function which is designed to have an output phenotype file inherit metadata from the required input phenotype file. It is specific to the Seven Bridges platform and therefore has not been included in the WDL. We have tested the workflow extensively and have not found a situation where the phenotype output file from the WDL varies from what the phenotype output from the CWL is; ie, in spite of this deletion the two outputs md5 across workflows.

Be aware that the original CWL gives different output for null_model_file depending on whether the Seven Bridges backend selected at workspace creation time is AWS (default) or Google. To clarify:

|                    	| WDL, local 	| WDL, Terra 	| CWL, 7B via AWS 	| CWL, 7B via Google 	|
|--------------------	|------------	|------------	|-----------------	|--------------------	|
| WDL, local         	| pass       	| pass       	| fail            	| pass               	|
| WDL, Terra         	| pass       	| pass       	| fail            	| pass               	|
| CWL, 7B via AWS    	| fail       	| fail       	| pass            	| fail               	|
| CWL, 7B via Google 	| pass       	| pass       	| fail            	| pass               	|

----------

# Algorithmic CWL/WDL Differences
These differences are likely only of interest to maintainers of this repo or those seeking to fully understand the CWL-->WDL conversion process.  

### All Workflows 
#### Strictly Necessary Changes  
* **The double input workaround:** Due to [#2](https://github.com/DataBiosphere/analysis_pipeline_WDL/issues/2), some WDL tasks require up to twice as much disk space as their CWL equivalent tasks would require. This is accounted for in disk size calculations, so this should not cause users to error out, but it has minor cost implications. 
* Filenames are generated by calling the Seven Bridges API in the CWL. This isn't possible in WDL, so inputs are generated from JSONs instead.  
* The original CWL does not have an option for disk space, but the WDL does, as it is a soft requirement for running on Terra.  
* The CWL generates config files using an InlineJavascriptRequirement, which is run before the CWL equivivalent of a task's command section begins. The WDL generates them using an inline Python script during the beginning of a task's command section.  
* A few R scripts require chromosome numbers to be passed in on the command line rather than in the configuration file. In order to do this, chromosome number is written to a file (completely separate from the configuration file) in the task's inline Python section. Upon exiting the Python block, this extra file is read in BASH and then passed to the Rscript call as an argument (as opposed to being in the configuration file). Although the actual call to the R script is identical as the CWL also passes the chr number as an argument, the CWL is able to rely on its inline Javascript to do this, while the WDL must use this workaround to pass the chr number out of the Python scope.

#### Miscellanous Differences
* The CWL imports other CWLs. The WDL does not import other WDLs, except in the case of the checker workflow.  
	* Reasoning: It is possible for WDLs to contain just tasks and be imported into another task, but in some contexts it can be slightly less secure.

### null-model-wf.wdl
#### Strictly Necessary Changes
* The file relocalization trick is used to support the odd method of passing parameters into the second task.  

### ld-pruning-wf.wdl
#### Strictly Necessary Changes
* Similiar to vcf-to-gds' file relocalization trick in unique_variant_ids, this workflow's merge_gds task has to use the same workaround.
* WDL does not have an equivalent to ScatterMethod:DotProduct so it instead scatters using zip().
* The workaround used by vcf-to-gds' check_gds to get chromosome number (see above) is also used by check_merged_gds for the same reason.  

### vcf-to-gds-wf.wdl     
#### Miscellanous Differences
* The WDL will not start the check_gds task if check_gds is false. The CWL will start the check_gds task regardless and generate a config file, and the true/false only applies to calling the  script.
	* Reasoning: The way GCS billing works, this has the potential of being cheaper. Otherwise we would spend for having a powerful non-preemptible compute designed for an intense task, then only using that compute for making a text file.
* The WDL can correctly handle a mixture of file extensions, not so much by design, but due to the specifics of implementation. The CWL will handle such a mixture incorrectly in check_gds (but can correctly handle a homogenous group, such as all being bcf files).