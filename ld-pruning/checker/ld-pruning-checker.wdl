version 1.0

# Caveat programmator: Please be sure to read the readme on Github

import "https://raw.githubusercontent.com/DataBiosphere/analysis_pipeline_WDL/main/ld-pruning/ld-pruning.wdl" as test_run_ldpruning
import "https://raw.githubusercontent.com/dockstore/checker-WDL-templates/v1.1.0/checker_tasks/arraycheck_task.wdl" as verify_array
import "https://raw.githubusercontent.com/dockstore/checker-WDL-templates/v1.1.0/checker_tasks/filecheck_task.wdl" as verify_file

workflow checker_ldprune {
	input {
		# inputs
		Array[File] gds_with_unique_var_ids

		# checker-specific
		#File truth_defaults_info
		#File truth_nondefaults_info
		Array[File] truth_defaults_subset
		Array[File] truth_nondefaults_subset
		File truth_defaults_merged
		File truth_nondefaults_merged

		# used for testing non-defaults
		String option_nondefault_genome_build = "hg19"
		Float option_nondefault_ld_r_threshold = 0.3
		Float option_nondefault_ld_win_size = 10.1
		Float option_nondefault_maf_threshold = 0.05
		Float option_nondefault_missing_threshold = 0.02
		String? option_nondefault_out_prefix = "includePCA_hg19_10.1win_0.3r_0.05MAF_0.02missing"
		# exclude_pca_corr is not tested due to a bug in the CWL that makes comparison difficult

	}

	####################################
	#    ld-pruning-wf, non-default    #
	####################################

	####################################
	#   LD prune (RData) and subset    #
	####################################
	scatter(gds in gds_with_unique_var_ids) {
		call test_run_ldpruning.ld_pruning as nondef_step1_prune {
			input:
				gds_file = gds,
				genome_build = option_nondefault_genome_build,
				ld_r_threshold = option_nondefault_ld_r_threshold,
				ld_win_size = option_nondefault_ld_win_size,
				maf_threshold = option_nondefault_maf_threshold,
				missing_threshold = option_nondefault_missing_threshold,
				#exclude_pca_corr = option_nondefault_exclude_pca_corr,  # beware of CWL bug
				out_prefix = option_nondefault_out_prefix
		}
	}

	scatter(gds_n_varinc in zip(gds_with_unique_var_ids, nondef_step1_prune.ld_pruning_output)) {
		call test_run_ldpruning.subset_gds as nondef_step2_subset {
			input:
				gds_n_varinc = gds_n_varinc
		}
	}

	# # # # # # # # # # # # #
	#     md5 -- subset     #
	# # # # # # # # # # # # #
	call verify_array.arraycheck_classic as nondef_md5_subset {
		input:
			test = nondef_step2_subset.subset_output,
			truth = truth_nondefaults_subset
	}

	####################################
	#  Merge GDS and check merged GDS  #
	####################################
	call test_run_ldpruning.merge_gds as nondef_step3_merge {
		input:
			gdss = nondef_step2_subset.subset_output,
			out_prefix = option_nondefault_out_prefix

	}
	scatter(subset_gds in nondef_step2_subset.subset_output) {
		call test_run_ldpruning.check_merged_gds as nondef_step4_checkmerge {
			input:
				gds_file = subset_gds,
				merged_gds_file = nondef_step3_merge.merged_gds_output
		}
	}

	# # # # # # # # # # # # #
	#     md5 -- merged     #
	# # # # # # # # # # # # #
	call verify_file.filecheck as nondef_md5_merge {
		input:
			test = nondef_step3_merge.merged_gds_output,
			truth = truth_nondefaults_merged
	}

	####################################
	#      ld-pruning-wf, default      #
	####################################

	####################################
	#   LD prune (RData) and subset    #
	####################################
	scatter(gds in gds_with_unique_var_ids) {
		call test_run_ldpruning.ld_pruning as default_step1_prune {
			input:
				gds_file = gds
		}
	}
	scatter(gds_n_varinc in zip(gds_with_unique_var_ids, default_step1_prune.ld_pruning_output)) {
		call test_run_ldpruning.subset_gds as default_step2_subset {
			input:
				gds_n_varinc = gds_n_varinc
		}
	}

	# # # # # # # # # # # # #
	#     md5 -- subset     #
	# # # # # # # # # # # # #
	call verify_array.arraycheck_classic as default_md5_subset {
		input:
			test = default_step2_subset.subset_output,
			truth = truth_defaults_subset
	}

	####################################
	#  Merge GDS and check merged GDS  #
	####################################
	call test_run_ldpruning.merge_gds as default_step3_merge {
		input:
			gdss = default_step2_subset.subset_output
	}
	scatter(subset_gds in default_step2_subset.subset_output) {
		call test_run_ldpruning.check_merged_gds as default_step4_checkmerge {
			input:
				gds_file = subset_gds,
				merged_gds_file = default_step3_merge.merged_gds_output
		}
	}

	# # # # # # # # # # # # #
	#     md5 -- merged     #
	# # # # # # # # # # # # #
	call verify_file.filecheck as default_md5_merge {
		input:
			test = default_step3_merge.merged_gds_output,
			truth = truth_defaults_merged
	}

	meta {
		author: "Ash O'Farrell"
		email: "aofarrel@ucsc.edu"
	}
}
