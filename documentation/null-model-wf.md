# Null Model (null-model-wf.wdl)  
*Authorship note: Much of this file paraphrases documentation written by Stephanie Gogarten*

## Table Of Contents
<!---toc start-->
* [Quick Introduction](#quick-introduction)
* [Regression Type](#regression-type)
* [Inputs](#inputs)
  * [Runtime Attributes](#runtime-attributes)
  * [Additional Null Model Settings](#additional-null-model-settings)
  * [Additional Report Settings](#additional-report-settings)
* [Outputs](#outputs)
* [Common Issues](#common-issues)
* [More Information](#more-information)
<!---toc end-->

## Quick Introduction
In a null model fitting, an outcome variable is regressed on specific fixed effect covariates and random effects. In our case the null hypothesis is there being no genotype effects on the outcome variable. Thus, this is often the first step in an association analysis.  

This workflow consists of two tasks -- fitting the null model and then generating reports (HTML and RMD) based on that. The reports contain phenotype distributions, covariate effect, marginal residuals, and adjusted phenotype values.

## Regression Type
The type of regression used is based on the values given for the variables `related_matrix_file` and `family` variables. If neither of them are not set by the user, the default of the `family` variable will be gaussian, leading to a standard linear regression.

| related matrix file 	| family   	| regression used          	|
|---------------------	|----------	|--------------------------	|
| not provided        	| gaussian 	| standard linear           |
| not provided        	| binomial 	| binomial                 	|
| not provided        	| poisson  	| poisson                  	|
| provided            	| gaussian 	| linear mixed             	|
| provided            	| binomial 	| generalized linear mixed 	|
| provided            	| poisson  	| generalized linear mixed 	|

## Common Issues

* If **PCA File** is not provided, the **Number of PCs to include as covariates** parameter **must** be set to 0.
* **PCA File** must be an RData object output from the *pcair* function in the GENESIS package.
* The null model job can be very computationally demanding in large samples (e.g. > 20K). GENESIS supports using sparse representations of matrices in the **Relatedness matrix file** via the R Matrix package, and this can substantially reduce memory usage and CPU time.

## Inputs
phenotype_file:
* Type: *File*
* todo  

outcome:
* Type: *String*
* Name of column in phenotype file containing outcome variable.

All other inputs in this workflow are optional.
### Runtime Attributes
| variable          			| type | default | info   										|
|---------------------------	|---   |-------- |------------------------------------------	|
| null_model_r.addldisk 		| int  | 1       | Extra disk space to allot for 1st task    	|
| null_model_r.cpu	 			| int  | 2       | Runtime cores to allot for 1st task          |
| null_model_r.memory  			| int  | 4       | Runtime memory to allot for 1st task   	    |
| null_model_r.preempt 			| int  | 3       | # of preemptible VM tries for 1st task       |
| null_model_report.addldisk 	| int  | 1       | Extra disk space to allot for 2nd task    	|
| null_model_report.cpu	 		| int  | 2       | Runtime cores to allot for 2nd task          |
| null_model_report.memory  	| int  | 4       | Runtime memory to allot for 2nd task   	    |
| null_model_report.preempt 	| int  | 3       | # of preemptible VM tries for 2nd task       |  

Note that `addldisk` is adding gigabytes **on top of** the WDL's best-guess estimate of disk space needed based on the size of your inputs.

### Additional Null Model Settings
| variable          			            | type     | default|info                                 |
|---------------------------------------	|----------|------- |------------------------------------	|
| null_model_r.conditional_variant_file 	| File     | n/a    | RData file with a data.frame of identifiers for variants to be included as covariates for conditional analysis. Columns should include “chromosome” and “variant.id” that match the variant.id in the GDS files. The alternate allele dosage of these variants will be included as covariates in the analysis.	|
| null_model_r.covars 						| Array[String]     | n/a   | Names of columns phenotype_file containing covariates.		|
| null_model_r.family						| String†  | "gaussian"   | Depending on the output type (quantitative or qualitative) one of possible values should be chosen: gaussian, binomial, poisson.    	|
| null_model_r.gds_files 					| Array[File]     | n/a   | List of gds files. Required if conditional_variant_file is specified.    	|
| null_model_r.group_var 					| String     | n/a   | Name of covariate to provide groupings for heterogeneous residual error variances in the mixed model.    	|
| null_model_r.inverse_normal 				| Boolean† | true   | TRUE if a two-stage model should be implemented. Stage 1: a null model is fit using the original outcome variable. Stage 2: a second null model is fit using the inverse-normal transformed residuals from Stage 1 as the outcome variable. When FALSE, only the Stage 1 model is fit.  Only applies when Family is “gaussian”.   	|
| null_model_r.n_pcs 						| Int	   | 0   	| Number of PCs from PCA file to include as covariates.    	|
| null_model_r.norm_bygroup 				| Boolean† | false  | Applies only if Two stage model is TRUE and Group variate is provided. If TRUE,the inverse-normal transformation (and rescaling) is done on each group separately. If FALSE, this is done on all samples jointly.		|
| null_model_r.output_prefix				| String   | "null_model"   | Base for all output file names.    	|
| null_model_r.pca_file 					| File     | n/a    | RData file with PCA results created by PC-AiR.    	|
| null_model_r.relatedness_matrix_file 		| File     | n/a    | RData or GDS file with a kinship matrix or GRM.    	|
| null_model_r.rescale_variance 			| String†  | "marginal"    | Applies only if Inverse normal is TRUE and Group variate is provided. Controls whether to rescale the variance for each group after inverse-normal transform, restoring it to the original variance before the transform. Options are marginal, varcomp, or none.    	|
| null_model_r.resid_covars 				| Boolean| true   | Applies only if Inverse normal is TRUE. Logical for whether covariates should be included in the second null model using the residuals as the outcome variable.    	|
| null_model_r.sample_include_file 			| File | n/a |  RData file with vector of sample.id to include.		|
† In the CWL, this is type enum, which doesn't exist in WDL.

### Additional Report Settings
n_categories_boxplot:
* Int? (optional)
* Number of catagories in box plot. Default is 10.

## Outputs
html_reports:  
* Type: *Array[File]*  
* HTML reports  

rmd_files:  
* Type: *Array[File]*  
* R markdown files used to generate the HTML reports  

## More Information
* [Original Python pipeline's description](https://github.com/UW-GAC/analysis_pipeline#null-model)
* [CWL Pipeline's documentation](https://github.com/UW-GAC/analysis_pipeline_cwl/blob/c68ac3f3c8b07512d0fcaffd03ed2d168e294993/association/null-model-wf.cwl#L4) -- note that cost estimations in that CWL do **not** apply to this WDL

