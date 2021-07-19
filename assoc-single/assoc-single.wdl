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


# order on SB seems to be
# 1. sbg_gds_renamer
# 2. define_segments_r
# 3. sbg_prepare_segments_1
# 4. assoc_single_r
# 5. sbg_flatten_lists
# 6. sbg_group_segments_1
# 7. assoc_combine_r
# 8. assoc_plots_r

# order in Python seems to be (excludes the job that doesn't happen in single)
# for chr in chr list
#   1. assoc
#   2. combine
# 3. assoc_plots
# 4. assoc_report
# 5. post_analysis

# SB:assoc_single_r probably correlates with py:assoc
# SB:assoc_combine_r probably correlates with py:combine
# SB:assoc_plots_r probably correlates with py:assoc_plots
# SB seems to lack anything for assoc_report and post_analysis so we can prob skip those

