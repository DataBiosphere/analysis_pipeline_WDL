version 1.0

import "king.wdl" as check_me
import "https://raw.githubusercontent.com/dockstore/checker-WDL-templates/v0.100.0/checker_tasks/filecheck_task.wdl" as checker_file

workflow checker {
	input {
		# First set of inputs: The same input(s) as the workflow to be checked
		File gds_file
		File sample_include_file

		# Second set of inputs: The truth file(s)
		File truth_king_ibdseg_output
		File truth_king_matrix
		File truth_kinship_plots
	}

	# Task 1 - gds2bed
	call check_me.gds2bed as gds2bed {
		input:
			gds_file = gds_file,
			sample_include_file = sample_include_file
	}

	# Task 2 - plink_make_bed
	call check_me.plink_make_bed as plink_make_bed {
		input:
			bedfile = gds2bed.processed_bed,
			bimfile = gds2bed.processed_bim,
			famfile = gds2bed.processed_fam
	}

	# Task 3 - king_ibdseg
	call check_me.king_ibdseg as king_ibdseg {
		input:
			bed_file = plink_make_bed.bed_file,
			bim_file = plink_make_bed.bim_file,
			fam_file = plink_make_bed.fam_file
			#out_prefix = king_ibdseg_out_prefix
	}

	# Check output of Task 3 with provided Truth Files
	call checker_file.filecheck as check_task3_king_ibdseg {
		input:
			test = king_ibdseg.king_ibdseg_output,
			truth = truth_king_ibdseg_output
	}

	# Task 4 - king_to_matrix
	call check_me.king_to_matrix as king_to_matrix {
		input:
			king_file = king_ibdseg.king_ibdseg_output,
			sample_include_file = sample_include_file
			#sparse_threshold = sparse_threshold,
			#out_prefix = king_to_matrix_out_prefix,
			#kinship_method = king_to_matrix_kinship_method
	}

	# Task 5 - kinship_plots
	call check_me.kinship_plots as kinship_plots {
		input:
			kinship_file = king_ibdseg.king_ibdseg_output,
			sample_include_file = sample_include_file
			#kinship_method = kinship_plots_kinship_method
	}

	# This checker does not check outputs from Tasks 4 and 5 due to the issue explained here:
	# https://github.com/DataBiosphere/analysis_pipeline_WDL/issues/51

}
