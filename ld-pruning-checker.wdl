version 1.0

# Caveat programmator: Please be sure to read the readme on Github
# WARNING: If exclude_pca_corr is False, the truth files derived from SB WILL FAIL due to a CWL bug

import "https://raw.githubusercontent.com/DataBiosphere/analysis_pipeline_WDL/v1.0.1/vcf-to-gds-wf.wdl" as workflowA
import "https://raw.githubusercontent.com/DataBiosphere/analysis_pipeline_WDL/implement-merge-gds/ld-pruning-wf.wdl" as workflowB

task md5sum {
	input {
		File test
		Array[File] truth
		File truth_info
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
	echo "truth file(s): ~{sep=' ' truth}"

	for i in ~{sep=' ' truth}
	do
		truth_basename="$(basename -- ${i})"
		echo "$(basename -- ${i})"
		if [ "${test_basename}" == "${truth_basename}" ]; then
			echo "$(cut -f1 -d' ' sum.txt)" ${i} | md5sum --check
		fi
	done
	>>>

	runtime {
		docker: "python:3.8-slim"
		memory: "2 GB"
		preemptible: 2
	}

}

workflow checker_ldprune {
	input {
		# inputs
		Array[File] gds_with_unique_var_ids

		# checker-specific
		File wfB_truth_defaults_info
		File wfB_truth_nondefaults_info
		Array[File] wfB_truth_nondefaults_RData  # only for nondefaults
		Array[File] wfB_truth_defaults_subset
		Array[File] wfB_truth_nondefaults_subset
		File wfB_truth_defaults_merged
		File wfB_truth_nondefaults_merged

		# used for testing non-defaults
		String wfB_option_nondefault_genome_build = "hg19"
		Float wfB_option_nondefault_ld_r_threshold = 0.3
		Float wfB_option_nondefault_ld_win_size = 10.1
		Float wfB_option_nondefault_maf_threshold = 0.05
		Float wfB_option_nondefault_missing_threshold = 0.02
		Boolean wfB_option_nondefault_exclude_pca_corr = false
		String? wfB_option_nondefault_out_prefix = "includePCA_hg19_10.1win_0.3r_0.05MAF_0.02missing"

	}

	####################################
	#            Workflow B            #
	#      ld-pruning-wf, default      #
	####################################

	####################################
	#   LD prune (RData) and subset    #
	####################################
	scatter(gds in gds_with_unique_var_ids) {
		call workflowB.ld_pruning as default_step1_prune {
			input:
				gds_file = gds
		}
	}
	scatter(gds_n_varinc in zip(gds_with_unique_var_ids, default_step1_prune.ld_pruning_output)) {
		call workflowB.subset_gds as default_step2_subset {
			input:
				gds_n_varinc = gds_n_varinc
		}
	}

	# # # # # # # # # # # # #
	#     md5 -- subset     #
	# # # # # # # # # # # # #
	scatter(wfB_gds_test in default_step2_subset.subset_output) {
		call md5sum as default_md5_1_subset {
			input:
				test = wfB_gds_test,
				truth = wfB_truth_defaults_subset,
				truth_info = wfB_truth_defaults_info
		}
	}

	####################################
	#  Merge GDS and check merged GDS  #
	####################################
	call workflowB.merge_gds as default_step3_merge {
		input:
			gdss = default_step2_subset.subset_output
	}
	scatter(subset_gds in default_step2_subset.subset_output) {
		call workflowB.check_merged_gds as default_step4_checkmerge {
			input:
				gds_file = subset_gds,

				merged_gds_file = default_step3_merge.merged_gds_output
		}
	}

	# # # # # # # # # # # # #
	#     md5 -- merged     #
	# # # # # # # # # # # # #
	call md5sum as default_md5_2_merge {
		input:
			test = default_step3_merge.merged_gds_output,
			truth = [wfB_truth_defaults_merged],
			truth_info = wfB_truth_defaults_info
	}

	####################################
	#            Workflow B            #
	#    ld-pruning-wf, non-default    #
	####################################

	####################################
	#     LD prune (generate RData)    #
	####################################
	scatter(gds in gds_with_unique_var_ids) {
		call workflowB.ld_pruning as nondef_step1_prune {
			input:
				gds_file = gds,
				genome_build = wfB_option_nondefault_genome_build,
				ld_r_threshold = wfB_option_nondefault_ld_r_threshold,
				ld_win_size = wfB_option_nondefault_ld_win_size,
				maf_threshold = wfB_option_nondefault_maf_threshold,
				missing_threshold = wfB_option_nondefault_missing_threshold,
				exclude_pca_corr = wfB_option_nondefault_exclude_pca_corr,  # bugged
				out_prefix = wfB_option_nondefault_out_prefix
		}
	}

	# # # # # # # # # # # # #
	#      md5 -- RData     #
	# # # # # # # # # # # # #
	# Yes, it's true, the non-defaults case has an extra check
	# This is because the CWL handles exclude_pca_corr oddly
	scatter(wfB_gds_test in nondef_step1_prune.ld_pruning_output) {
		call md5sum as md5_nondef_1_rdata {
			input:
				test = wfB_gds_test,
				truth = wfB_truth_nondefaults_subset,
				truth_info = wfB_truth_nondefaults_info
		}
	}

	####################################
	#     subset GDS based on RData    #
	####################################
	scatter(gds_n_varinc in zip(gds_with_unique_var_ids, nondef_step1_prune.ld_pruning_output)) {
		call workflowB.subset_gds as nondef_step2_subset {
			input:
				gds_n_varinc = gds_n_varinc
		}
	}

	# # # # # # # # # # # # #
	#     md5 -- subset     #
	# # # # # # # # # # # # #
	scatter(wfB_gds_test in nondef_step2_subset.subset_output) {
		call md5sum as md5_nondef_2_subset {
			input:
				test = wfB_gds_test,
				truth = wfB_truth_nondefaults_subset,
				truth_info = wfB_truth_nondefaults_info
		}
	}

	####################################
	#  Merge GDS and check merged GDS  #
	####################################
	call workflowB.merge_gds as nondef_step3_merge {
		input:
			gdss = nondef_step2_subset.subset_output,
			out_prefix = wfB_option_nondefault_out_prefix
	}
	scatter(subset_gds in nondef_step2_subset.subset_output) {
		call workflowB.check_merged_gds as nondef_step4_checkmerge {
			input:
				gds_file = subset_gds,
				merged_gds_file = nondef_step3_merge.merged_gds_output
		}
	}

	# # # # # # # # # # # # #
	#     md5 -- merged     #
	# # # # # # # # # # # # #
	call md5sum as md5_nondef_3_merge {
		input:
			test = nondef_step3_merge.merged_gds_output,
			truth = [wfB_truth_nondefaults_merged],
			truth_info = wfB_truth_nondefaults_info
	}
}