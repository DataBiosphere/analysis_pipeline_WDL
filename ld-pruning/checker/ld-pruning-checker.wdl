version 1.0

# Caveat programmator: Please be sure to read the readme on Github

import "https://raw.githubusercontent.com/DataBiosphere/analysis_pipeline_WDL/v7.1.1/ld-pruning/ld-pruning.wdl" as test_run_ldpruning

task md5sum {
	input {
		File test
		Array[File] truth
		File truth_info
		# having an input that depends upon a previous task's output reigns in
		# cromwell's tendencies to run tasks out of order
		File? enforce_chronological_order
	}

	command <<<

	set -eux -o pipefail

	echo "Information about these truth files:"
	head -n 3 "~{truth_info}"
	echo "The container version refers to the container used in applicable tasks in the WDL and is the important value here."
	echo "If container versions are equivalent, there should be no difference in GDS output between a local run and a run on Terra."
	
	md5sum ~{test} > sum.txt

	test_basename="$(basename -- ~{test})"
	echo "test file: ${test_basename}"

	for i in ~{sep=' ' truth}
	do
		truth_basename="$(basename -- ${i})"
		if [ "${test_basename}" == "${truth_basename}" ]; then
			actual_truth="$i"
			break
		fi
	done

	# must be done outside while and if or else `set -eux -o pipefail` is ignored
	echo "$(cut -f1 -d' ' sum.txt)" $actual_truth | md5sum --check

	touch previous_task_dummy_output
	>>>

	runtime {
		docker: "python:3.8-slim"
		memory: "2 GB"
		preemptible: 2
	}

	output {
		File enforce_chronological_order = "previous_task_dummy_output"
	}

}

workflow checker_ldprune {
	input {
		# inputs
		Array[File] gds_with_unique_var_ids

		# checker-specific
		File truth_defaults_info
		File truth_nondefaults_info
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
		#Boolean option_nondefault_exclude_pca_corr = false  # skipped due to CWL bug
		String? option_nondefault_out_prefix = "includePCA_hg19_10.1win_0.3r_0.05MAF_0.02missing"

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
	scatter(gds_test in nondef_step2_subset.subset_output) {
		call md5sum as nondef_md5_subset {
			input:
				test = gds_test,
				truth = truth_nondefaults_subset,
				truth_info = truth_nondefaults_info
		}
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
	call md5sum as nondef_md5_merge {
		input:
			test = nondef_step3_merge.merged_gds_output,
			truth = [truth_nondefaults_merged],
			truth_info = truth_nondefaults_info,
			enforce_chronological_order = nondef_md5_subset.enforce_chronological_order[0]

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
	scatter(gds_test in default_step2_subset.subset_output) {
		call md5sum as default_md5_subset {
			input:
				test = gds_test,
				truth = truth_defaults_subset,
				truth_info = truth_defaults_info,
				enforce_chronological_order = nondef_md5_merge.enforce_chronological_order
		}
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
	call md5sum as default_md5_merge {
		input:
			test = default_step3_merge.merged_gds_output,
			truth = [truth_defaults_merged],
			truth_info = truth_defaults_info,
			enforce_chronological_order = default_md5_subset.enforce_chronological_order[0]
	}

	meta {
		author: "Ash O'Farrell"
		email: "aofarrel@ucsc.edu"
	}
}
