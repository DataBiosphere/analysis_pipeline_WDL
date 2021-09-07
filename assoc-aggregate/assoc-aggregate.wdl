version 1.0

task define_segments_r {
	input {
		segment_length
		n_segments
		String genome_build

		# runtime attributes
		Int addldisk = 1
		Int cpu = 2
		Int memory = 4
		Int preempt = 3
	}
	command {
	}

	Int finalDiskSize = 10
	
	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		File config_file = "define_segments_r.config"
		File define_segments_output = ""
	}
}

task aggregate_list {
	input {
		File variant_group_file
		String aggregate_type
		String group_id

		# runtime attr
		Int addldisk = 1
		Int cpu = 2
		Int memory = 4
		Int preempt = 2
	}
	command <<<
		set -eux -o pipefail
	>>>
	# Estimate disk size required
	Int vargroup_size = ceil(size(variant_group_file, "GB"))
	Int finalDiskSize = vargroup_size + addldisk

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		Array[File] unique_variant_id_gds_per_chr = glob("*.gds")
		File config_file = "unique_variant_ids.config"
	}
}

task assoc_aggregate {
	input {
		File gds_file
		File null_model_file
		File phenotype_file
		File aggregate_variant_file
		String? out_prefix
		rho
		File segment_file
		test
		File variant_include_file
		weight_beta
		segment
		String aggregate_type
		alt_freq_max
		pass_only
		variant_weight_file
		weight_user
		String genome_build

		# runtime attr
		Int addldisk = 1
		Int cpu = 8
		Int memory = 12
		Int preempt = 0
	}

	command <<<
	>>>

	# Estimate disk size required
	select_first([ceil(size(sample_include_file, "GB")), 0])

	Int gds_size = ceil(size(gds, "GB"))

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + finalDiskSize + " SSD"
		bootDiskSizeGb: 6
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		File config_file = "check_gds.config"
	}
}

task sbg_prepare_segments_1 {
	input {
		Array[File] input_gds_files
		File segments_file
		Array[File] aggregate_files
		Array[File] variant_include_files
	}
}

task sbg_flatten_lists {
	inputs {
		input_list

	}
}

workflow assoc_agg {
	input {
	}

	output {
		
	}

	meta {
		author: "Ash O'Farrell"
		email: "aofarrel@ucsc.edu"
	}
}
