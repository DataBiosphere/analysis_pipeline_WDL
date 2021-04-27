# Conversion to GDS (vcf-to-gds-wf.wdl)
This script converts vcf.gz/vcf/vcf.bgz/bcf, one per chromosome, to GDS files. It then provides each variant across the files with unique variant IDs for later compatiability with PLINK, and optionally checks the resulting GDS files against their original inputs for consistency. This represents [the first "chunk" of the original pipeline](https://github.com/UW-GAC/analysis_pipeline#conversion-to-gds) minus the currently-not-recommend optional merge. Merging is still planned to be supported, but only after linkage disequilbrium (also in-progress) is calculated.

Please be aware that the third step, check_gds is skipped by default, as it is incredibly slow on non-downsampled data. Running this step on modern TOPMed data can take literal days.  

### Inputs
| variable          	| type          	| default 	| info                                                                                                                        	|
|-------------------	|---------------	|---------	|-----------------------------------------------------------------------------------------------------------------------------	|
| **vcf**               	| **Array[File]**   	|         	| **Input vcf, .vcf.bgz, .vcf.gz, .bcf, or any combination thereof; expects 22-25**                                                              	|
|                   	|               	|         	|                                                                                                                             	|
| check_gds         	| Boolean       	| false   	| Run the checkGDS step. **Highly recommended** to leave as `false`. 	|
| checkgds_cpu			| int 				| 1			| Runtime cores to allot for 3rd task (no-op if check_gds=False)                                                         	|
| checkgds_disk     	| int           	|         	| Runtime disk space to allot for 3rd task (no-op if check_gds=False)                                                         	|
| checkgds_memory   	| int           	| 4       	| Runtime memory to allot for 3rd task (no-op if check_gds=False)                                                             	|
| format            	| Array[String] 	| ["GT"]  	| VCF FORMAT fields to carry over into the GDS. Default is GT, ie, non-genotype fields are discarded.                         	|
| uniquevars_cpu		| int 				| 1			| Runtime cores to allot for 2nd task |
| uniquevars_disk   	| int           	|         	| Runtime disk space to allot for 2nd task                                                                                    	|
| uniquevars_memory 	| int           	| 4       	| Runtime memory to allot for 2nd task                                                                                        	|
| vcfgds_cpu			| int 				| 1			| Runtime cores to allot for 1st task |
| vcfgds_disk       	| int           	|         	| Runtime disk space to allot for 1st task                                                                                    	|
| vcfgds_memory     	| int           	| 4       	| Runtime memory to allot for 1st task                                                                                        	|
|                   	|               	|         	|                                                                                                                             	|

### Outputs
unique_variant_id_gds_per_chr: *Array[File]* of GDS files, matching the name of the input vcfs with ".gds" appended to the end, and with unique variant IDs across the whole genome.
