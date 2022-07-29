version 1.0

# Caveat programmator: Please be sure to read the readme on Github

import "https://raw.githubusercontent.com/DataBiosphere/analysis_pipeline_WDL/main/vcf-to-gds/vcf-to-gds.wdl" as test_run_vcftogds

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

	>>>

	runtime {
		docker: "python:3.8-slim"
		memory: "2 GB"
		preemptible: 2
	}

}

workflow checker_vcftogds {
	input {
		# checker-specific
		File truth_info
		Array[File] truth_gds
		# standard workflow
		Array[File] test_vcfs
		Boolean option_check_gds = true   #careful now...
		Array[String] option_format
	}



	####################################
	#           vcf-to-gds-wf          #
	####################################
	scatter(test_vcf in test_vcfs) {
		call test_run_vcftogds.vcf2gds {
			input:
				vcf = test_vcf,
				format = option_format
		}
	}
	call test_run_vcftogds.unique_variant_id {
		input:
			gdss = vcf2gds.gds_output
	}
	if(option_check_gds) {
		scatter(gds in unique_variant_id.unique_variant_id_gds_per_chr) {
			call test_run_vcftogds.check_gds {
				input:
					gds = gds,
					vcfs = test_vcfs
			}
		}
	}

	# # # # # # # # # # # # #
	#        Checker        #
	# # # # # # # # # # # # #
	scatter(test in unique_variant_id.unique_variant_id_gds_per_chr) {
		call md5sum as md5sum {
			input:
				test = test,
				truth = truth_gds,
				truth_info = truth_info
		}
	}




	meta {
		author: "Ash O'Farrell"
		email: "aofarrel@ucsc.edu"
	}
}
