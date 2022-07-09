# Test Data
From UWGAC:
> The data in this directory are from [the 1000 Genomes project](http://www.internationalgenome.org/). This is a small subset of the data available [here](http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502/). The variants are in genome build hg19.  

Unless otherwise noted, all files here were generated with default settings for the pipeline. 

## assoc/
The following files should not be used as truth files:
* null_model.RData
* segments.txt
* aggregate_list_chr1, aggregate_list_chr2, aggregate_list_chr12, and aggregate_list_chrX

My copy of this repo includes a large bogus chr1 file that was created by concatinating chr1 to itself until it was over 4 GB in size. Not wanting to make this repo huge, it is not included in remote, but it may appear in checksums.md5

| file                                         	| source                           	| docker                     	| config   	| chrs of run    	| notes                                                                                                                                         	|
|----------------------------------------------	|----------------------------------	|----------------------------	|----------	|----------------	|-----------------------------------------------------------------------------------------------------------------------------------------------	|
| 1KG_phase3_subset_chr*.gds                   	| original pipeline's `/testdata/` 	| n/a                        	| n/a      	| n/a            	| manually checked md5 match of chr1 with [source](https://github.com/UW-GAC/analysis_pipeline/commit/8e35e1e011e106b0a9a9ece714470aff5cc8e123) 	|
| aggregate_list_chr*.RData                    	| WDL, local                       	| uwgac/topmed-master:2.12.0 	| position 	| chr [1,2,12,X] 	| intermediate file; doesn't have every chr                                                                                                     	|
| coding_variants_chr*.RData                   	| original pipeline's `/testdata/` 	| n/a                        	| n/a      	| n/a            	| used in allele and weights config                                                                                                             	|
| genes_chr*.RData                             	| original pipeline's `/testdata/` 	| n/a                        	| n/a      	| n/a            	| used in position config                                                                                                                       	|
| null_model.RData                             	| original pipeline's `/testdata/` 	| n/a                        	| n/a      	| n/a            	| md5sum match with [this commit](https://github.com/UW-GAC/analysis_pipeline/commit/3020ede672f81cfd8412596af50ce64b78858ca6)                  	|
| variant_include_chr*.RData                   	| original pipeline's `/testdata/` 	| n/a                        	| n/a      	| n/a            	|                                                                                                                                               	|
| truths/allele*                               	| CWL, SBG                         	| unknown                    	| allele   	| unknown        	|                                                                                                                                               	|
| truths/position*                             	| CWL, SBG                         	| unknown                    	| position 	| unknown        	|                                                                                                                                               	|
| truths/weights*                              	| CWL, SBG                         	| unknown                    	| weights  	| unknown        	|                                                                                                                                               	|
| truths/sbg_chr1,2,X/position_with_x_*.RData  	| CWL, SBG                         	| unknown                    	| position 	| chr [1,2,X]    	|                                                                                                                                               	|
| truths/sbg_chr1,2,X/sbg_prepare_segments_1/* 	| CWL, SBG                         	| unknown                    	| unknown  	| chr [1,2,X]    	| intermediate outputs of a single task                                                                                                         	|

## gds/

#### gds/output_vcf2gds
GDS files created as the output of the unique_variant_IDs task. They were instead created using the v1.0.1 WDL version of this pipeline, which runs in uwgac/topmed-master:2.10.0.

#### gds/output_ldpruning
The merged GDS file as the output of the merge_gds task, which also underwent LD pruning on the default settings.

#### gds/2017_versions
Mirrors of `1KG_phase3_subset_chr*.gds` from [UWGAC testdata](https://github.com/UW-GAC/analysis_pipeline/tree/master/testdata). Appear to be from 2017, possibly created via an old version of vcf2gds. Not to be used as truth files for modern pipelines, but they can be used as inputs for assoc_aggregate.

#### Lineage of GDS files
|   	|                                                                                                                      	|   	|                   	|   	|                                                                          	|
|---	|----------------------------------------------------------------------------------------------------------------------	|---	|-------------------	|---	|--------------------------------------------------------------------------	|
|   	| 1KG_phase3_subset_chr*.vcf.gz in `vcfs/`, UWGAC's `testdata/`, and gs://topmed_workflow_testing/UWGAC_WDL/ 		| - 	| *unknown process* 	| → 	| 1KG_phase3_subset_chr*.gds files in `gds/2017_versions/` and UWGAC's `testdata/` 		|
|   	| ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀\|                                                                                                   	|   	|                   	|   	|                                                                          	|
|   	| *Terra WDL run of vcf2gds on uwgac/topmed-master:2.10.0*                                                             	|   	|                   	|   	|                                                                          	|
|   	| ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀↓                                                                                                    	|   	|                   	|   	|                                                                          	|
|   	| 1KG_phase3_subset_chr*.gds in<sup>†</sup> `gds/output_vcf2gds/` and gs://topmed_workflow_testing/UWGAC_WDL/checker/a_vcf2gds/  	|   	|                   	|   	|                                                                          	|
|   	| ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀\|                                                                                                   	|   	|                   	|   	|                                                                          	|
|   	| *Terra WDL run of ld_pruning on uwgac/topmed-master:2.10.0*                                                          	|   	|                   	|   	|                                                                          	|
|   	| ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀↓                                                                                                    	|   	|                   	|   	|                                                                          	|
|   	| `gds/output_ldpruning/merged.gds` and gs://topmed_workflow_testing/UWGAC_WDL/checker/b_ldpruning/merged.gds           |   	|                   	|   	|                                                                          	|
 
<sup>†</sup>chrX is among the files in `gds/output_vcf2gds/`, but was not used to generate the files in `gds/output_ldpruning/` due to [#8](https://github.com/DataBiosphere/analysis_pipeline_WDL/issues/8).

## null_model/
Test files pulled from [UWGAC Github](https://github.com/UW-GAC/analysis_pipeline/tree/master/testdata), with the exception of the two *Null_model_mixed* files which came from the GENESIS Null Model sample workspace, based upon Revision 17 of the CWL null model workflow, on Seven Bridges. All files are based upon older versions of 1000 Genomes data but may have undergone additional processing, the details of which are unknown due to the age of the files. *It is not recommended to use any of these for real analysis, as they are made for a specific test data set.*

## vcfs/
These are the same vcf.gz files as can be found in the UWGAC, with the exception of chrX. This repo's chrX is filtered as some of the lines on the original repo's chrX are invalid and will error out. See https://github.com/UW-GAC/analysis_pipeline/issues/46.

#### vcfs/alternative_vcfs/
In addition to the vcf.gz files stored in `vcfs/`, the following additional test files are also included for testing alternative file types.
* 1KG_phase3_subset_chr1.bcf
* 1KG_phase3_subset_chr1.vcf
* 1KG_phase3_subset_chr2.vcf
* 1KG_phase3_subset_chr2.vcf.bgz
* 1KG_phase3_subset_chr3.vcf.bgz
* 1KG_phase3_subset_chrX.vcf
* unfiltered1KG_phase3_subset_chrX.vcf.gz -- the original chrX in the UWGAC repo
* unfiltered1KG_phase3_subset_chrX.vcf -- the original chrX in the UWGAC repo, unzipped


# Miscellanous tips
* github.com is pretty good for determining when a file was added, but you could also use `git log --diff-filter=A -- WHATEVERFILENAMEHERE | head -n 3 | tail -n 1` from the command line