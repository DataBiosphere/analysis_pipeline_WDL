version 1.0

# Caveat programmator: Please be sure to read the readme on Github

import "https://raw.githubusercontent.com/DataBiosphere/analysis_pipeline_WDL/v1.0.1/vcf-to-gds-wf.wdl" as workflowA
import "https://raw.githubusercontent.com/DataBiosphere/analysis_pipeline_WDL/implement-merge-gds/ld-pruning-wf.wdl" as workflowB

task md5sum {
	input {
		File gds_test
		Array[File] gds_truth
		File truth_info
	}

	command <<<

	set -eux -o pipefail

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

workflow checker {
	input {
		# checker-specific
		File wfA_truth_info
		Array[File] wfA_truth_gds
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




	meta {
		author: "Ash O'Farrell"
		email: "aofarrel@ucsc.edu"
	}
}