version 1.0

task wdl_validate_inputs {
	# WDL Only -- Validate inputs that are type enum in the CWL
	input {
		String? genome_build
		String? aggregate_type
		String? test
	}

	command <<<
		set -eux -o pipefail
		acceptable_genome_builds=("hg38" "hg19")
		acceptable_aggreg_types=("allele" "position")
		acceptable_test_values=("burden" "skat" "smmat" "fastskat" "skato")
		
		#if [[ ~{genome_build} = "" ]]
		# first do a defined check before doing this
		if [[ ! "${acceptable_genome_builds}[*]}" =~ "~{genome_build}" ]]
		then
			echo "Invalid input for genome_build. Must be hg38 or hg19."
			exit 1
		fi
		if [[ ! " ${acceptable_aggreg_types}[*]} " =~ " ~{aggregate_type} " ]]
		then
			echo "Invalid input for aggregate_type. Must be allele or position."
			exit 1
		fi

		# do other checks!
	>>>

	runtime {
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		preemptibles: 2
	}

	output {
		String? valid_genome_build = genome_build
		String? valid_aggregate_type = aggregate_type
		String? valid_test = test
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

		nameroot = os.path.basename("~{in_variant}").rsplit[".", 1][0]
		chr = find_chromosome(nameroot)
		base = nameroot.split('chr'+chr)[0]

		print(base+'chr'+chr+".gds")
		CODE

		touch foo.txt
	>>>

	runtime {
		cpu: 2
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + gds_size + " HDD"
		memory: "4 GB"
		preemptibles: 2
	}
	output {
		File renamed_variants = "foo.txt"
	}
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
		touch foo.txt
		touch define_segments_r.config
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
		File define_segments_output = "foo.txt"
	}
}

# This task is probably not strictly necessary in WDL, as WDL can handle lists of lists better than CWL.
# Nevertheless, it is in this WDL to ensure compatiability with the CWL version.
task sbg_flatten_lists {
	input {
		Array[File] input_list
	}

	command {
		pass
	}

	output {
		Array[File] output_list = input_list
	}
}
# comes after define segs and gds renamer
task sbg_group_segments_1 {
	input {
		Array[File] assoc_files
	}

	command {
		touch foo.txt
		touch bar.txt
		touch bizz.txt
	}

	output {
		Array[File] grouped_assoc_files = ["foo.txt", "bar.txt"]
		Array[String] chromosome = ["foo", "bar"]
		File gds_output = "bizz.txt"
	}
}

task aggregate_list {
	input {
		File variant_group_file
		String? aggregate_type
		String? out_file
		String? group_id

		# runtime attr
		Int addldisk = 1
		Int cpu = 2
		Int memory = 4
		Int preempt = 2
	}
	# Basenames
	File basename_vargroup = basename(variant_group_file)
	# Estimate disk size required
	Int vargroup_size = ceil(size(variant_group_file, "GB"))
	Int finalDiskSize = vargroup_size + addldisk
	command <<<
		set -eux -o pipefail

		cp ~{variant_group_file} ~{basename_vargroup}

		#Rscript /usr/local/analysis_pipeline/R/aggregate_list.R aggregate_list.config
	>>>

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		File aggregate_list = glob("*.RData")[0]
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
		String? genome_build # acts as enum

		# runtime attr
		Int addldisk = 1
		Int cpu = 1
		Int memory = 8
		Int preempt = 0
	}
	# Estimate disk size required
	Int varweight_size = select_first([ceil(size(variant_weight_file, "GB")), 0])
	Int gds_size = ceil(size(gds_file, "GB"))
	Int finalDiskSize = gds_size + varweight_size

	command <<<
		touch foo.txt
		touch bar.txt
	>>>

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + finalDiskSize + " SSD"
		bootDiskSizeGb: 6
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		Array[File] assoc_aggregate = ["foo.txt", "bar.txt"]
	}
}

task sbg_prepare_segments_1 {
	input {
		Array[File] input_gds_files
		File segments_file
		Array[File] aggregate_files
		Array[File]? variant_include_files
	}
	command {
		touch foo.txt
	}

	output {
		File gds_output = "foo.txt"
		Array[Int]? segments = [1,2]
		File aggregate_output = "foo.txt" # seems optional in CWL but WDL is pickier
		File variant_include_output = "foo.txt" # again, may be optional
	}
}

task assoc_combine_r {
	input {
		Pair[String, File] chr_n_assocfiles
		String? assoc_type
		String? out_prefix
		File? conditional_variant_file
	}

	command <<<
		touch foo.txt
		touch bar.txt
	>>>

	output {
		File assoc_combined = glob("*.RData")[0]
	}
}

task assoc_plots_r {
	input {
		Array[File] assoc_files
		String assoc_type
		String? plots_prefix
		Boolean? disable_thin
		File? known_hits_file
		Int? thin_npoints
		Int? thin_nbins
		Int? plot_mac_threshold
		Float? truncate_pval_threshold
	}

	command {
		pass
	}
}


workflow assoc_agg {
	input {
		String?      aggregate_type
		Float?       alt_freq_max
		Boolean?     disable_thin
		String?      genome_build
		String?      group_id
		File?        known_hits_file
		Array[File]  input_gds_files
		Int?         n_segments
		File         null_model_file
		String?      out_prefix
		Boolean?     pass_only
		File         phenotype_file
		Int?         plot_mac_threshold
		Array[Float]? rho
		Int?         segment_length
		String?      test
		Int?         thin_nbins
		Int?         thin_npoints
		Float?       truncate_pval_threshold
		Array[File]  variant_group_files
		Array[File]? variant_include_files
		File?        variant_weight_file
		String?      weight_beta
		String?      weight_user
	}

	# In order to force this to run first, all other tasks that uses these psuedoenums
	# will take them in via outputs of this task
	call wdl_validate_inputs {
		input:
			genome_build = genome_build,
			aggregate_type = aggregate_type,
			test = test
	}

#	scatter(gds_file in input_gds_files) {
#		call sbg_gds_renamer {
#			input:
#				in_variant = gds_file
#		}
#	}
#	call define_segments_r {
#		input:
#			segment_length = segment_length,
#			n_segments = n_segments,
#			genome_build = genome_build
#	}

#	scatter(variant_group_file in variant_group_files) {
#		call aggregate_list {
#			input:
#				variant_group_file = variant_group_file,
#				aggregate_type = aggregate_type,
#				group_id = group_id
#		}
#	}

#	call sbg_prepare_segments_1 {
#		input:
#			input_gds_files = sbg_gds_renamer.renamed_variants,
#			segments_file = define_segments_r.define_segments_output,
#			aggregate_files = aggregate_list.aggregate_list,
#			variant_include_files = variant_include_files
#	}

	# CWL has this as a four way dot product scatter... not sure how to do this in WDL!
#	call assoc_aggregate {
#		input:
#			gds_file = sbg_prepare_segments_1.gds_output, # CWL has linkMerge: merge_flattened for all inputs from other tasks
#			null_model_file = null_model_file,
#			phenotype_file = phenotype_file,
#			aggregate_variant_file = sbg_prepare_segments_1.aggregate_output,
#			out_prefix = out_prefix,
#			rho = rho,
#			segment_file = define_segments_r.define_segments_output,
#			test = test,
#			variant_include_file = sbg_prepare_segments_1.variant_include_output,
#			weight_beta = weight_beta,
#			segment = sbg_prepare_segments_1.segments,
#			aggregate_type = aggregate_type,
#			alt_freq_max = alt_freq_max,
#			pass_only = pass_only,
#			variant_weight_file = variant_weight_file,
#			weight_user = weight_user,
#			genome_build = genome_build
#
#	}

	#call sbg_flatten_lists {
	#	input:
	#		input_list = assoc_aggregate.assoc_aggregate
	#}

	#call sbg_group_segments_1 {
	#	input:
	#		assoc_files = sbg_flatten_lists.output_list
	#}

	# CWL uses a dotproduct scatter; this is the closest WDL equivalent that I'm aware of
	#scatter(chr_n_assocfiles in zip(sbg_group_segments_1.chromosome, sbg_group_segments_1.grouped_assoc_files)) {
	#	call assoc_combine_r {
	#		input:
	#			chr_n_assocfiles = chr_n_assocfiles,
	#			assoc_type = "aggregate"
	#	}
	#}

#	call assoc_plots_r {
#		input:
#			assoc_files = assoc_combine_r.assoc_combined,
#			assoc_type = "aggregate",
#			plots_prefix = out_prefix,
#			disable_thin = disable_thin,
#			known_hits_file = known_hits_file,
#			thin_npoints = thin_npoints,
#			thin_nbins = thin_nbins,
#			plot_mac_threshold = plot_mac_threshold,
#			truncate_pval_threshold = truncate_pval_threshold
#	}

	meta {
		author: "Ash O'Farrell"
		email: "aofarrel@ucsc.edu"
	}
}
