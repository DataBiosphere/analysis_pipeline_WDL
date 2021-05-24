version 1.0

# Caveat programmator: Please be sure to read the readme on Github
# WARNING: If you do not change the settings here, this pipeline is DESIGNED TO FAIL.

task md5sum {
	input {
		File test
		Array[File] truth
		File? dummyfile
	}

	command <<<

	set -eux -o pipefail


	# truth info file would go here


	md5sum ~{test} > sumbefore.txt
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

	touch dummyfile.txt
	>>>

	runtime {
		docker: "python:3.8-slim"
		memory: "2 GB"
		preemptible: 2
	}

	output {
		File dummy = "dummyfile.txt"
	}

}

workflow debug {
	input {

		# checker-specific
		Array[File] wfB_truth_nondefaults_RData
		Array[File] wfB_truth_nondefaults_subset
		File wfB_truth_nondefaults_merged

		# debug - manually created test files
		Array[File] test_rdata
		Array[File] test_subset
		File test_merged
	}



	####################################
	#            Workflow B            #
	#    ld-pruning-wf, non-default    #
	####################################

	# # # # # # # # # # # # #
	#      md5 -- RData     #
	# # # # # # # # # # # # #

	scatter(test_rdata in test_rdata) {
		call md5sum as md5_nondef_1_rdata {
			input:
				test = test_rdata,
				truth = wfB_truth_nondefaults_RData,
		}
	}

	# # # # # # # # # # # # #
	#     md5 -- subset     #
	# # # # # # # # # # # # #
	scatter(test_subset in test_subset) {
		call md5sum as md5_nondef_2_subset {
			input:
				test = test_subset,
				truth = wfB_truth_nondefaults_subset,
				dummyfile = md5_nondef_1_rdata.dummy[0],
		}
	}

	# # # # # # # # # # # # #
	#     md5 -- merged     #
	# # # # # # # # # # # # #
	call md5sum as md5_nondef_3_merge {
		input:
			test = test_merged,
			truth = [wfB_truth_nondefaults_merged],
			dummyfile = md5_nondef_2_subset.dummy[0]
	}
}