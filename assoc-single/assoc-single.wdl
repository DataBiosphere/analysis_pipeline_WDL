version 1.0

task check_enums {
	# WDL lacks the enum type, so this workaround will
	# stop the pipeline if any are incorrectly defined
	input {
		String? genome_build
		String? test_type
		# pass_only is enum in CWL, but it acts like a Bool
	}
	Boolean isdefined_genome = defined(genome_build)
	Boolean isdefined_test   = defined(test_type)
	
	command <<<
		set -eux -o pipefail

		python << CODE
		if isdefined_genome:
			if "~{genome_build}" not in ['hg19', 'hg38']:
				print("Invalid ref genome. Please only select either hg38 or hg19.")
				exit(1)
		if isdefined_test:
			if "~{test_type}" not in ['score', 'score.spa', 'BinomiRare']:
				print("Invalid test type. Please only select either score, score.spa, or BinomiRare.")
				exit(1)
		CODE
}

task define_segments_r {
	input {
		Int? segment_length
		Int? n_segments
		String? genome_build
	}
	
}

task assoc_single_r {
	
}

task assoc_combine_r {
	
}

task assoc_plots_r {
	
}

task sbg_gds_renamer {
	
}

task sbg_flatten_lists {
	
}

task sbg_prepare_segments_1 {
	
}

task sbg_group_segments_1 {
	
}