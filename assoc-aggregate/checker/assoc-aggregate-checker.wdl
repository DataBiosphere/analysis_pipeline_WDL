version 1.0
import "https://raw.githubusercontent.com/DataBiosphere/analysis_pipeline_WDL/assoc-agg-part2/assoc-aggregate/assoc-aggregate.wdl" as assoc_agg_wf
import "https://raw.githubusercontent.com/dockstore/checker-WDL-templates/rdata-checker-for-arraycheck/checker_tasks/arraycheck_task.wdl" as verify_array

workflow aggie_checker {
	input {
		# do not make any changes, including n_segments, without remaking the truth files
		Array[File]  input_gds_files
		File         null_model_file
		File         phenotype_file
		Array[File]  variant_group_files_coding # used for weights_test and allele_test
		Array[File]  variant_group_files_genes  # used for position_test
		Array[File]  variant_include_files

		# truths
		Array[File] truths_allele
		Array[File] truths_position
		Array[File] truths_weights
	}

	call assoc_agg_wf.assoc_agg as allele_run {
		input:
			aggregate_type = "allele",
			genome_build = "hg19",
			input_gds_files = input_gds_files,
			null_model_file = null_model_file,
			out_prefix = "allele",
			phenotype_file = phenotype_file,
			test = "burden",
			variant_group_files = variant_group_files_coding,
			variant_include_files = variant_include_files
	}

	call verify_array.arraycheck_classic as allele_check {
		input:
			test = allele_run.assoc_combined,
			truth = truths_allele
	}
	
	call assoc_agg_wf.assoc_agg as position_run {
		input:
			aggregate_type = "position",
			alt_freq_max = 0.1,
			genome_build = "hg19",
			input_gds_files = input_gds_files,
			null_model_file = null_model_file,
			out_prefix = "position",
			phenotype_file = phenotype_file,
			test = "burden",
			variant_group_files = variant_group_files_genes,
			variant_include_files = variant_include_files
	}

	call verify_array.arraycheck_classic as position_check {
		input:
			test = position_run.assoc_combined,
			truth = truths_position
	}

	call assoc_agg_wf.assoc_agg as weights_run {
		input:
			aggregate_type = "allele",
			alt_freq_max = 0.1,
			genome_build = "hg19",
			input_gds_files = input_gds_files,
			null_model_file = null_model_file,
			out_prefix = "weights",
			phenotype_file = phenotype_file,
			test = "burden",
			variant_group_files = variant_group_files_coding,
			weight_user = "CADD"
	}

	call verify_array.arraycheck_classic as weights_check {
		input:
			test = weights_run.assoc_combined,
			truth = truths_weights
	}
}