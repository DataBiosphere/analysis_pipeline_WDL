version 1.0

# Caveat programmator: Please be sure to read the readme on Github
# If this workflow is run locally, there is a decent chance it will lock up Docker
# A Docker lockup is system-wide and persists outside Cromwell -- restart Docker to fix it

import "https://raw.githubusercontent.com/DataBiosphere/analysis_pipeline_WDL/v1.0.1/vcf-to-gds-wf.wdl" as megastepA
import "https://raw.githubusercontent.com/DataBiosphere/analysis_pipeline_WDL/implement-ld-pruning/ld-pruning-wf.wdl" as megastepB

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
		File wfB_truth_info
		Array[File] wfA_truth_gds
		Array[File] wfB_truth_subset

		# standard workflow
		Array[File] wfA_test_vcfs
		Boolean wfA_option_check_gds = true   #careful now...
	}

	scatter(wfA_test_vcf in wfA_test_vcfs) {
		call megastepA.vcf2gds {
			input:
				vcf = wfA_test_vcf
		}
	}
	
	call megastepA.unique_variant_id {
		input:
			gdss = vcf2gds.gds_output
	}
	
	if(wfA_option_check_gds) {
		scatter(gds in unique_variant_id.unique_variant_id_gds_per_chr) {
			call megastepA.check_gds {
				input:
					gds = gds,
					vcfs = wfA_test_vcfs
			}
		}
	}

	#scatter(wfA_gds_test in unique_variant_id.unique_variant_id_gds_per_chr) {
	#	call md5sum {
	#		input:
	#			gds_test = wfA_gds_test,
	#			gds_truth = wfA_truth_gds,
	#			truth_info = wfA_truth_info
	#	}
	#}

	# For ld prune and subset, test that variant_include_file works by running an extra time
	# on just chr3, as it can only take in one such file and will error on other chrs.

	# Don't forget to compare running with and without the sample_include_file

	scatter(gds in unique_variant_id.unique_variant_id_gds_per_chr) {
		call megastepB.ld_pruning {
			input:
				gds = gds
		}
	}

	scatter(gds_n_varinc in zip(unique_variant_id.unique_variant_id_gds_per_chr, ld_pruning.ld_pruning_output)) {
		call megastepB.subset_gds {
			input:
				gds_n_varinc = gds_n_varinc
		}
	}

	scatter(wfB_gds_test in subset_gds.subset_output) {
		call md5sum {
			input:
				gds_test = wfB_gds_test,
				gds_truth = wfB_truth_subset,
				truth_info = wfB_truth_info
		}
	}


	meta {
		author: "Ash O'Farrell"
		email: "aofarrel@ucsc.edu"
	}
}