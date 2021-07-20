version 1.0

# [1] vcf2gds -- converts a VCF file into a GDS file
task vcf2gds {
	input {
		File vcf
		String output_file_name = basename(sub(vcf, "\.vcf\.gz(?!.{1,})|\.vcf\.bgz(?!.{5,})|\.vcf(?!.{5,})|\.bcf(?!.{1,})", ".gds"))
		Array[String] format # vcf formats to keep
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
		f = open("vcf2gds.config", "a")
		f.write("vcf_file ~{vcf}\n")
		f.write("format ")
		for py_formattokeep in ['~{sep="','" format}']:
			f.write(py_formattokeep)
		f.write("\ngds_file '~{output_file_name}'\n")
		f.close()
		exit()
		CODE

		echo "Calling R script vcfToGds.R"
		Rscript /usr/local/analysis_pipeline/R/vcf2gds.R vcf2gds.config
	}
	
	# Estimate disk size required
	Int vcf_size = ceil(size(vcf, "GB"))
	Int finalDiskSize = 2*vcf_size + addldisk
	
	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		File gds_output = output_file_name
		File config_file = "vcf2gds.config"
	}
}

# [2] uniqueVars -- attempts to give unique variant IDS
task unique_variant_id {
	input {
		Array[File] gdss
		# runtime attr
		Int addldisk = 1
		Int cpu = 2
		Int memory = 4
		Int preempt = 2
	}
	command <<<
		set -eux -o pipefail

		# This is a workaround for the Python code to work correctly
		# Symlinks would be preferable, but they do not work on GCS
		# This is known as the twice-localized workaround
		echo "Twice-localized workaround: Copying GDS inputs into the workdir"
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
			chrom_num = file.split("chr")[1]
			return chrom_num

		def write_config(chr_array, path):
			f = open("unique_variant_ids.config", "a")
			f.write('chromosomes "' + chrs + '"\n')
			f.write('gds_file "' + path[0] + 'chr ' + path[1] + '"\n')
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
			chr_array.append(chrom_num)
		chrs = ' '.join(chr_array)

		write_config(chrs, path)
		
		exit()
		CODE
		
		echo "Calling uniqueVariantIDs.R"
		Rscript /usr/local/analysis_pipeline/R/unique_variant_ids.R unique_variant_ids.config
	>>>
	# Estimate disk size required
	Int gdss_size = ceil(size(gdss, "GB"))
	Int finalDiskSize = 2*gdss_size + addldisk

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		Array[File] unique_variant_id_gds_per_chr = glob("*.gds")
	}
}

# [3] checkGDS - check a GDS file against its supposed VCF input
task check_gds {
	input {
		File gds
		Array[File] vcfs
		# runtime attr
		Int addldisk = 1
		Int cpu = 8
		Int memory = 12
		Int preempt = 0
	}

	command <<<
		# triple carrot syntax is required for this command section
		set -eux -o pipefail

		echo "Searching for VCF and generating config file"
		python << CODE
		import os

		def split_n_space(py_splitstring):
		# Return [file name with chr name replaced by space, chr name]
		# Ex: test_data_chrX.vcf.gz returns ["test_data_chr .vcf.gz", "X"]

			if(unicode(str(py_splitstring[1][1])).isnumeric()):
				# chr10 and above
				py_thisVcfWithSpace = "".join([
					py_splitstring[0],
					"chr ",
					py_splitstring[1][2:]])
				py_thisChr = py_splitstring[1][0:2]
			else:
				# chr9 and below + chrX
				py_thisVcfWithSpace = "".join([
					py_splitstring[0],
					"chr ",
					py_splitstring[1][1:]])
				py_thisChr = py_splitstring[1][0:1]
			return [py_thisVcfWithSpace, py_thisChr]

		def write_config(py_vcf, py_gds):
			f = open("check_gds.config", "a")

			# write VCF file
			f.write("vcf_file ")
			f.write("'" + split_n_space(py_vcf.split("chr"))[0] + "'" + '\n')

			# write GDS file
			f.write("gds_file ")
			f.write("'" + split_n_space(py_gds.split("chr"))[0] + "'" + '\n')

			# grab chr number and close file
			py_thisChr = split_n_space(py_gds.split("chr"))[1]
			f.close()

			# write chromosome number to new file, to be read in bash
			g = open("chr_number", "a")
			g.write(str(py_thisChr)) # already str if chrX but python won't complain

		py_vcfarray = ['~{sep="','" vcfs}']
		py_gds = "~{gds}"
		py_vcf = py_vcfarray[0]
		py_base = os.path.basename(py_vcf)
		write_config(py_vcf, py_gds)
		CODE

		echo "Setting chromosome number"
		BASH_CHR=$(<chr_number)
		echo "Chromosme number is ${BASH_CHR}"

		echo "Calling check_gds.R"
		Rscript /usr/local/analysis_pipeline/R/check_gds.R check_gds.config --chromosome ${BASH_CHR}
	>>>

	# Estimate disk size required
	Int gds_size = ceil(size(gds, "GB"))
	Int vcfs_size = ceil(size(vcfs, "GB"))
	Int finalDiskSize = gds_size + vcfs_size + addldisk

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + finalDiskSize + " SSD"
		bootDiskSizeGb: 6
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
}

workflow vcftogds {
	input {
		Array[File] vcf_files
		Array[String] format = ["GT"]
		Boolean check_gds = false
	}

	scatter(vcf_file in vcf_files) {
		call vcf2gds {
			input:
				vcf = vcf_file,
				format = format
		}
	}
	
	call unique_variant_id {
		input:
			gdss = vcf2gds.gds_output,
	}
	
	if(check_gds) {
		scatter(gds in unique_variant_id.unique_variant_id_gds_per_chr) {
			call check_gds {
				input:
					gds = gds,
					vcfs = vcf_files
			}
		}
	}

	output {
		Array[File] pruned_output = unique_variant_id.unique_variant_id_gds_per_chr
	}

	meta {
		author: "Ash O'Farrell"
		email: "aofarrel@ucsc.edu"
	}
}
