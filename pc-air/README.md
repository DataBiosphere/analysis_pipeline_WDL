# PC-AiR

**Select an informative set of unrelated samples, do PCA on unrelated, project into relatives**
 
This workflow uses the [PC-AiR algorithm](https://pubmed.ncbi.nlm.nih.gov/25810074/) to compute ancestry principal components (PCs) while accounting for kinship.

Step 1 uses pairwise kinship estimates to assign samples to an unrelated set that is representative of all ancestries in the sample. Step 2 performs Principal Component Analysis (PCA) on the unrelated set, then projects relatives onto the resulting set of PCs. Step 3 plots the PCs, optionally color-coding by a grouping variable. Step 4 (optional) calculates the correlation between each PC and variants in the dataset, then plots this correlation to allow screening for PCs that are driven by particular genomic regions.

## Inputs

parameter | type | description | default
--- | --- | --- | ---
`gds_file_full` | Array[File] | GDS files (one per chromosome) used to calculate PC-variant correlations. | 
`kinship_file` | File? | Pairwise kinship matrix used to identify unrelated and related sets of samples in Step 1. It is recommended to use KING-IBDseg or PC-Relate estimates. | 
`out_prefix` | File? | Prefix for output files. | 
`gds_file` | File | Input GDS file for PCA. It is recommended to use an LD pruned file with all chromosomes. | 
`run_correlation` | Boolean | For pruned variants as well as a random sample of additional variants, compute correlation between the variants and PCs, and generate plots. This step can be computationally intensive, but is useful for verifying that PCs are not driven by small regions of the genome. | True
`divergence_file` | File? | Pairwise matrix used to identify ancestrally divergent pairs of samples in Step 1. It is recommended to use KING-robust estimates. |
`sample_include_file` | File? | RData file with vector of sample.id to include. If not provided, all samples in the GDS file are included. | 
`variant_include_file` | File? | RData file with vector of variant.id to include. If not provided, all variants in the GDS file are included. | 
`phenotype_file` | File? | RData file with data.frame or AnnotatedDataFrame of phenotypes. Used for color-coding PCA plots by group. | 
`kinship_threshold` | Float? | Minimum kinship estimate to use for identifying relatives. | 0.044194174 # 2^(-9/2) (third-degree relatives and closer)
`divergence_threshold` | Float? | Maximum divergence estimate to use for identifying ancestrally divergent pairs of samples. | 0.044194174 # 2^(-9/2)
`n_pairs` |  Int? | Number of PCs to include in the pairs plot. | 6
`group` | String? | Name of column in phenotype_file containing group variable for color-coding plots. | 
`n_corr_vars` | Int? | Randomly select this number of variants distributed across the entire genome to use for PC-variant correlation. If running on a single chromosome, the variants returned will be scaled by the proportion of that chromosome in the genome. | 10e6
`n_pcs_plot` | Int? | Number of PCs to plot. | 20
`n_pcs` | Int? | Number of PCs (Principal Components) to return. | 32 
`n_perpage` | Int? | Number of PC-variant correlation plots to stack in a single page. The number of png files generated will be ceiling(n_pcs_plot/n_perpage). | 4

## Outputs

* out_unrelated_file: RData file with vector of sample.id of unrelated samples identified in Step 1
* out_related_file (File): RData file with vector of sample.id of samples related to the set of unrelated samples identified in Step 1
* pcair_output (File): RData file with PC-AiR PCs for all samples
* pcair_plots (Array[File]): Plot of PCs
* pc_correlation_plots (Array[File]): PC-variant correlation plots (only output if run_correlation is not set to False)
* pca_corr_gds (Array[File]): GDS file with PC-variant correlation results (only output if run_correlation is not set to False)
