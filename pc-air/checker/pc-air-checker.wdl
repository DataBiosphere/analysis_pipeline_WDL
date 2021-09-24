version 1.0

import "../pc-air.wdl" as pcair_wf

workflow checker_pcair {
	input {
		# parent inputs
		File kinship_file
		File gds_file
		Array[File] gds_file_full

		String? out_prefix
		File? divergence_file
		File? sample_include_file
		File? variant_include_file
		File? phenotype_file
		Int? n_pairs
		Int? n_corr_vars
		Int? n_pcs
		Int? n_pcs_plot
		Int? n_perpage
		String? group
		Boolean run_correlation

		# checker-specific inputs
		Array[File] truth_files
	}

	# Run the workflow to be checked
	call pcair_wf.pcair as pcair {
		input:
			kinship_file = kinship_file,
			gds_file = gds_file,
			gds_file_full = gds_file_full,
			out_prefix = out_prefix,
			divergence_file = divergence_file,
			sample_include_file = sample_include_file,
			variant_include_file = variant_include_file,
			phenotype_file = phenotype_file,
			n_pairs = n_pairs,
			n_corr_vars = n_corr_vars,
			n_pcs = n_pcs,
			n_pcs_plot = n_pcs_plot,
			n_perpage = n_perpage,
			group = group,
			run_correlation = run_correlation
	}

	Array[File] non_gds_output   = [pcair.out_unrelated_file, pcair.out_related_file, pcair.pcair_output]
	Array[File] aggregate_output = flatten(select_all([pcair.pca_corr_gds, non_gds_output]))
	
	call filecheck_array {
		input:
			test_files = aggregate_output,
			truth_files = truth_files
	}

	output {
		File checker_output = filecheck_array.checker_output
	}

	meta {
		author: "Julian Lucas"
		email: "juklucas@ucsc.edu"
	}
}

task filecheck_array {
	input {
		Array[File] truth_files
		Array[File] test_files
		
		# runtime attributes
		Int addldisk = 5
		Int cpu = 2
		Int memory = 4
		Int preempt = 3
	}

	# Estimate disk size required
	Int truth_size    = ceil(size(truth_files, "GB"))
	Int test_size     = ceil(size(test_files, "GB"))
	Int final_disk_dize =  truth_size + test_size + 10
	

	command <<<
		set -eux -o pipefail

		## Pull last test file
		last_test_file_pos=$((${#test_files[@]} - 1))
		last_test_file_name="$(basename -- ${test_files[$last_test_file_pos]})"

		## Check all test files
		for truth_file in "${truth_files[@]}" 
		do
			truth_file_name="$(basename -- $truth_file)"

			## Loop through test files
			for test_file in "${test_files[@]}" 
			do
				test_file_name="$(basename -- $test_file)"	
				
				## If filenames match, compare MD5s
				if [[ $truth_file_name == $test_file_name ]]; 
				then
					md5_truth=$(md5 $truth_file | awk '{print $4}')
					md5_test=$(md5 $test_file | awk '{print $4}')

					if [[ $md5_truth == $md5_test ]]; 
					then
						echo "$test_file_name md5 matches" | tee -a checker_output.txt
					else
						echo "CHECKING ERROR: MD5 MISMATCH $test_file_name md5 mismatch" | tee -a checker_output.txt
					fi
					break
				## If there isn't a match and its the last element, we cannot find a test
				## file that matches the truth file	
				elif [[ $test_file_name == $last_test_file_name ]];
				then
					echo "CHECKING ERROR: FILE NOT FOUND $truth_file_name not found" | tee -a checker_output.txt
				fi
			done
		done

	>>>

	runtime {
		cpu: cpu
		docker: "quay.io/aofarrel/rchecker:1.1.0"
		disks: "local-disk " + final_disk_dize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		File checker_output = "checker_output.txt"
	}

}