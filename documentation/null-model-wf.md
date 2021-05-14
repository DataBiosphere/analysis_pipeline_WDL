# Null Model (null-model-wf.wdl)


## Inputs
phenotype_file:
* Type: *File*
* todo
outcome:
* Type: *String*
* Name of column in phenotype file containing outcome variable.


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

### Additional Null Model Settings (all optional)

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

### Outputs
todo:
* Type: *Array[File]*
* todo
  


