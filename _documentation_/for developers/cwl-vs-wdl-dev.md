# CWL vs WDL: Algorithmic Differences
These differences are likely only of interest to maintainers of this repo or those seeking to fully understand the CWL --> WDL conversion process, besides basics of the WDL or removal of things related to the Seven Bridges API.  

## All Workflows 
**Javascript vs Python:** The CWL generates config files using an InlineJavascriptRequirement, which is run before the CWL equivivalent of a task's command section begins. The WDL generates them using an inline Python script during the beginning of a task's command section.  

**Imports:** The CWL appears to be set up such that there is a "main" CWL file for the overall workflow, which imports one additional CWL file per task. A WDL equivalent to this setup exists, but was not used for security reasons. The current recommended best practice is to avoid using imports in workflows except in checker workflows.

**Defaults:** The CWL has some entries listed as sbg:toolDefaultValue which are not considered defaults in the WDL. This is because sbg:toolDefaultValue is a UI tooltip that does not write anything. The default values are defaults with regard to the Rscript. For instance, if the user does not input a value for `null_model_r.norm_bygroup`, the WDL will not write `false` to the config file. Instead, it will not write it to the config file at all, and the Rscript will treat this as if the config said `false`

**The chromosome file workaround:** A few R scripts require chromosome numbers to be passed in on the command line rather than in the configuration file. In order to do this, chromosome number is written to a file (completely separate from the configuration file) in the task's inline Python section. Upon exiting the Python block, this extra file is read in BASH and then passed to the Rscript call as an argument (as opposed to being in the configuration file). Although the actual call to the R script is identical as the CWL also passes the chr number as an argument, the CWL is able to rely on its inline JavaScript to do this, while the WDL must use this workaround to pass the chr number out of the Python scope. As this only involves writing a tiny file that doesn't scale with inputs, it does not have cost implications.

## assoc-aggregate.wdl
This one has the most significant differences by far. Some tasks have their outputs changed to better comply with the strict output limitations of WDL, and subsequent tasks include processing to account for those changed outputs. As such the input and output of some tasks are not one-to-one of their CWL equivalent tasks.

### General
Some of the outputs in the CWL at first look like they are globbing .txt files, but they actually are using loadContents, which works like this: For each file matched in glob, read up to the first 64 KiB of text from the file  and place it in the contents field of the file object for manipulation by outputEval. So, the CWL's call for self[0].contents would be the first 64 KiB of the 0th file to match the .txt glob. That would be segments.txt in the prepare segments tasks. Therefore the WDL mimics this by just reading segments.txt

This pipeline features heavy usage of the twice localized workaround. Some steps in the CWL actually use the same or a similiar workaround.

### High-level overview
The CWL takes the following approach:
1. Prepartion tasks, which can run in parallel
  A. scatter(sbg_gds_renamer)
  B. define_segments
  C. scatter(aggregate_list)
2. sbg_prepare_segments_1
3. scatter(assoc_aggregate)
4. sbg_flatten_lists
5. sbg_group_segments
6. scatter(assoc_combine)
7. assoc_plots_r

The WDL takes the following approach:
1. **wdl_validate_inputs**
2. Prepartion tasks, which can run in parallel
  A. scatter(sbg_gds_renamer)
  B. define_segments
  C. scatter(aggregate_list)
3. sbg_prepare_segments_1
4. scatter(assoc_aggregate)
5. **wdl_process_assoc_files**
6. **scatter(sbg_group_segments)**
7. scatter(assoc_combine)
8. assoc_plots_r

sbg_flatten_lists is **not** used in the WDL due to major differences between how WDL and CWL handles arrays. It is replaced by wdl_process_assoc_files. Strictly speaking these two tasks have the same goal -- processing the output of the previous task so that it aligns with the requirements and limitations of a given workflow language -- but the nature of those limitations are quite different.

### sbg_prepare_segments_1
The CWL's output of sbg_prepare_segments_1 is three or four objects:
* An array of GDS files
* An array of integers representing segment number
* An array of aggregate RData files
* Optional: An array of variant include RData files

The CWL then dot-product scatters on these arrays, meaning that each instance of the next task gets:
* One GDS file
* One integer representing segment number
* One aggregate RData file
* Optional: One variant include RData file

It is theoretically possible to mimic this in a WDL that is compatible in Terra using custom structs, but I am not sure if it is possible to reliably scatter on such a thing. In any case, I found it to be less error-prone to simply set this task's output to a single array of zip files and to have the next task scatter on those zip files. Each zip file contains, and will pass into each instance of the subsequent scattered task:
* One GDS file
* One file with with the pattern X.integer where X is represents the segment number
* One aggregate RData file
* Optional: One variant include RData file, in its own subfolder in order to differentiate it from the other RData file

## ld-pruning.wdl
* WDL does not have an equivalent to ScatterMethod:DotProduct so it instead scatters using zip().
* check_merged_gds uses the chromosome file workaround.

## null-model.wdl
The CWL technically has duplicated outputs. The WDL instead returns each file once. On SB, cwl.output.json sets the outputs as the following, where ! indicates a duplicated output, inverse norm transformation is applied, and the output_prefix is set to `test`:
* configs:
  * null_model.config
  * ! null_model.config.null_model.params
* null_model_files:
  * ! test_null_model_invnorm.RData
  * test_null_model_invnorm_reportonly.RData
  * test_null_model_reportonly.RData
* null_model_output:
  * ! test_null_model_invnorm.RData
* null_model_params:
  * ! null_model.config.null_model.params
* null_model_phenotypes:
  * test_phenotypes.RData
Because everything in null_model_output is already covered by null_model_files, it does not exist as an output in the WDL.

## vcf-to-gds.wdl     
* The twice-localized workaround is used in unique_variant_ids due to permission errors on Terra. See [#2](https://github.com/DataBiosphere/analysis_pipeline_WDL/issues/2).
* The WDL will not start the check_gds task if check_gds is false. The CWL will start the check_gds task regardless and generate a config file, and the true/false only applies to calling the  script.
	* Reasoning: The way GCS billing works, this has the potential of being cheaper. Otherwise we would spend for having a powerful non-preemptible compute designed for an intense task, then only using that compute for making a text file.
* The WDL can correctly handle a mixture of file extensions, not so much by design, but due to the specifics of implementation. The CWL will handle such a mixture incorrectly in check_gds (but can correctly handle a homogenous group, such as all being bcf files).
* check_gds uses the chromosome file workaround.
