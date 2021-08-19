version 1.0

# Replace the first URL here with the URL of the workflow to be checked.
import "https://raw.githubusercontent.com/DataBiosphere/analysis_pipeline_WDL/implement-king/king.wdl" as check_me
import "https://raw.githubusercontent.com/aofarrel/checker-WDL-templates/v0.9.3/tasks/filecheck_task.wdl" as checker_file

workflow checker {
	input {
		# First set of inputs: The same input(s) as the workflow to be checked
		File gds_file

		# Second set of inputs: The truth file(s)
		File truth_king_ibdseg_output
		File truth_king_matrix
		File truth_kinship_plots

		# Optional inputs:
		#String king_ibdseg_out_prefix = "king_ibdseg"
		#Float sparse_threshold = 0.02209709
		#String king_to_matrix_out_prefix = "king_ibdseg_matrix"
		#String king_to_matrix_kinship_method = "king_ibdseg"
		#String kinship_plots_kinship_method = "king"


	}

	# Task 1 - gds2bed
	call check_me.gds2bed as gds2bed {
		input:
			gds_file = gds_file
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
			king_file = king_ibdseg.king_ibdseg_output
			#sparse_threshold = sparse_threshold,
			#out_prefix = king_to_matrix_out_prefix,
			#kinship_method = king_to_matrix_kinship_method
	}

	# Check output of Task 4 with provided Truth Files
	call checker_file.filecheck as check_task4_king_to_matrix {
		input:
			test = king_to_matrix.king_matrix,
			truth = truth_king_matrix
	}

	# Task 5 - kinship_plots
	call check_me.kinship_plots as kinship_plots {
		input:
			kinship_file = king_ibdseg.king_ibdseg_output
			#kinship_method = kinship_plots_kinship_method
	}

	# Check output of Task 5 with provided Truth Files
	call checker_file.filecheck as check_task5_kinship_plots {
		input:
			test = kinship_plots.kinship_plots,
			truth = truth_kinship_plots
	}

}
