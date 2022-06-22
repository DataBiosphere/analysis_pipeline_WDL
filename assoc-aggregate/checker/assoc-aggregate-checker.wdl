version 1.0
import "https://raw.githubusercontent.com/DataBiosphere/analysis_pipeline_WDL/v7.1.2/assoc-aggregate/assoc-aggregate.wdl" as assoc_agg_wf
#import "../assoc-aggregate.wdl" as assoc_agg_wf # use this if you want to test a local version
import "https://raw.githubusercontent.com/dockstore/checker-WDL-templates/v1.1.0/checker_tasks/arraycheck_task.wdl" as verify_array

workflow aggie_checker {
	# If run as-is, this checker workflow will go through four configurations.
	# And it should indeed be run as-is, unless you wish to remove a task entirely, and/or
	# are willing to create new truth files. Even if you change something small like 
	# n_segments, without remaking the truth files, you will likely get a mismatch.
	#
	# The one exception to this are runtime attributes (disk size, memory, preempts, etc)
	# but even then, I recommend against swapping out the Docker image. That being said,
	# truth files generated on 2.12.0 seem to pass against test files generated on 2.10.0
	input {
		Array[File]  input_gds_files
		File         null_model_file
		File         phenotype_file
		Array[File]  variant_group_files_coding # used for weights_test and allele_test
		Array[File]  variant_group_files_genes  # used for position_test only
		Array[File]  variant_include_files

		# variant_weight_file is not included in any of the assoc-aggregate configs
		# see: https://github.com/UW-GAC/analysis_pipeline/search?q=variant_weights

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
			truth = truths_allele,
			rdata_check = true
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
			truth = truths_position,
			rdata_check = true
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
			truth = truths_weights,
			rdata_check = true
	}
}