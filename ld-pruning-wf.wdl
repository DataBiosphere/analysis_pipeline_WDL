version 1.0

# General notes:
# Should error out if genome_build != one of these: hg38, hg19, or hg18
# There might be a better way of doing this in WDL than the current implementation though...

# [1] ld_pruning -- ld prunes a GDS file
task ld_pruning {
	input {

		# will need to figure out how to deal with autosome_only = true

		File gds
		File? sample_include_file
		File? variant_include_file
		String genome_build = "hg38"  # can also be hg18 or hg19
		Float ld_r_threshold = 0.32  # (r^2 = 0.1)
		Float ld_win_size = 10
		Float maf_threshold = 0.01
		Float missing_threshold = 0.01
		Boolean autosome_only = true
		Boolean exclude_pca_corr = true  # will act as String by Python
		String? out_prefix
		
		# runtime attributes
		Int addldisk = 1
		Int cpu = 2
		Int memory = 4
		Int preempt = 3
	}
	command {
		set -eux -o pipefail

		echo "Generating config file"
		python << CODE
		import os
		f = open("ld_pruning.config", "a")
		f.write("gds_file ~{gds}\n")
		if "~{exclude_pca_corr}" != "true":
			f.write("exclude_pca_corr ~{exclude_pca_corr}\n")
		if "~{genome_build}" != "hg38":
			if "~{genome_build}" == "hg18" || "~{genome_build}" == "hg19":  # is this valid python?
				f.write("genome_build ~{genome_build}\n")
			else:
				# invalid
				exit(1)
		if ~{ld_r_threshold} != 0.32:
			f.write("ld_r_threshold ~{ld_r_threshold}\n")
		if ~{ld_win_size} != 10:
			f.write("ld_win_size ~{ld_win_size}\n")
		if ~{maf_threshold} != 0.01:
			f.write("maf_threshold ~{maf_threshold}\n")
		if ~{missing_threshold} != 0.01
			f.write("missing_threshold ~{missing_threshold}\n")

		# need to implement sample include file
		# need to implement variant include file

		f.close()
		exit()
		CODE

		echo "Calling R script ld_pruning.R"
		Rscript /usr/local/analysis_pipeline/R/ld_pruning.R ld_pruning.config
	}
	
	# Estimate disk size required

	# should include sample file...
	Int gds_size = ceil(size(gds, "GB"))
	Int finalDiskSize = 2*gds_size + addldisk
	
	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master:2.10.0"
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		Array[File] ld_pruning_output = glob("*.RData") # RData file with variant.id of pruned variants
		File config_file = "ld_pruning.config"
	}
}

task subset_gds {
   # CWL has "scatterMethod: dotproduct"
   # more research is needed
}

task merge_gds {
	input {
		Array[File] gdss
		String? out_prefix

		# runtime attributes
		Int addldisk = 1
		Int cpu = 2
		Int memory = 4
		Int preempt = 3
	}

	command <<<

	# CWL has an ln -s, will probably need to use copy trick again

	python CODE <<
	# if chr, etc

	if "~{out_prefix}" != "":  # would this work in Python??
		merged_gds_file_name = "~{out_prefix}" + ".gds"
	else:
		merged_gds_file_name = "merged.gds"

	f = open("merge_gds.config", "a")
	f.write('merged_gds_file "' + merged_gds_file_name + '"')

	f.close()
	exit()
	CODE


	Rscript /usr/local/analysis_pipeline/R/merge_gds.R merge_gds.config
	>>>

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master:2.10.0"
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	
	output {
		Array[File] merged_gds_output = glob("*.gds")
		File config_file = "merge_gds.config"
	}
}

task check_merged_gds {
	input {
		File gds

		# runtime attributes
		Int addldisk = 1
		Int cpu = 2
		Int memory = 4
		Int preempt = 3
	}

}

workflow b_ldpruning {
	input {
		Array[File] gds_files
	}

	scatter(gds_file in gds_files) {
		call ld_pruning {
			input:
				gds = gds_file
		}
	}

	# subset GDS seems to have weird scatter type

	call check_merged_gds {
		input:
			gdss = gds_files  # should be output of previous step!!
	}

	scatter(gds_file in gds_files) { # should be output of previous step!!
		call check_merged_gds {
			input:
				gds = gds_file
		}
	}

	meta {
		author: "Ash O'Farrell"
		email: "aofarrel@ucsc.edu"
	}
}
