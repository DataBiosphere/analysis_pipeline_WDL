version 1.0
import "https://raw.githubusercontent.com/DataBiosphere/analysis_pipeline_WDL/assoc-agg-part2/assoc-aggregate/assoc-aggregate.wdl" as assoc_agg_wf
import "https://raw.githubusercontent.com/dockstore/checker-WDL-templates/rdata-checker-for-arraycheck/checker_tasks/arraycheck_task.wdl" as verify_array

workflow checker {
	input {
		Array[File]  input_gds_files
		Int          n_segments = 100 # if this changes, you need to remake the truth files
		File         null_model_file
		File         phenotype_file
		Array[File]  variant_group_files_coding # used for weights_test and allele_test
		Array[File]  variant_group_files_genes  # used for position_test
		Array[File]  variant_include_files
		File         variant_weight_file
	}

	call assoc_agg_wf.assoc_agg as allele_test {
		input:
			aggregate_type = "allele",
			genome_build = "hg19",
			input_gds_files = input_gds_files,
			n_segments = n_segments,
			null_model_file = null_model_file,
			out_prefix = "allele_test",
			phenotype_file = phenotype_file,
			test = "burden",
			variant_group_files = variant_group_files,
			ariant_include_files = variant_include_files,
			variant_weight_file = variant_weight_file
	}
	
	call assoc_agg_wf.assoc_agg as position_test {
		input:
			aggregate_type = "position",
			alt_freq_max = 0.1,
			genome_build = "hg19",
			input_gds_files = input_gds_files,
			n_segments = n_segments,
			null_model_file = null_model_file,
			out_prefix = "position_test",
			phenotype_file = phenotype_file,
			test = "burden",
			variant_group_files = variant_group_files,
			ariant_include_files = variant_include_files
	}

	call assoc_agg_wf.assoc_agg as weights_test {
		input:
			aggregate_type = "allele",
			alt_freq_max = 0.1,
			genome_build = "hg19",
			input_gds_files = input_gds_files,
			n_segments = n_segments,
			null_model_file = null_model_file,
			out_prefix = "weights_test",
			pass_only = pass_only,
			phenotype_file = phenotype_file,
			segment_length = segment_length,
			test = "burden",
			variant_group_files = variant_group_files,
			variant_weight_file = variant_weight_file,
			weight_user = "CADD"
	}
}