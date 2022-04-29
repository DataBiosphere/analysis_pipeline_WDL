# Relatedness and Population Structure Filtering (ld-pruning-wf.wdl)
**Cost estimate when running on Terra, default inputs: $0.67**  
This workflow prunes on the basis of linkage disequilibrium. It then subsets GDS files based on those pruned variants, then performs merging and optional checks the merged files. This represents [the second "chunk" of the original pipeline](https://github.com/UW-GAC/analysis_pipeline#relatedness-and-population-structure).

**Warning: If you run this on a local machine without setting concurrent-job-limit for Cromwell, Cromwell will attempt to LD prune all 23 chromosomes at once, likely freezing Docker across your OS in the process.** Please check the repo's main readme for more information.

Original CWL description:
> This workflow LD prunes variants and creates a new GDS file containing only the pruned variants. Linkage disequilibrium (LD) is a measure of correlation of genotypes between a pair of variants. LD-pruning is the process filtering variants so that those that remain have LD measures below a given threshold. This procedure is typically used to identify a (nearly) independent subset of variants. This is often the first step in evaluating relatedness and population structure to avoid having results driven by clusters of variants in high LD regions of the genome.

Some variable descriptions have been pulled from the CWL.

## Inputs
Note that this pipeline only directly takes in variant_include_file in the first step. If you pass in variant_include_file, that is used as a vector of variants to consider for LD pruning. LD pruning outputs an RData file. After the LD pruning task, a variable called variant_include_file is also used in the subset task, but it takes in the output of the previous task's RData file, **not** the file you input for the first task.

Due to [how](https://github.com/zhengxwen/SeqArray/blob/828cbb5d06d85581119aaf9ab854e1d2497c65c5/R/UtilsMerge.R#L282) [SeqArray](https://github.com/zhengxwen/SeqArray/blob/828cbb5d06d85581119aaf9ab854e1d2497c65c5/R/UtilsMerge.R#L299) [works](https://github.com/zhengxwen/SeqArray/blob/828cbb5d06d85581119aaf9ab854e1d2497c65c5/R/UtilsMerge.R#L358), you **must** input more than one file into gds_files. Otherwise, the pipeline will (likely incorrectly) claim that you have repeating variants IDs and/or repeating sample IDs.

### Input Files
* gds_files
	* Required
	* An array of GDS files, with names that contain "chr" + the number/letter of the chromosome, such as ["chr1.gds", "chr2.gds"]
	* Must contain at least two files
* sample_include_file
	* Optional
	* RData file with vector of sample.id to use for LD pruning (unrelated samples are recommended)
	* If not provided, all samples in the GDS files are included
* variant_include_file
	* Optional
	* RData file with vector of variant.id to consider for LD pruning
	* If not provided, all variants in the GDS files are included


### Runtime Attributes
| variable          			| type | default | info   										|
|---------------------------	|---   |-------- |------------------------------------------	|
| check_merged_gds.addldisk		| int  | 5       | Extra disk space to allot for 4th task    	|
| check_merged_gds.cpu	 		| int  | 2       | Runtime cores to allot for 4th task          |
| check_merged_gds.memory  		| int  | 4       | Runtime memory to allot for 4th task   	    |
| check_merged_gds.preempt 		| int  | 3       | # of preemptible VM tries for 4th task       |
| ld_pruning.addldisk 			| int  | 5       | Extra disk space to allot for 1st task    	|
| ld_pruning.cpu	 			| int  | 2       | Runtime cores to allot for 1st task          |
| ld_pruning.memory  			| int  | 4       | Runtime memory to allot for 1st task   	    |
| ld_pruning.preempt 			| int  | 3       | # of preemptible VM tries for 1st task       |
| merge_gds.addldisk 			| int  | 5       | Extra disk space to allot for 3rd task    	|
| merge_gds.cpu	 				| int  | 2       | Runtime cores to allot for 3rd task          |
| merge_gds.memory  			| int  | 4       | Runtime memory to allot for 3rd task   	    |
| merge_gds.preempt 			| int  | 3       | # of preemptible VM tries for 3rd task       |
| subset_gds.addldisk 			| int  | 5       | Extra disk space to allot for 2nd task    	|
| subset_gds.cpu	 			| int  | 2       | Runtime cores to allot for 2nd task          |
| subset_gds.memory  			| int  | 4       | Runtime memory to allot for 2nd task   	    |
| subset_gds.preempt 			| int  | 3       | # of preemptible VM tries for 2nd task       |  

Note that `addldisk` is adding gigabytes **on top of** the WDL's best-guess estimate of disk space needed based on the size of your inputs.

### Tuning Your LD Pruning
| variable          			| type   | default    |info                                 |
|----------------------------	|--------|----------- |------------------------------------	|
| ld_pruning.exclude_pca_corr 	| Boolean|    true    | Exclude variants in regions with high correlation with PCs (HLA, LCT, inversions)    	|
| ld_pruning.genome_build 		| String |    "hg38"  | Must be "hg38", "hg19", or "hg18"	|
| ld_pruning.ld_r_threshold		| Float  |    0.32    | R threshold (0.32^2 = 0.1)    		|
| ld_pruning.ld_win_size 		| Float  |    10.0    | Sliding window size in Mb    		|
| ld_pruning.maf_threshold 		| Float  |    0.01    | Minimum MAF for variants    		|
| ld_pruning.missing_threshold 	| Float  |    0.01    | Maximum missing call rate for variants    	|

### Other
out_prefix: Prefix for all output files (except the config files), type String

## Outputs
ld_pruning_output: Array[File] of RData from the first task


