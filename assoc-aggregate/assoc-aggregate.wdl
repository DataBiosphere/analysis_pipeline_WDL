version 1.0

task wdl_validate_inputs {
	# WDL Only -- Validate inputs that are type enum in the CWL
	input {
		String? genome_build
		String? aggregate_type
		String? test
	}

	command <<<
		acceptable_genome_builds = ("hg38" "hg19")
		acceptable_aggreg_types = ("allele" "position")
		acceptable_test_values = ("burden" "skat" "smmat" "fastskat" "skato")
		
		# first do a defined check before doing this
		if [[ ! " ${acceptable_genome_builds}[*]} " =~ " ~{genome_build} " ]]
		then
			echo "Invalid input for genome_build. Must be hg38 or hg19."
			exit(1)
		fi
	>>>

	runtime {
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		preemptibles: 2
	}

}

task sbg_gds_renamer {
	# This tool renames GDS file in GENESIS pipelines if they contain suffixes after chromosome (chr##) in the filename.
 	# For example: If GDS file has name data_chr1_subset.gds the tool will rename GDS file to data_chr1.gds.
	input {
		File in_variant
	}
	Int gds_size= ceil(size(in_variant, "GB"))
	
	command <<<
		python << CODE
		import os
		def find_chromosome(file):
			chr_array = []
			chrom_num = split_on_chromosome(file)
			if(unicode(str(chrom_num[1])).isnumeric()):
				# two digit number
				chr_array.append(chrom_num[0])
				chr_array.append(chrom_num[1])
			else:
				# one digit number or Y/X/M
				chr_array.append(chrom_num[0])
			return "".join(chr_array)

		def split_on_chromosome(file):
			chrom_num = file.split("chr")[1]
			return chrom_num

		nameroot = os.path.basename(~{in_variant}).rsplit[".", 1][0]
		chr = find_chromosome(nameroot)
		base = nameroot.split('chr'+chr)[0]

		print(base+'chr'+chr+".gds")
		CODE
	>>>

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	#output {
	#	File renamed_variant
	#}
}

task define_segments_r {
	input {
		Int? segment_length
		Int? n_segments
		String? genome_build

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
# comes after define segs and gds renamer
task sbg_group_segments_1 {
	inputs {
		Array[File] assoc_files
	}

	output {
		Array[File} grouped_assoc_files
		chromosome
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
		Array[Float]? rho
		File? segment_file
		String? test # acts as enum
		File? variant_include_file
		String? weight_beta
		Int? segment
		String? aggregate_type # acts as enum
		Float? alt_freq_max
		Boolean? pass_only
		File? variant_weight_file
		String? weight_user
		String genome_build # acts as enum

		# runtime attr
		Int addldisk = 1
		Int cpu = 1
		Int memory = 8
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
	input {
		input_list

	}
}



workflow assoc_agg {
	input {
		Int? segment_length
		Int? n_segements
		String? genome_build
		String? aggregate_type
		String? test
		Array[File] input_gds_files
		Array[File]? variant_include_files
	}

	call wdl_validate_inputs {
		input:
			genome_build = genome_build,
			aggregate_type = aggregate_type,
			test = test
	}

	scatter(gds_file in input_gds_files) {
		call sbg_gds_renamer {
			input:
				in_variant = gds_file
		}
	}

	call define_segments_r {
		input:
			segment_length = segment_length,
			n_segments = n_segments,
			genome_build = genome_build
	}

	scatter(variant_group_file in variant_group_files) {
		call aggregate_list {
			input:
				variant_group_file = variant_group_file,
				aggregate_type = aggregate_type,
				group_id = group_id
		}
	}

	call sbg_prepare_segments_1 {
		input:
			input_gds_files = sbg_gds_renamer.renamed_variants,
			segments_file = define_segments_r.define_segments_output,
			aggregate_files = aggreagate_list.aggregate_list,
			variant_include_files = variant_include_files
	}

	# CWL uses a dotproduct scatter; this is the closest WDL equivalent
	scatter(chr_n_assocfiles in zip(sbg_group_segments_1.chromosome, sbg_group_segments_1.grouped_assoc_files)) {
		call assoc_combine_r {
			input:
				chr_n_assocfiles = chr_n_assocfiles,
				assoc_type = assoc_type
		}
	}

	meta {
		author: "Ash O'Farrell"
		email: "aofarrel@ucsc.edu"
	}
}
