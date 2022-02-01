# CWL vs WDL: Algorithmic Differences
These differences are likely only of interest to maintainers of this repo or those seeking to fully understand the CWL --> WDL conversion process, besides basics of the WDL or removal of things related to the Seven Bridges API.  

* [All Workflows](#all-workflows)
* [assoc-aggregate.wdl](#assoc-aggregatewdl)
* [ld-pruning.wdl](#ld-pruningwdl)
* [null-model.wdl](#null-modelwdl)
* [pcrelate.wdl](#pcrelatewdl)
* [vcf-to-gds.wdl](#vcf-to-gdswdl)

## All Workflows 
**JavaScript vs Python:** The CWL generates config files using an InlineJavascriptRequirement, which is run before the CWL equivalent of a task's command section begins. The WDL generates them using an inline Python script during the beginning of a task's command section.  

**Imports:** The CWL appears to be set up such that there is a "main" CWL file for the overall workflow, which imports one additional CWL file per task. A WDL equivalent to this setup exists, but was not used for security reasons. The current recommended best practice is to avoid using imports in workflows except in checker workflows.

**Defaults:** The CWL has some entries listed as sbg:toolDefaultValue which are not considered defaults in the WDL. This is because sbg:toolDefaultValue is a UI tooltip that does not write anything. The default values are defaults with regard to the Rscript. For instance, if the user does not input a value for `null_model_r.norm_bygroup`, the WDL will not write `false` to the config file. Instead, it will not write it to the config file at all, and the Rscript will treat this as if the config said `false`

**The chromosome file workaround:** A few R scripts require chromosome numbers to be passed in on the command line rather than in the configuration file. In order to do this, chromosome number is written to a file (completely separate from the configuration file) in the task's inline Python section. Upon exiting the Python block, this extra file is read in BASH and then passed to the Rscript call as an argument (as opposed to being in the configuration file). Although the actual call to the R script is identical as the CWL also passes the chr number as an argument, the CWL is able to rely on its inline JavaScript to do this, while the WDL must use this workaround to pass the chr number out of the Python scope. As this only involves writing a tiny file that doesn't scale with inputs, it does not have cost implications.

## assoc-aggregate.wdl
This one has the most significant differences by far. Some tasks have their outputs changed to better comply with the strict output limitations of WDL, and subsequent tasks include processing to account for those changed outputs. As such the input and output of some tasks are not one-to-one of their CWL equivalent tasks.

### Miscellaneous
* loadContents: Some of the outputs in the CWL at first look like they are globbing .txt files, but they actually are using loadContents, which works like this: For each file matched in glob, read up to the first 64 KiB of text from the file  and place it in the contents field of the file object for manipulation by outputEval. So, the CWL's call for self[0].contents would be the first 64 KiB of the 0th file to match the .txt glob. That would be segments.txt in the prepare segments tasks. Therefore the WDL mimics this by just reading segments.txt

* This pipeline features heavy usage of the twice localized workaround. (Interestingly, some steps in the CWL actually use the same or a similar workaround, so sometimes this isn't a difference but rather a case of simultaneous invention.)

### High-level overview
![Table showing high-level overview of tasks in the CWL versus the WDL. Information is summarized in text.](https://raw.githubusercontent.com/DataBiosphere/analysis_pipeline_WDL/assoc-agg-part2/_documentation_/for%20developers/assoc_agg_cwl_vs_wdl.png)

### wdl_validate_inputs
**Summary: New task to validate inputs**  
This is a simple to task to validate if three String? inputs are valid. The CWL sets them as type enum, which limits what values they can be. WDL does not have this type, so this task performs the validation to ensure inputs are valid. We do this before anything else runs as these inputs are not used until about halfway down the pipeline, and we don't want to waste user's time doing the first half if the second is doomed to fail.

### sbg_prepare_segments_1
First, a point on naming: sbg_prepare_segments_1 is not to be confused with sbg_prepare_segments. sbg_prepare_segments is not used in this workflow at all, in neither the CWL or the WDL, but is used in different CWL workflows.

#### input differences
**Summary: CWL considers an input optional; WDL considers it required**  
The CWL accounts for there being no aggregate files, as the CWL considers them an optional input. We don't need to account for that because the way WDL works means it they are a required output of a previous task and a required input of this task. That said, if this code is reused for other WDLs, it will need adjustment in the latter half of this task (the region is marked with a comment restating this paragraph).

#### output differences
**Summary: CWL outputs 3 or 4 files; WDL outputs one zip file containing 3 or 4 files**  
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

It is theoretically possible to mimic this in a WDL that is compatible in Terra using custom structs, but I had difficulty scattering on such a thing reliably. (The fact that variant_include_files is an optional array seems to be part of the issue.) In any case, I found it to be less error-prone to simply set this task's output to a single array of zip files and to have the next task scatter on those zip files. Each zip file contains, and will pass into each instance of the subsequent scattered task:
* One GDS file
* One file with with the pattern X.integer where X represents the segment number
* One aggregate RData file
* Optional: One variant include RData file, in its own subfolder in order to differentiate it from the other RData file

Why is the variant include output in its own subfolder? The variant include RData file does not have a predictable file name, nor does the aggregate RData file -- all we know is their extension, which they share. The CWL "keeps track" of them by assigning them to output variables of type file. We are unable to do that, nor can we easily assign unpredictable file names to an output variable of type string in WDL ("easily" because in theory this could be done with using read_file() to output a variable of type string but I have found it to be error-prone), therefore we are using the filesystem itself to keep track of which RData file is which.

### assoc_aggregate
**Summary: Both WDL and CWL can output nothing for this task, but in WDL we must be very careful**  
Each instance of this scattered task represents one segment of the genome. In both the CWL and the WDL, it is possible for a segment to generate no output in this task. This is not an error, and it is more common with a greater number of segments (as that means smaller segments and decreased likelihood of a "hit"). The Rscript will report there is nothing to do and print "exiting gracefully" without generating an RData file.

This is problematic for WDL, as Terra-compatible WDL has strict limitations on generating and using optional outputs. Thusly we have to set the output to `Array[File]? assoc_aggregate = glob("*.RData")`, which is not to be confused with `Array[File?] assoc_aggregate = glob("*.RData")`.

### sbg_flatten_lists and `Array[File] flatten_array = flatten(select_all(assoc_aggregate.assoc_aggregate))`
Completely replace CWL task with a WDL built-in function.  

### sbg_group_segments_1
The CWL has this as a scattered task. Each instance of the scattered task takes in an Array[File] and outputs an Array[Array[File?]] plus an Array[String?].

The WDL has this a non-scattered task. The task takes in a Array[File] and outputs list of strings a list of the grouped files as Array[String] (along with two debug files). Previous versions of this code attempted to output a complex object containing one Array[File] and one Array[String], but this has issues on Terra. Therefore, the current version is not actually passing any files to the next task. This has the unfortunate side effect of the next task needing to duplicate some of the work done in this task.

### assoc_combine_r
In this task we have a bunch of RData input files in the workdir. If we did not need to run on Terra, we could write the output filename to a text file, then read that as a WDL task-level output and then glob upon that as another WDL task output, but Google-Cromwell doesn't allow for such workarounds. Thankfully, `assoc_combined = glob("*.RData")[0]` *appears* to always grab the correct RData file in its output, although I fear this may not be robust.

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

## pcrelate.wdl
* The kinship_plots task, in the CWL, takes in an out_prefix input via `valueFrom: ${ return inputs.out_prefix + "_pcrelated` } but WDL does not allow this sort of evaluation during a call task. As such the calculation of this string is instead made at runtime of the task.
* The tasks pcrelate_beta and pcrelate both check each input variable is defined before writing that variable to the config file. Some of these inputs must always be defined, so the WDL skips checks for non-optional inputs.

## vcf-to-gds.wdl     
* The twice-localized workaround is used in unique_variant_ids due to permission errors on Terra. See [#2](https://github.com/DataBiosphere/analysis_pipeline_WDL/issues/2).
* The WDL will not start the check_gds task if check_gds is false. The CWL will start the check_gds task regardless and generate a config file, and the true/false only applies to calling the  script.
	* Reasoning: The way GCS billing works, this has the potential of being cheaper. Otherwise we would spend for having a powerful non-preemptible compute designed for an intense task, then only using that compute for making a text file.
* The WDL can correctly handle a mixture of file extensions, not so much by design, but due to the specifics of implementation. The CWL will handle such a mixture incorrectly in check_gds (but can correctly handle a homogeneous group, such as all being bcf files).
* check_gds uses the chromosome file workaround.
