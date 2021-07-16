version 1.0

task wdl_only__check_enums {
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
	>>>

	output {
		String wdl_only__enums_valid = "This string ensures check_enums executes first."
	}
}

task define_segments_r {
	input {
		Int? segment_length
		Int? n_segments
		String? genome_build
	}

	output {
		File config
		File define_segments_output
	}
	
}

task assoc_single_r {
	input {
		File gds_file
		File null_model_file
		File phenotype_file
		Float? mac_threshold
		Float? maf_threshold
		Boolean? pass_only
		File? segment_file
		String? test_type  # enum
		File? variant_include_file
		String? chromosome  # 1-24 | X | Y
		Int? segment
		# memory_gb and cpu are runtime vars in WDL
		Int? variant_block_size
		String? out_prefix
		String? genome_build  # enum
	}
	
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