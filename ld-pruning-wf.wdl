version 1.0

# General notes:
# ld_pruning should error out genome_build != one of these: hg38, hg19, or hg18
# There might be a better way of doing this in WDL than the current implementation though...
#
# ld_pruning seems functional but is largely untested at the moment
#
# The current focus is subset GDS due to a current need for that one in particular
#
# variables and functions exclusive to the WDL version tend to have "py_" in front and use camelCase between words
# this is to make it clear they don't quite correlate to the CWL

# [1] ld_pruning -- ld prunes a GDS file
task ld_pruning {
	input {

		# will need to figure out how to deal with autosome_only = true

		File gds
		File? sample_include_file
		File? variant_include_file
		String genome_build = "hg38"  # can also be hg18 or hg19
		Float ld_r_threshold = 0.32  # (r^2 = 0.1)
		Float ld_win_size = 10  # yes, a float, not an int
		Float maf_threshold = 0.01
		Float missing_threshold = 0.01
		Boolean autosome_only = true
		Boolean exclude_pca_corr = true  # will act as String in Python
		String? out_prefix
		# Workaround for optional files
		Boolean def_sampleInc = defined(sample_include_file)
		Boolean def_variantInc = defined(variant_include_file)
		
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
				# invalid
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

		# need to implement variant include file

		f.close()
		exit()
		CODE

		echo "Calling R script ld_pruning.R"
		Rscript /usr/local/analysis_pipeline/R/ld_pruning.R ld_pruning.config
	}
	
	# Estimate disk size required
	Int gds_size = ceil(size(gds, "GB"))
	Int sample_size = if defined(sample_include_file) then ceil(size(sample_include_file, "GB")) else 0
	Int varInclude_size = if defined(variant_include_file) then ceil(size(variant_include_file, "GB")) else 0
	Int finalDiskSize = gds_size + sample_size + varInclude_size + addldisk
	
	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master:2.10.0"
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		File ld_pruning_output = ("pruned_variants.RData") # RData file with variant.id of pruned variants
		File config_file = "ld_pruning.config"
	}
}

task subset_gds {
	input {
		Array[File] gds_n_varinc  # [gds, variant_include_files]
		String? out_prefix
		# need sample file eventually
	}

	command {

		python << CODE

		py_varIncArray = ['~{sep="','" gds_n_varinc}']
		gds = py_varIncArray[0]
		variant_include_file = py_varIncArray[1]
		
		def py_getThisVarIncFile():
			# Locate the variant include file corresponding to the gds file
			# Necessary due to WDL only being able to scatter on one array
			py_varIncArray = ['~{sep="','" variant_include_files}']
			print(py_varIncArray)
			py_gdsChr = py_rootPlusChr("~{gds}")[1]
			py_debugging = []
			for py_varIncFile in py_varIncFiles:
				py_varIncChr = py_rootPlusChr(os.path.basename(py_varIncFile))[1]
				if py_varIncChr == py_gdsChr:
					return py_varIncFile
				else:
					py_debugging.append(py_varIncChr)

			# if we get here, none found
			os.write(2, b"variant_include_file array defined, but could not match any of them with the current gds file\n")
			os.write(2, "more info:\n")
			os.write(2, "\tGDS file passed in: ~{gds}\n")
			os.write(2, "\tGDS file determined to be chromosome " + py_gdsChr + "\n")
			os.write(2, "\tVariant include file array: " + py_varIncFiles + "\n")
			os.write(2, "\tRespectively, these generate these chromosomes: " + py_debugging + "\n")


		def py_rootPlusChr(py_filename):
			# Similar to split_n_space in vcf-to-gds but not equivalent
			# Ex: "test_data_chrX.vcf.gz" returns ["test_data_", "X"]
			py_split = py_filename.split("chr")
			if(unicode(str(py_split[1][1])).isnumeric()):
				# chr10 and above
				py_thisNamerootSplit = py_split[0]
				py_thisChr = py_split[1][0:2]
			else:
				# chr9 and below + chrX
				py_thisNamerootSplit = py_split[0]
				py_thisChr = py_split[1][0:1]
			return [py_thisNamerootSplit, py_thisChr]


		f = open("subset_gds.config", "a")
		f.write("gds_file ~{gds}\n")
		f.write("variant_include_file " + py_getThisVarIncFile() + "\n")

		# add in if sample include file

		if "~{out_prefix}" != "":
			chromosome = py_rootPlusChr("~{gds}")
			f.write("subset_gds_file" + "~{out_prefix}" + "_chr" + chromosome + ".gds"
		else:
			chromosome = py_rootPlusChr("~{gds}")[1]
			basename = py_rootPlusChr("~{gds}")[0]
			f.write("subset_gds_file" + "~{out_prefix}" + "_chr" + chromosome + ".gds"
		f.close()
		CODE

		R -q --vanilla --args subset_gds.config /usr/local/analysis_pipeline/R/subset_gds.R
	}
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
	import os

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

	# may have components missing
	Int gds_size = ceil(size(gdss, "GB"))
	Int finalDiskSize = gds_size + addldisk

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

	command <<<
	pass
	>>>

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master:2.10.0"
		#disks: "local-disk " + finalDiskSize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}

	#output {
		#File config_file = "check_merged_gds.config"
	#}

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

	# The CWL version of subet_gds uses scatterMethod: dotproduct
	# I'm not aware of a WDL equivalent

	# Walt pointed out we can try using zip?

	# A CWL dotproduct scatter requires both arrays to have the same
	# number of entries. Checking the len of both arrays therefore
	# brings the CWL and WDL into closer alignment.

	if (length(gds_files) == length(ld_pruning.ld_pruning_output)) {  # requires workaround A
		scatter(gds_n_varinc in zip(gds_files, ld_pruning.ld_pruning_output)) {
			call subset_gds {
				input:
					gds_n_varinc = gds_n_varinc
			}
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
