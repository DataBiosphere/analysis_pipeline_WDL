version 1.0

# Caveat programmator: Please be sure to read the readme on Github
# If this workflow is run locally, there is a decent chance it will lock up Docker
# A Docker lockup is system-wide and persists outside Cromwell -- restart Docker to fix it

import "https://raw.githubusercontent.com/DataBiosphere/analysis_pipeline_WDL/v1.0.1/vcf-to-gds-wf.wdl" as megastepA
import "https://raw.githubusercontent.com/DataBiosphere/analysis_pipeline_WDL/implement-ld-pruning/ld-pruning-wf.wdl" as megastepB

task md5sumWFA {
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

task md5sumWFB {
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
		File truth_info
		Array[File] gds_truths

		# standard workflow
		Array[File] vcf_files
		Array[String] format = ["GT"]
		Boolean check_gds = true   #careful now...
	}

	scatter(vcf_file in vcf_files) {
		call megastepA.vcf2gds {
			input:
				vcf = vcf_file,
				format = format
		}
	}
	
	call megastepA.unique_variant_id {
		input:
			gdss = vcf2gds.gds_output
	}
	
	if(check_gds) {
		scatter(gds in unique_variant_id.unique_variant_id_gds_per_chr) {
			call megastepA.check_gds {
				input:
					gds = gds,
					vcfs = vcf_files
			}
		}
	}

	scatter(gds_test in unique_variant_id.unique_variant_id_gds_per_chr) {
		call md5sumWFA {
			input:
				gds_test = gds_test,
				gds_truth = gds_truths,
				truth_info = truth_info
		}
	}

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


	meta {
		author: "Ash O'Farrell"
		email: "aofarrel@ucsc.edu"
	}
}