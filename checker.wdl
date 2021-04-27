version 1.0

# Please be sure to read the caveats on Github

import "https://raw.githubusercontent.com/aofarrel/TOPMed_Pipeline_First_Step_WDL/master/vcf-to-gds-wf.wdl" as megastepA

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
		File truth_info
		Array[File] gds_truths

		# standard workflow
		Array[File] vcf_files
		Array[String] format = ["GT"]
		Boolean check_gds = true   #careful now...

		# standard workflow runtime attributes
		# [1] vcf2gds
		Int vcfgds_cpu = 1
		Int vcfgds_disk = 60
		Int vcfgds_memory = 4
		# [2] uniquevarids
		Int uniquevars_cpu = 1
		Int uniquevars_disk = 60
		Int uniquevars_memory = 4
		# [3] checkgds
		Int checkgds_cpu = 1
		Int checkgds_disk = 60
		Int checkgds_memory = 4

	}

	scatter(vcf_file in vcf_files) {
		call megastepA.vcf2gds {
			input:
				vcf = vcf_file,
				format = format,
				cpu = vcfgds_cpu,
				disk = vcfgds_disk,
				memory = vcfgds_memory
		}
	}
	
	call megastepA.unique_variant_id {
		input:
			gdss = vcf2gds.gds_output,
			cpu = uniquevars_cpu,
			disk = uniquevars_disk,
			memory = uniquevars_memory
	}
	
	if(check_gds) {
		scatter(gds in unique_variant_id.unique_variant_id_gds_per_chr) {
			call megastepA.check_gds {
				input:
					gds = gds,
					vcfs = vcf_files,
					cpu = checkgds_cpu,
					disk = checkgds_disk,
					memory = checkgds_memory
			}
		}
	}

	scatter(gds_test in unique_variant_id.unique_variant_id_gds_per_chr) {
		call md5sum {
			input:
				gds_test = gds_test,
				gds_truth = gds_truths,
				truth_info = truth_info
		}
	}


	meta {
		author: "Ash O'Farrell"
		email: "aofarrel@ucsc.edu"
	}
}