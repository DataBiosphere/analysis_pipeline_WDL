version 1.0

# General notes:
#
# variables and functions exclusive to the WDL version tend to have "py_" in front
# and use camelCase between words - this is to make it clear they don't quite 
# correlate to the CWL


# [1] ld_pruning -- calculates linkage diseq on a GDS file
task ld_pruning {
	input {
		File gds
		File? sample_include_file
		File? variant_include_file
		String genome_build = "hg38"  # can also be hg18 or hg19
		Float ld_r_threshold = 0.32
		Float ld_win_size = 10  # yes, a float, not an int
		Float maf_threshold = 0.01
		Float missing_threshold = 0.01
		#Boolean autosome_only = true  # buggy and not in CWL
		Boolean exclude_pca_corr = true  # will act as String in Python
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
			if ("~{genome_build}" == "hg18" or "~{genome_build}" == "hg19"):
				f.write("genome_build ~{genome_build}\n")
			else:
				f.close()
				print("Invalid ref genome. Please only select either hg38, hg19, or hg18.")
				exit(1)
		if ~{ld_r_threshold} != 0.32:
			f.write("ld_r_threshold ~{ld_r_threshold}\n")
		if ~{ld_win_size} != 10:  # by default this compares 10.0 to 10 which evals to true
			f.write("ld_win_size ~{ld_win_size}\n")
		if ~{maf_threshold} != 0.01:
			f.write("maf_threshold ~{maf_threshold}\n")
		if ~{missing_threshold} != 0.01:
			f.write("missing_threshold ~{missing_threshold}\n")

		if "~{def_sampleInc}" == "true":
			f.write("sample_include_file ~{sample_include_file}\n")

		if "~{def_variantInc}" == "true":
			f.write("variant_include_file ~{variant_include_file}\n")

		if "chr" in "~{gds}":
			parts = os.path.splitext(os.path.basename("~{gds}"))[0].split("chr")
			outfile_temp = "pruned_variants_chr" + parts[1] + ".RData"
			print(outfile_temp)
		else:
			outfile_temp = "pruned_variants.RData"
		if "~{out_prefix}" != "":
			outfile_temp = "~{out_prefix}" + "_" + outfile_temp

		f.write("outfile_temp " + outfile_temp + "\n")

		f.close()
		CODE

		echo "Calling R script ld_pruning.R"
		Rscript /usr/local/analysis_pipeline/R/ld_pruning.R ld_pruning.config
	}
	
	# Estimate disk size required
	Int gds_size = ceil(size(gds, "GB"))
	Int sample_size = if defined(sample_include_file) then ceil(size(sample_include_file, "GB")) else 0
	Int varInclude_size = if defined(variant_include_file) then ceil(size(variant_include_file, "GB")) else 0
	Int finalDiskSize = gds_size + sample_size + varInclude_size + addldisk

	# Workaround for optional files
	Boolean def_sampleInc = defined(sample_include_file)
	Boolean def_variantInc = defined(variant_include_file)
	
	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master:2.10.0"
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		File ld_pruning_output = "pruned_variants.RData"
		File config_file = "ld_pruning.config"
	}
}

# [2] subset_gds -- subset a GDS file based on RData vector of variants
task subset_gds {
	input {
		Pair[File, File] gds_n_varinc  # [gds, variant_include_file]
		String? out_prefix
		File? sample_include_file

		# runtime attributes
		Int addldisk = 1
		Int cpu = 2
		Int memory = 4
		Int preempt = 3
	}

	command {
		set -eux -o pipefail

		python << CODE
		import os

		def py_rootPlusChr(py_filename):
			'''
			Similar to split_n_space in vcf-to-gds but not equivalent
			The CWL uses nameroot for this, but I think the WDL needs the full path
			Ex: "inputs/test_data_chrX.vcf.gz" returns ["inputs/test_data_", "X"]
			'''
			py_split = py_filename.split("chr")
			if unicode(str(py_split[1][1])).isnumeric():
				# chr10 and above
				py_thisNamerootSplit = py_split[0]
				py_thisChr = py_split[1][0:2]
			else:
				# chr9 and below + chrX
				py_thisNamerootSplit = py_split[0]
				py_thisChr = py_split[1][0:1]
			return [py_thisNamerootSplit, py_thisChr]

		gds = "~{gds_n_varinc.left}"
		variant_include_file = "~{gds_n_varinc.right}"

		f = open("subset_gds.config", "a")
		f.write("gds_file " + gds + "\n")
		f.write("variant_include_file " + variant_include_file + "\n")

		if "~{def_sampleInc}" == "true":
			f.write("sample_include_file ~{sample_include_file}\n")

		if ("~{out_prefix}" != ""):
			chromosome = py_rootPlusChr(gds)[1]
			py_filename = "~{out_prefix}" + "_chr" + chromosome + ".gds"
		else:
			chromosome = py_rootPlusChr(gds)[1]
			basename = os.path.basename(py_rootPlusChr(gds)[0])
			py_filename = basename + "subset_chr" + chromosome + ".gds"

		f.write("subset_gds_file " + py_filename)
		f.close()
		CODE

		R -q --vanilla < /usr/local/analysis_pipeline/R/subset_gds.R --args subset_gds.config
	}

	# Estimate disk size required
	Int gds_size = ceil(size(gds_n_varinc.left, "GB"))
	Int varinc_size = ceil(size(gds_n_varinc.right, "GB"))
	Int sample_size = if defined(sample_include_file) then ceil(size(sample_include_file, "GB")) else 0
	Int finalDiskSize = gds_size + varinc_size + sample_size + addldisk

	# Workaround for optional files
	Boolean def_sampleInc = defined(sample_include_file)

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master:2.10.0"
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		File config_file = "subset_gds.config"
		# Seems that "/.+?(?=\.gds)/.gds" isn't valid for an output
		File subset_output = glob("*.gds")[0]
	}
}

# task merge_gds {
# 	input {
# 		Array[File] gdss
# 		String? out_prefix

# 		# runtime attributes
# 		Int addldisk = 1
# 		Int cpu = 2
# 		Int memory = 4
# 		Int preempt = 3
# 	}

# 	command <<<
# 	set -eux -o pipefail

# 	# CWL has an ln -s, will probably need to use copy trick again

# 	python CODE <<
# 	import os

# 	# if chr, etc

# 	if "~{out_prefix}" != "":  # would this work in Python??
# 		merged_gds_file_name = "~{out_prefix}" + ".gds"
# 	else:
# 		merged_gds_file_name = "merged.gds"

# 	f = open("merge_gds.config", "a")
# 	f.write('merged_gds_file "' + merged_gds_file_name + '"')

# 	f.close()
# 	exit()
# 	CODE


# 	Rscript /usr/local/analysis_pipeline/R/merge_gds.R merge_gds.config
# 	>>>

# 	# may have components missing
# 	Int gds_size = ceil(size(gdss, "GB"))
# 	Int finalDiskSize = gds_size + addldisk

# 	runtime {
# 		cpu: cpu
# 		docker: "uwgac/topmed-master:2.10.0"
# 		disks: "local-disk " + finalDiskSize + " HDD"
# 		memory: "${memory} GB"
# 		preemptibles: "${preempt}"
# 	}
	
# 	output {
# 		Array[File] merged_gds_output = glob("*.gds")
# 		File config_file = "merge_gds.config"
# 	}
# }

# task check_merged_gds {
# 	input {
# 		File gds

# 		# runtime attributes
# 		Int addldisk = 1
# 		Int cpu = 2
# 		Int memory = 4
# 		Int preempt = 3
# 	}

# 	command <<<
# 	set -eux -o pipefail
# 	pass
# 	>>>

# 	runtime {
# 		cpu: cpu
# 		docker: "uwgac/topmed-master:2.10.0"
# 		#disks: "local-disk " + finalDiskSize + " HDD"
# 		memory: "${memory} GB"
# 		preemptibles: "${preempt}"
# 	}

# 	#output {
# 		#File config_file = "check_merged_gds.config"
# 	#}

# }

workflow b_ldpruning {
	input {
		Array[File] gds_files
		String? out_prefix
		File? sample_include_file
		File? variant_include_file
	}

	scatter(gds_file in gds_files) {
		call ld_pruning {
			input:
				gds = gds_file,
				sample_include_file = sample_include_file,
				variant_include_file = variant_include_file,
				out_prefix = out_prefix
		}
	}

	# CWL uses a dotproduct scatter; this is the closest WDL equivalent
	scatter(gds_n_varinc in zip(gds_files, ld_pruning.ld_pruning_output)) {
		call subset_gds {
			input:
				gds_n_varinc = gds_n_varinc,
				sample_include_file = sample_include_file,
				out_prefix = out_prefix
		}
	}


	#call merge_gds {
	#	input:
	#		gdss = gds_files  # should be output of previous step!!
	#}

	#scatter(gds_file in gds_files) { # should be output of previous step!!
	#	call check_merged_gds {
	#		input:
	#			gds = gds_file
	#	}
	#}

	meta {
		author: "Ash O'Farrell"
		email: "aofarrel@ucsc.edu"
	}
}
