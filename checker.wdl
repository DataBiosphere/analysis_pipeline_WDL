version 1.0

# Caveat programmator: Please be sure to read the readme on Github
# If this workflow is run locally, there is a decent chance it will lock up Docker
# A Docker lockup is system-wide and persists outside Cromwell -- restart Docker to fix it

import "https://raw.githubusercontent.com/DataBiosphere/analysis_pipeline_WDL/v1.0.1/vcf-to-gds-wf.wdl" as workflowA
import "https://raw.githubusercontent.com/DataBiosphere/analysis_pipeline_WDL/implement-merge-gds/ld-pruning-wf.wdl" as workflowB

task md5sum {
	input {
		File gds_test
		Array[File] gds_truth
		File truth_info
	}

	command <<<

	echo "Information about these truth files:"
	head -n 3 "~{truth_info}"
	echo "The container version refers to the container used in applicable tasks in the WDL and is the important value here."
	echo "If container versions are equivalent, there should be no difference in GDS output between a local run and a run on Terra."
	
	md5sum ~{gds_test} > sum.txt
	test_basename="$(basename -- ~{gds_test})"
	echo "test file: ${test_basename}"
	echo "truth file(s): ~{sep=' ' gds_truth}"

	for i in ~{sep=' ' gds_truth}
	do
		truth_basename="$(basename -- ${i})"
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

workflow checker {
	input {
		# checker-specific
		File wfA_truth_info
		File wfB_truth_defaults_info
		File wfB_truth_nondefaults_info
		Array[File] wfA_truth_gds
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

		# standard workflow
		Array[File] wfA_test_vcfs
		Boolean wfA_option_check_gds = true   #careful now...
		Array[String] wfA_option_format
	}



	####################################
	#            Workflow A            #
	#           vcf-to-gds-wf          #
	####################################
	scatter(wfA_test_vcf in wfA_test_vcfs) {
		call workflowA.vcf2gds {
			input:
				vcf = wfA_test_vcf,
				format = wfA_option_format
		}
	}
	call workflowA.unique_variant_id {
		input:
			gdss = vcf2gds.gds_output
	}
	if(wfA_option_check_gds) {
		scatter(gds in unique_variant_id.unique_variant_id_gds_per_chr) {
			call workflowA.check_gds {
				input:
					gds = gds,
					vcfs = wfA_test_vcfs
			}
		}
	}

	# # # # # # # # # # # # #
	#        Checker        #
	# # # # # # # # # # # # #
	scatter(wfA_gds_test in unique_variant_id.unique_variant_id_gds_per_chr) {
		call md5sum as md5sum_wfA {
			input:
				gds_test = wfA_gds_test,
				gds_truth = wfA_truth_gds,
				truth_info = wfA_truth_info
		}
	}

	####################################
	#            Workflow B            #
	#      ld-pruning-wf, default      #
	####################################
	scatter(gds in unique_variant_id.unique_variant_id_gds_per_chr) {
		call workflowB.ld_pruning as prune_defaults {
			input:
				gds_file = gds
		}
	}
	scatter(gds_n_varinc in zip(unique_variant_id.unique_variant_id_gds_per_chr, prune_defaults.ld_pruning_output)) {
		call workflowB.subset_gds as subset_defaults {
			input:
				gds_n_varinc = gds_n_varinc
		}
	}
	call workflowB.merge_gds as merge_defaults {
		input:
			gdss = subset_defaults.subset_output
	}
	scatter(subset_gds in subset_defaults.subset_output) {
		call workflowB.check_merged_gds as check_merged_defaults {
			input:
				gds_file = subset_gds,
				merged_gds_file = merge_defaults.merged_gds_output
		}
	}

	# # # # # # # # # # # # #
	#        Checker        #
	# # # # # # # # # # # # #
	scatter(wfB_gds_test in subset_defaults.subset_output) {
		call md5sum as md5sum_wfB_defaults {
			input:
				gds_test = wfB_gds_test,
				gds_truth = wfB_truth_defaults_subset,
				truth_info = wfB_truth_defaults_info
		}
	}
	call md5sum as md5sum_wfB_defaults_merge {
		input:
			gds_test = merge_defaults.merged_gds_output,
			gds_truth = [wfB_truth_defaults_merged],
			truth_info = wfB_truth_defaults_info
	}

	####################################
	#            Workflow B            #
	#    ld-pruning-wf, non-default    #
	####################################
	scatter(gds in unique_variant_id.unique_variant_id_gds_per_chr) {
		call workflowB.ld_pruning as prune_nondefaults {
			input:
				gds_file = gds,
				genome_build = wfB_option_nondefault_genome_build,
				ld_r_threshold = wfB_option_nondefault_ld_r_threshold,
				ld_win_size = wfB_option_nondefault_ld_win_size,
				maf_threshold = wfB_option_nondefault_maf_threshold,
				missing_threshold = wfB_option_nondefault_missing_threshold,
				exclude_pca_corr = wfB_option_nondefault_exclude_pca_corr,
				out_prefix = wfB_option_nondefault_out_prefix
		}
	}
	scatter(gds_n_varinc in zip(unique_variant_id.unique_variant_id_gds_per_chr, prune_nondefaults.ld_pruning_output)) {
		call workflowB.subset_gds as subset_nondefaults {
			input:
				gds_n_varinc = gds_n_varinc
		}
	}
	call workflowB.merge_gds as merge_nondefaults {
		input:
			gdss = subset_nondefaults.subset_output,
			out_prefix = wfB_option_nondefault_out_prefix
	}
	scatter(subset_gds in subset_nondefaults.subset_output) {
		call workflowB.check_merged_gds as check_merged_nondefaults {
			input:
				gds_file = subset_gds,
				merged_gds_file = merge_nondefaults.merged_gds_output
		}
	}

	# # # # # # # # # # # # #
	#        Checker        #
	# # # # # # # # # # # # #
	scatter(wfB_gds_test in subset_nondefaults.subset_output) {
		call md5sum as md5sum_wfB_nondefaults {
			input:
				gds_test = wfB_gds_test,
				gds_truth = wfB_truth_nondefaults_subset,
				truth_info = wfB_truth_nondefaults_info
		}
	}
	call md5sum as md5sum_wfB_nondefaults_merge {
		input:
			gds_test = merge_nondefaults.merged_gds_output,
			gds_truth = [wfB_truth_nondefaults_merged],
			truth_info = wfB_truth_nondefaults_info
	}
	





	meta {
		author: "Ash O'Farrell"
		email: "aofarrel@ucsc.edu"
	}
}