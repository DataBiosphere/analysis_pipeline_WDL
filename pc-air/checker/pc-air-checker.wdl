version 1.0

import "../pc-air.wdl" as pcair_wf
import "https://raw.githubusercontent.com/dockstore/checker-WDL-templates/v0.100.0/checker_tasks/filecheck_task.wdl" as verify_file

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
		File truth_related_file
		File truth_unrelated_file
		File truth_pcair_output
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

	call verify_file.filecheck as check_related {
		input:
			test  = pcair.out_related_file,
			truth = truth_related_file
	}

	call verify_file.filecheck as check_unrelated {
		input:
			test  = pcair.out_unrelated_file,
			truth = truth_unrelated_file
	}

	call verify_file.filecheck as check_pcair {
		input:
			test  = pcair.pcair_output,
			truth = truth_pcair_output,
			tolerance = 0.01
	}

	output {
		File related_check   = check_related.report
		File unrelated_check = check_related.report
		File pcair_check     = check_pcair.report
	}

	meta {
		author: "Julian Lucas"
		email: "juklucas@ucsc.edu"
	}
}