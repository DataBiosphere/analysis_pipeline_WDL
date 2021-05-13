# Null Model (null-model-wf.wdl)


## Inputs
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
| variable          			| type   | default    |info                                 |
|----------------------------	|--------|----------- |------------------------------------	|
| ld_pruning.exclude_pca_corr 	| Boolean|    true    | Exclude variants in regions with high correlation with PCs (HLA, LCT, inversions)    	|
| ld_pruning.genome_build 		| String |    "hg38"  | Must be "hg38", "hg19", or "hg18"	|
| ld_pruning.ld_r_threshold		| Float  |    0.32    | R threshold (0.32^2 = 0.1)    		|
| ld_pruning.ld_win_size 		| Float  |    10.0    | Sliding window size in Mb    		|
| ld_pruning.maf_threshold 		| Float  |    0.01    | Minimum MAF for variants    		|
| ld_pruning.missing_threshold 	| Float  |    0.01    | Maximum missing call rate for variants    	|

Note that `addldisk` is adding gigabytes **on top of** the WDL's best-guess estimate of disk space needed based on the size of your inputs.

### Outputs
unique_variant_id_gds_per_chr:
* Type: *Array[File]*
* Array of GDS files, matching the name of the input vcfs with ".gds" appended to the end, and with unique variant IDs across the whole genome.  
  
Note that the check_gds step, while it will stop the pipeline should a check fail, does not actually have any true ouputs. The GDS file output is from the step prior.
