# Conversion to GDS (vcf-to-gds-wf.wdl)
This workflow converts vcf.gz/vcf/vcf.bgz/bcf, one per chromosome, to GDS files. It then provides each variant across the files with unique variant IDs for later compatiability with PLINK, and optionally checks the resulting GDS files against their original inputs for consistency. This represents [the first "chunk" of the original pipeline](https://github.com/UW-GAC/analysis_pipeline#conversion-to-gds) minus the currently-not-recommend optional merge. For merging GDS files, see the merge_gds task in this repo's LD Pruning workflow.

Please be aware that the third step, check_gds is skipped by default, as it is incredibly slow on non-downsampled data. Running this step on modern TOPMed data can take literal days.  

### Inputs
| variable          	| type          	| default 	| info                                                                                                                        	|
|-------------------	|---------------	|---------	|-----------------------------------------------------------------------------------------------------------------------------	|
| **vcf**               	| **Array[File]**   	|         	| **Input vcf, .vcf.bgz, .vcf.gz, .bcf, or any combination thereof; expects no more than 25 files.**                                                              	|
|                   |           |         	|                                            	|
| check_gds         | Boolean   | false   	| Run the checkGDS step. **Highly recommended** to leave as `false` except on provided test data. 	|
| check_gds.cpu		| int 		| 8			| Runtime cores to allot for 3rd task           |
| checkgds_disk     | int       |         	| Runtime disk space to allot for 3rd task    	|
| check_gds.memory  | int       | 12       	| Runtime memory to allot for 3rd task   	    |
| check_gds.preempt | int       | 0       	| # of preemptible VM tries for 3rd task, **highly recommended** to leave as 0 except on provided test data. |
| format            | Array[String] | ["GT"]| VCF FORMAT fields to carry over into the GDS. Default is GT, ie, non-genotype fields are discarded. |
| unique_variant_id.cpu	| int 	| 2			| Runtime cores to allot for 2nd task           |
| uniquevars_disk   	| int   |         	| Runtime disk space to allot for 2nd task    	|
| unique_variant_id.memory 	| int  | 4      | Runtime memory to allot for 2nd task          |
| unique_variant_id.preempt | int  | 4      | # of preemptible VM tries for for 2nd task    |
| vcfgds.cpu			| int   | 2			| Runtime cores to allot for 1st task           |
| vcfgds.addldisk       | int   | 1       	| Extra disk size (GB) to allot for 1st task    |
| vcfgds.memory     	| int   | 4       	| Runtime memory to allot for 1st task      	|
| vcfgds.preempt     	| int   | 3       	| # of preemptible VM tries for for 1st task   	|
|                   	|       |         	|                                               |

Note that `addldisk` is adding gigabytes **on top of** the WDL's best-guess estimate of disk space needed based on the size of your inputs.

### Outputs
unique_variant_id_gds_per_chr:
* Type: *Array[File]*
* Array of GDS files, matching the name of the input vcfs with ".gds" appended to the end, and with unique variant IDs across the whole genome.  
  
Note that the check_gds step, while it will stop the pipeline should a check fail, does not actually have any true ouputs. The GDS file output is from the step prior.

### Example of runtime attributes for "real" data on Terra
When running on 1000 Genomes NA20768.haplotypeCalls.er.raw.g.vcf.gz and NA19321.haplotypeCalls.er.raw.g.vcf.gz, the first task alone took 2 hours and 40 minutes when vcfgds.addldisk = 1, vcfgds.cpu = 16, and vcfgds.memory = 64. unique_variant_ids was not run as these files do not correspond to the chrN naming scheme that it requires.
