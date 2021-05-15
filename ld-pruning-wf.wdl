version 1.0

# General notes:
#
# variables and functions exclusive to the WDL version tend to have "py_" in front
# and use camelCase between words - this is to make it clear they don't quite 
# correlate to the CWL

# [1] ld_pruning -- calculates linkage diseq on a GDS file
task ld_pruning {
	input {
		File gds_file

		# optional
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
		Int addldisk = 5
		Int cpu = 2
		Int memory = 4
		Int preempt = 3
	}

	# Estimate disk size required
	Int gds_size = ceil(size(gds_file, "GB"))
	Int final_disk_dize = gds_size + addldisk

	# Workaround for optional files
	Boolean defSampleInclude = defined(sample_include_file)
	Boolean defVariantInclude = defined(variant_include_file)
	
	command {
		set -eux -o pipefail

		echo "Generating config file"
		# noquotes = argument has no quotes in the config file to match CWL config EXACTLY
		python << CODE
		import os
		f = open("ld_pruning.config", "a")
		f.write('gds_file "~{gds_file}"\n')

		# this logic is slightly different from the CWL intentionally
		if "~{exclude_pca_corr}" != "true":
			f.write("exclude_pca_corr ~{exclude_pca_corr}\n")  # noquotes

		# to match CWL exactly, genome_build is written even if default value
		if "~{genome_build}" not in ['hg18', 'hg19', 'hg38']:
			f.close()
			print("Invalid ref genome. Please only select either hg38, hg19, or hg18.")
			exit(1)
		else:
			f.write('genome_build "~{genome_build}"\n')
		
		if ~{ld_r_threshold} != 0.32:
			f.write("ld_r_threshold ~{ld_r_threshold}\n")  # noquotes
		if ~{ld_win_size} != 10:  # by default this compares 10.0 to 10 which evals to true
			f.write("ld_win_size ~{ld_win_size}\n")  # noquotes
		if ~{maf_threshold} != 0.01:
			f.write("maf_threshold ~{maf_threshold}\n")  # noquotes
		if ~{missing_threshold} != 0.01:
			f.write("missing_threshold ~{missing_threshold}\n")  # noquotes

		if "~{defSampleInclude}" == "true":
			f.write('sample_include_file "~{sample_include_file}"\n')

		if "~{defVariantInclude}" == "true":
			f.write('variant_include_file "~{variant_include_file}"\n')

		if "chr" in "~{gds_file}":
			parts = os.path.splitext(os.path.basename("~{gds_file}"))[0].split("chr")
			outfile_temp = "pruned_variants_chr" + parts[1] + ".RData"
		else:
			outfile_temp = "pruned_variants.RData"
		if "~{out_prefix}" != "":
			outfile_temp = "~{out_prefix}" + "_" + outfile_temp

		f.write('out_file "' + outfile_temp + '"\n')

		f.close()
		CODE

		echo "Calling R script ld_pruning.R"
		Rscript /usr/local/analysis_pipeline/R/ld_pruning.R ld_pruning.config
	}

	
	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master:2.10.0"
		disks: "local-disk " + final_disk_dize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		File ld_pruning_output = glob("*.RData")[0]
		File config_file = "ld_pruning.config"
	}

}

# [2] subset_gds -- subset a GDS file based on RData vector of variants
task subset_gds {
	input {
		Pair[File, File] gds_n_varinc  # [gds, variant_include_file]

		# optional
		String? out_prefix
		File? sample_include_file

		# runtime attributes
		Int addldisk = 5
		Int cpu = 2
		Int memory = 4
		Int preempt = 3
	}
	
	# Estimate disk size required
	Int gds_size = ceil(size(gds_n_varinc.left, "GB"))
	Int final_disk_dize = gds_size + addldisk

	# Workaround for optional files
	Boolean defSampleInclude = defined(sample_include_file)
	
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

		if "~{defSampleInclude}" == "true":
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

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master:2.10.0"
		disks: "local-disk " + final_disk_dize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		File config_file = "subset_gds.config"
		File subset_output = glob("*.gds")[0]
	}
}

# [3] merge_gds -- merge a bunch of GDS files into one
task merge_gds {
	input {
		Array[File] gdss

		# optional
		String? out_prefix

		# runtime attributes
		Int addldisk = 5
		Int cpu = 2
		Int memory = 4
		Int preempt = 3
	}

	# Estimate disk size required
	Int gds_size = ceil(size(gdss, "GB"))
	Int final_disk_dize = gds_size * 3 + addldisk
	String filename = select_first([out_prefix, "merged"])

	command <<<
		set -eux -o pipefail

		# CWL has an ln -s, will probably need to use copy trick again
		echo "Copying inputs into the workdir"
		BASH_FILES=(~{sep=" " gdss})
		for BASH_FILE in ${BASH_FILES[@]};
		do
			cp ${BASH_FILE} .
		done

		echo "Generating config file"
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
			if "chr" in file:
				chrom_num = file.split("chr")[1]
				return chrom_num
			else:
				return "error-invalid-inputs"

		def write_config(chrs, path):
			f = open("merge_gds.config", "a")

			if "~{out_prefix}" != "":
				merged_gds_file_name = "~{out_prefix}" + ".gds"
			else:
				merged_gds_file_name = "merged.gds"

			f.write('gds_file "' + path[0] + 'chr ' + path[1] + '"\n')
			f.write('merged_gds_file "' + merged_gds_file_name + '"\n')
			f.write('chromosomes "' + chrs + '"\n')

			f.close()

		gds_array_fullpath = ['~{sep="','" gdss}']
		gds_array_basenames = []
		for fullpath in gds_array_fullpath:
			gds_array_basenames.append(os.path.basename(fullpath))

		a_file = gds_array_basenames[0]
		chr = find_chromosome(a_file)
		path = a_file.split('chr'+chr)

		# make list of all chromosomes found in input files
		chr_array = []
		for gds_file in gds_array_basenames:
			chrom_num = find_chromosome(gds_file)
			if chrom_num == "error-invalid-inputs":
				print("Unable to determine chromosome number from inputs.")
				print("Please ensure your files contain ''chr'' followed by")
				print("the number of letter of the chromosome (chr1, chr2, etc)")
				exit(1)
			else:
				chr_array.append(chrom_num)
		chrs = ' '.join(chr_array)

		write_config(chrs, path)

		exit()
		CODE

		Rscript /usr/local/analysis_pipeline/R/merge_gds.R merge_gds.config
	>>>

	runtime {
		cpu: cpu
		disks: "local-disk " + final_disk_dize + " HDD"
		docker: "uwgac/topmed-master:2.10.0"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	
	output {
		File merged_gds_output = filename + ".gds"
		File config_file = "merge_gds.config"
	}
}

# [4] check_merged_gds -- check a merged GDS file against its inputs

task check_merged_gds {
	input {
		File gds_file
		File merged_gds_file

		#runtime attributes
		Int addldisk = 5
		Int cpu = 2
		Int memory = 4
		Int preempt = 3
	}

	# Estimate disk size required
	Int gds_size = ceil(size(gds_file, "GB"))
	Int final_disk_dize = gds_size * 3 + addldisk

	command <<<
		set -eux -o pipefail

		python << CODE
		import os
		gds = "~{gds_file}"
		gds_first_part = gds.split('chr')[0]
		gds_second_part = gds.split('chr')[1]
		print(gds_first_part)
		print(gds_second_part)

		# grab the chr number
		g = open("chr_number", "a")
		if(unicode(str(gds_second_part[1])).isnumeric()):
			# two digit number
			g.write(gds_second_part[:2])
			gds_second_part = gds_second_part[2:]
		else:
			# one digit number or Y/X/M
			g.write(gds_second_part[0])
			gds_second_part = gds_second_part[1:]
		g.close()

		gds_name = gds_first_part + 'chr ' + gds_second_part
		f = open("check_merged_gds.config", "a")
		f.write('gds_file "' + gds_name + '"\n')
		f.write('merged_gds_file "~{merged_gds_file}"\n')
		f.close
		exit()
		CODE

		echo "Setting chromosome number"
		BASH_CHR=$(<chr_number)
		echo "Chromosme number is ${BASH_CHR}"

		R -q --vanilla < /usr/local/analysis_pipeline/R/check_merged_gds.R --args check_merged_gds.config --chromosome ${BASH_CHR}
	>>>

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master:2.10.0"
		disks: "local-disk " + final_disk_dize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		File config_file = "check_merged_gds.config"
	}

}

workflow ldpruning {
	input {
		Array[File] gds_files
		String? out_prefix
		File? sample_include_file
		File? variant_include_file
	}

	scatter(gds_file in gds_files) {
		call ld_pruning {
			input:
				gds_file = gds_file,
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

	call merge_gds {
		input:
			gdss = subset_gds.subset_output,
			out_prefix = out_prefix
	}

	scatter(subset_gds in subset_gds.subset_output) {
		call check_merged_gds {
			input:
				gds_file = subset_gds,
				merged_gds_file = merge_gds.merged_gds_output

		}
	}


	meta {
		author: "Ash O'Farrell"
		email: "aofarrel@ucsc.edu"
	}
}