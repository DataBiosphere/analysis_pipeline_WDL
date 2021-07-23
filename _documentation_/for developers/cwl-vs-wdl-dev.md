# CWL vs WDL: Algorithmic Differences
These differences are likely only of interest to maintainers of this repo or those seeking to fully understand the CWL --> WDL conversion process, besides basics of the WDL or removal of things related to the Seven Bridges API.  

## All Workflows 
**Javascript vs Python:** The CWL generates config files using an InlineJavascriptRequirement, which is run before the CWL equivivalent of a task's command section begins. The WDL generates them using an inline Python script during the beginning of a task's command section.  

**Imports:** The CWL is set up such that there is a "main" CWL file for the overall workflow, which imports one additional CWL file per task. A WDL equivalent to this setup exists, but was not used for security reasons. The current recommended best practice is to avoid using imports in workflows except in checker workflows.

**Defaults:** The CWL has some entries listed as sbg:toolDefaultValue which are not considered defaults in the WDL. This is because sbg:toolDefaultValue is a UI tooltip that does not write anything. The default values are defaults with regard to the Rscript. For instance, if the user does not input a value for `null_model_r.norm_bygroup`, the WDL will not write `false` to the config file. Instead, it will not write it to the config file at all, and the Rscript will treat this as if the config said `false`

**The chromosome file workaround:** A few R scripts require chromosome numbers to be passed in on the command line rather than in the configuration file. In order to do this, chromosome number is written to a file (completely separate from the configuration file) in the task's inline Python section. Upon exiting the Python block, this extra file is read in BASH and then passed to the Rscript call as an argument (as opposed to being in the configuration file). Although the actual call to the R script is identical as the CWL also passes the chr number as an argument, the CWL is able to rely on its inline Javascript to do this, while the WDL must use this workaround to pass the chr number out of the Python scope. As this only involves writing a tiny file that doesn't scale with inputs, it does not have cost implications.

## null-model.wdl
The twice-localized workaround is used for a slightly different reason that it is in other workflows. See [params-vs-wdl](https://github.com/DataBiosphere/analysis_pipeline_WDL/blob/implement-null-model/_documentation_/for%20developers/params-vs-config.md) for more information.

The second significant difference: The CWL technically has duplicated outputs. The WDL instead returns each file once. On SB, cwl.output.json sets the outputs as the following, where ! indicates a duplicated output, inverse norm transformation is applied, and the output_prefix is set to `test`:
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

## ld-pruning.wdl
* The twice-localized workaround is used for the same reason as it is in unique_variant_ids; it is taking in an input array of files from more than one input directory.
* WDL does not have an equivalent to ScatterMethod:DotProduct so it instead scatters using zip().
* check_merged_gds uses the chromosome file workaround.

## vcf-to-gds.wdl     
* The twice-localized workaround is used in unique_variant_ids due to the fact the R script requires an array of GDS files and uses a config file which can only support an array of GDS files if each GDS file is in the same parent directory. As the GDS files are generated from a scattered task, they are sometimes given unique input directories on some file systems. As such, they first need to be pulled from all of their input directories and placed in the working directory before the config file is generated. This is explained more in-depth as the example case for [#2](https://github.com/DataBiosphere/analysis_pipeline_WDL/issues/2).
* The WDL will not start the check_gds task if check_gds is false. The CWL will start the check_gds task regardless and generate a config file, and the true/false only applies to calling the  script.
	* Reasoning: The way GCS billing works, this has the potential of being cheaper. Otherwise we would spend for having a powerful non-preemptible compute designed for an intense task, then only using that compute for making a text file.
* The WDL can correctly handle a mixture of file extensions, not so much by design, but due to the specifics of implementation. The CWL will handle such a mixture incorrectly in check_gds (but can correctly handle a homogenous group, such as all being bcf files).
* check_gds uses the chromosome file workaround.
