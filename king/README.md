# Relatedness and Population Structure - Getting Initial Kinship Estimates (king.wdl)
**Cost estimate when running on Terra, default inputs: $0.07**  
This workflow first converts the ld-pruned gds file to the bed file format. Next, it uses the [PLINK](https://www.cog-genomics.org/plink2/) program to process the bed file. It then uses the [KING](https://www.chen.kingrelatedness.com/) program to get initial kinship estimates. It also outputs a kinship matrix and kinship hexbin plot based on the kinship estimates. This represents [the third "chunk" of the original pipeline](https://github.com/UW-GAC/analysis_pipeline#relatedness-and-population-structure).

Original CWL description:
> This workflow uses the KING --ibdseg method to estimate kinship coefficients, and returns results for pairs of related samples. These kinship estimates can be used as measures of kinship in PC-AiR.

Some variable descriptions have been pulled from the CWL.

## Inputs
Note that this pipeline the only required input is the gds_file. A sample_include_file, variant_include_file, and phenotype_file are optional input files that may be used at various steps in the workflow. A bim_file and fam_file are generated as secondary outputs in the first and second task and are given as input to the next consecutive task.

### Input Files
* gds_files
	* Required
	* GDS file with only LD pruned variants, all chromosomes
* sample_include_file
	* Optional
	* RData file with vector of sample.id to include
	* Required to ensure that the output matrix includes all samples for later analysis
* variant_include_file
	* Optional
	* RData file with vector of variant.id to include
* phenotype_file
	* Optional
	* RData file with AnnotatedDataFrame of phenotypes
	* Used for plotting kinship estimates separately by study


### Runtime Attributes
| variable          			| type | default | info   										|
|---------------------------	|---   |-------- |------------------------------------------	|
| gds2bed.addldisk		| int  | 5       | Extra disk space to allot for 1st task    	|
| gds2bed.cpu	 		| int  | 2       | Runtime cores to allot for 1st task          |
| gds2bed.memory  		| int  | 4       | Runtime memory to allot for 1st task   	|
| gds2bed.preempt 		| int  | 3       | # of preemptible VM tries for 1st task       |
| plink_make_bed.addldisk		| int  | 5       | Extra disk space to allot for 2nd task    	|
| plink_make_bed.cpu	 		| int  | 2       | Runtime cores to allot for 2nd task          |
| plink_make_bed.memory  		| int  | 4       | Runtime memory to allot for 2nd task   	|
| plink_make_bed.preempt 		| int  | 3       | # of preemptible VM tries for 2nd task       |
| king_ibdseg.addldisk		| int  | 5       | Extra disk space to allot for 3rd task    	|
| king_ibdseg.cpu	 	| int  | 2       | Runtime cores to allot for 3rd task          |
| king_ibdseg.memory  		| int  | 4       | Runtime memory to allot for 3rd task   	|
| king_ibdseg.preempt 		| int  | 3       | # of preemptible VM tries for 3rd task       |
| king_to_matrix.addldisk		| int  | 5       | Extra disk space to allot for 4th task    	|
| king_to_matrix.cpu	 		| int  | 2       | Runtime cores to allot for 4th task          |
| king_to_matrix.memory  		| int  | 4       | Runtime memory to allot for 4th task   	|
| king_to_matrix.preempt 		| int  | 3       | # of preemptible VM tries for 4th task       |
| kinship_plots.addldisk		| int  | 5       | Extra disk space to allot for 5th task    	|
| kinship_plots.cpu	 		| int  | 2       | Runtime cores to allot for 5th task          |
| kinship_plots.memory  		| int  | 4       | Runtime memory to allot for 5th task   	|
| kinship_plots.preempt 		| int  | 3       | # of preemptible VM tries for 5th task       |
  

Note that `addldisk` is adding gigabytes **on top of** the WDL's best-guess estimate of disk space needed based on the size of your inputs.

### Tuning King
| variable          			| type   | default    |info                                 	|
|--------------------------------------	|--------|----------- |----------------------------------------	|
| gds2bed.bed_file		 	| String |    ""      | Output BED file name		    	|
| king_to_matrix.sparse_threshold 	| Float  | 0.02209709 | Minimum kinship to use for creating the sparse matrix from king --ibdseg output |
| kinship_plots.study			| String |    ""      | Name of column in phenotype_file containing study variable    			|

### Other
out_prefix: Prefix for all output files (except the config files), type String

## Outputs
* king_ibdseg_output: Text [File].seg with pairwise kinship estimates for all sample pairs with any detected IBD segmentsfrom the third task
* king_ibdseg_matrix: Block-diagonal matrix [File].seg of pairwise kinship estimates from the fourth task
* king_ibdseg_plots: Hexbin plots [File].RData of estimated kinship coefficients from the the fifth task


