# assoc-aggregate

## Introduction
*Authorship note: This paraphrases earlier documentation by Stephanie Gogarten.*

**Aggregate Association Testing workflow** runs aggregate association tests, using Burden, SKAT<sup>[1](#SKAT)</sup>, fastSKAT<sup>[2](#fastSKAT)</sup>, SMMAT<sup>[3](#SMMAT)</sup>, or SKAT-O<sup>[4](#SKATO)</sup> to aggregate a user-defined set of variants. Association tests are parallelized by segments within chromosomes.

The define segments tasks splits the genome into segments and assigns each aggregate unit to a segment based on the position of its first variant. Note that n_segments is based upon the entire genome *regardless of the number of chromosomes you are running on.*<sup>[5](#segs)</sup> Association testing is then performed for each segment in parallel, before combining results on chromosome level. Finally, the last step creates QQ and Manhattan plots.

The **alt freq max** parameter allows specification of the maximum alternate allele frequency allowable for inclusion in the joint variant test. Included variants are usually weighted using either a function of allele frequency (specified via the **weight beta** parameter) or some other annotation information (specified via the **variant weight file** and **weight user** parameters). 

When running a burden test, the effect estimate is for each additional unit of burden; there are no effect size estimates for the other tests. Multiple alternate alleles for a single variant are treated separately.

This workflow utilizes the *assocTestAggregate* function from the GENESIS<sup>[6](#GENESIS)</sup> software.

### Use case
Aggregate tests are typically used to jointly test rare variants. This workflow is designed to perform multi-variant association testing on a user-defined groups of variants.

### Common Issues and important notes:
* This pipeline expects that **GDS files**, **variant include files**, and **variant group files** are separated per chromosome, and that files are properly named (as with other workflows in this repository).

* If **Weight Beta** parameter is set, it needs to follow proper convention: two space-delimited floating point numbers.

* **Number of segments** parameter, if provided, needs to be equal or higher than number of chromosomes.

* Testing showed that default parameters for **CPU** and **memory GB** (8GB) are sufficient for testing studies (up to 50k samples), however different null models might increase the requirements.

* The user can ommit known hits using `known_hits_file`, an RData file with data.frame containing columns `chr` and `pos`. If provided, 1 Mb regions surrounding each variant listed will be omitted from the QQ and manhattan plots.

## Sample Inputs
* terra-allele, local-allele, and the first part of the checker workflow are based upon https://github.com/UW-GAC/analysis_pipeline/blob/master/testdata/assoc_aggregate_allele.config
* terra-position, local-position, and the second part of the checker workflow are based upon https://github.com/UW-GAC/analysis_pipeline/blob/master/testdata/assoc_aggregate_position.config
* terra-weights, local-weights, and the third part of the checker workflow are based upon https://github.com/UW-GAC/analysis_pipeline/blob/master/testdata/assoc_aggregate_weights.config
* You'll note that none of these make use of `variant_weight_file`, but one has been provided in this repo regardless


## Notes to code maintainers
* Local Cromwell allows for modifying input files directly even though the Docker image executes as the topmed user which should not have write permissions on the input files. Terra is technically more correct in blocking this, but this leads to some headaches where an output is supposed to be a modified input file as opposed to a brand new file. For these scenarios Terra support suggested `find . -type d -exec sudo chmod -R 777 {} +` which should allow for modifying any input files as the topmed user. This should probably not be messed with -- we need stderr/stdout to keep their permissions, and something like `sudo chmod 777 ${input_file_to_change}` or `sudo su - root` does not work.
* Unlike most WDLs in this repository, this one has some major differences in how it works versus the CWL. These differences should not change the output, but any future code maintainers should take note of cwl-vs-wdl-dev.md in the `_documentation_` folder of this repo.

## References/Footnotes
<a name="SKAT">[1]</a> [SKAT](https://dx.doi.org/10.1016%2Fj.ajhg.2011.05.029)  
<a name="fastSKAT">[2]</a>  [fastSKAT](https://doi.org/10.1002/gepi.22136)  
<a name="SMMAT">[3]</a>  [SMMAT](https://doi.org/10.1016/j.ajhg.2018.12.012)  
<a name="SKATO">[4]</a>  [SKAT-O](https://doi.org/10.1093/biostatistics/kxs014)  
<a name="segs">[5]</a>  For instance, if you set n_segments = 100 and run on just chr1 and chr2, you can expect there to be about 15 segments because chr1 and chr2 together make up about 15% of the human genome. Furthermore, at a minimum, the code automatically will create 1 segment per chromosome, so setting n_segments = 2, 4, or 10 when running on just chr1 and chr2 will each result in just two segments even though you might expect dividing the entire genome into 2, 4, or 10 pieces would result in one segment covering all of chr1 and chr2.  
<a name="GENESIS">[6]</a>  [GENESIS](https://f4c.sbgenomics.com/u/boris_majic/genesis-pipelines-dev/apps/doi.org/10.1093/bioinformatics/btz567)