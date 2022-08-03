version 1.0
# WDL Author: Ash O'Farrell (UCSC)
# Based on code from the University of Washington Genome Analysis Center
# Please see https://doi.org/10.1093/bioinformatics/btz567

task wdl_validate_inputs {
	# WDL Only -- Validate inputs
	#
	# This task:
	# * mimics CWL type enum for three input variables by ensuring they're valid
	# * makes sure more than one GDS file was input
	# * sets up proper disk scaling for the prepare segments task
	#
	# It is acceptable for the user to put nothing for the enums. The R scripts
	# will fall back on the falling defaults if nothing is defined:
	# * genome_build: "hg38"
	# * aggregate_type: "allele"
	# * test: "burden" (note lowercase-B, not uppercase-B as indicated in CWL)
	
	input {
		String? genome_build
		String  aggregate_type
		String  test
		String  chromosome
		Int?	n_segments=1

		# no runtime attr because this is a trivial task that does not scale
	}

	command <<<
		set -eux -o pipefail

		#acceptable genome builds: ("hg38" "hg19")
		#acceptable aggreg types:  ("allele" "position")
		acceptable_test_values=("burden" "skat" "smmat" "fastskat" "skato")
		acceptable_chromosome_values=("1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21" "22" "X" "Y" "M")

		if [[ ! "~{genome_build}" = "" ]]
		then
			if [[ ! "hg38" = "~{genome_build}" ]]
			then
				if [[ ! "hg19" = "~{genome_build}" ]]
				then
					echo "Invalid input for genome_build. Must be hg38 or hg19."
					exit 1
				else
					echo "~{genome_build} seems valid"
				fi
			fi
		fi

		if [[ ! "~{aggregate_type}" = "" ]]
		then
			if [[ ! "allele" = "~{aggregate_type}" ]]
			then
				if [[ ! "position" = "~{aggregate_type}" ]]
				then
					echo "Invalid input for aggregate_type. Must be allele or position."
					exit 1
				else
					echo "~{aggregate_type} seems valid"
				fi
			fi
		fi

		if [[ ! "~{test}" = "" ]]
		then
			in_array=0
			for thing in "${acceptable_test_values[@]}"
			do
				if [[ "^$thing$" = "^~{test}$" ]]
				then
					in_array=1
				fi
			done
			if [[ $in_array = 0 ]]
			then
				echo "Invalid input for test. Must be burden, skat, smmat, fastskat, or skato."
				exit 1
			else
				echo "~{test} seems valid"
			fi
		fi
		
		if [[ ~{n_segments} -le 0 || ~{n_segments} -ge 11  ]]
		then
			echo "Invalid input for n_segment. Only a positive integer less than or equal to 10 is accepted"
			exit 1
		else
			echo "n_segments ~{n_segments} seems valid"
		fi	
		
		if [[ ! "~{chromosome}" = "" ]]
		then
			in_array=0
			for thing in "${acceptable_chromosome_values[@]}"
			do
				if [[ "^$thing$" = "^~{chromosome}$" ]]
				then
					in_array=1
				fi
			done
			if [[ $in_array = 0 ]]
			then
				echo "Invalid input for Chromosome. Must be 1, 2, ..., 22, X, Y or M."
				exit 1
			else
				echo "input for Chromosome ~{chromosome} seems valid"
			fi
		fi			
	>>>

	runtime {
		docker: "ubuntu:jammy-20220101"
		preemptibles: 3
	}

	output {
		String? valid_genome_build = genome_build
		String? valid_aggregate_type = aggregate_type
		String? valid_test = test
	}

}

task sbg_gds_renamer {
	# Renames GDS file if they contain suffixes after chromosome (chr##) in the filename.
 	# Example: data_chr1_subset.gds --> data_chr1.gds.
 	#
 	# Do not change the sudo chmod command with something like "sudo chmod 777 ~{in_variant}"
 	# That does not work on Terra!

	input {
		File in_variant
		Boolean debug

		# this is ignored by the script itself, but including this stops this task from firing
		# before wdl_validate_inputs finishes
		String? noop

		# runtime attributes, which you shouldn't need to adjust as this is a very light task
		Int addldisk = 3
		Int cpu = 2
		Int memory = 4
		Int preempt = 3
	}
	
	Int gds_size = ceil(size(in_variant, "GB"))
	Int finalDiskSize = gds_size + addldisk
	
	command <<<

		# do not change these two lines without careful testing on Terra
		set -eux -o pipefail
		find . -type d -exec sudo chmod -R 777 {} +

		python << CODE
		import os
		def find_chromosome(file):
			chr_array = []
			chrom_num = split_on_chromosome(file)
			if len(chrom_num) == 1:
				acceptable_chrs = [str(integer) for integer in list(range(1,22))]
				acceptable_chrs.extend(["X","Y","M"])
				if chrom_num in acceptable_chrs:
					return chrom_num
				else:
					print("%s appears to be an invalid chromosome number." % chrom_num)
					exit(1)
			elif (unicode(str(chrom_num[1])).isnumeric()):
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

		nameroot = os.path.basename("~{in_variant}").rsplit(".", 1)[0]
		chr = find_chromosome(nameroot)
		base = nameroot.split('chr'+chr)[0]
		newname = base+'chr'+chr+".gds"
		if "~{debug}" == "true":
			print("Debug: Generated name: %s" % newname)
			print("Debug: Renaming file... (if you error here, it's likely a permissions problem)")

		os.rename("~{in_variant}", newname)

		CODE

	>>>

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:c564d54f5a3b9daed7a7677f860155f3b8c310b0771212c2eef1d6338f5c2600" # uwgac/topmed-master:2.12.0
		disks: "local-disk " + finalDiskSize + " HDD"
		maxRetries: 1
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		# although there are two gds files lying around, only the one that's in the parent directory
		# should get matched here according to my testing.
		File renamed_variants = glob("*.gds")[0]
	}
}

task define_segments_r {
	# This task divides the entire genome into segments to improve parallelization in later tasks.
	# As an absolute minimum, you will end up with one segment per chromosome.
	# n_segments (optional)
	# n_segments sets the number of segments. Note that n_segments assumes you are running on the
	# full genome. For example, if you set n_segments to 100, but only run on chr1 and chr2, you can
	# expect there to be about 15 segments as chr1 and chr2 together represent ~15% of the genome.
	# The remaining segments won't be created, and your 15 segments will be parallelized in later
	# tasks as 15 units, instead of 100.

	input {
		Int? segment_length
		Int? n_segments
		Int chromosome
		String? genome_build
		# runtime attributes -- should be sufficient for hg19, maybe adjust if you're using hg38
		Int cpu = 2
		Int memory = 4
		Int preempt = 3
	}

	# this task doesn't localize input files, so it doesn't need much disk size
	Int finalDiskSize = 10

	command <<<
		set -eux -o pipefail
		python << CODE
		import os
		f = open("define_segments.config", "a")
		f.write('out_file "segments.txt"\n')
		if "~{genome_build}" != "":
			f.write('genome_build "~{genome_build}"\n')
		f.close()
		CODE

		if [[ ! "~{segment_length}" = "" ]]
		then
			if [[ ! "~{n_segments}" = "" ]]
			then
				# has both args
				Rscript /usr/local/analysis_pipeline/R/define_segments.R --segment_length ~{segment_length} --n_segments $((~{n_segments} * 23)) define_segments.config
			else
				# has only seg length
				Rscript /usr/local/analysis_pipeline/R/define_segments.R --segment_length ~{segment_length} define_segments.config
			fi
		else
			if [[ ! "~{n_segments}" = "" ]]
			then
				# has only n segs
				Rscript /usr/local/analysis_pipeline/R/define_segments.R --n_segments $((~{n_segments} * 23)) define_segments.config
			else
				# has no args
				Rscript /usr/local/analysis_pipeline/R/define_segments.R define_segments.config
			fi
		fi
		cat segments.txt
		R --vanilla << CODE
		in.segments <- read.table("segments.txt",header=T,as.is=TRUE)
		write.table(in.segments[which(in.segments[,1] == ~{chromosome}),],file="segments.txt",sep="\t",col.names=TRUE,row.names=FALSE,quote=FALSE)
		CODE
		cat segments.txt
		# get the actual number of segments so we can scale sbg_prepare_segments_1 
		lines=$(wc -l < "segments.txt")
		segs="$((lines-1))"
		echo $segs > "Iwishtopassthisbashvariableasanoutput.txt"
	>>>

	runtime {
		cpu: cpu
		disks: "local-disk " + finalDiskSize + " HDD"
		docker: "uwgac/topmed-master@sha256:c564d54f5a3b9daed7a7677f860155f3b8c310b0771212c2eef1d6338f5c2600" # uwgac/topmed-master:2.12.0
		maxRetries: 1
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		Int actual_number_of_segments = read_int("Iwishtopassthisbashvariableasanoutput.txt")
		File config_file = "define_segments.config"
		File define_segments_output = "segments.txt"
	}
}


task aggregate_list {
	input {
		File variant_group_file
		String? aggregate_type
		String? group_id
		String chromosome

		# there is an inconsistency in the CWL here...
		# the parent CWL does not have out_file, but it does have out_prefix
		# the task CWL does not have out_prefix, but it does have out_file
		String? out_file

		# runtime attr
		Int addldisk = 1
		Int cpu = 2
		Int memory = 4
		Int preempt = 2
	}

	# For simplified assoc-aggregate_one_gds.wdl, we can simplify this task quite a bit
	# We no longer need to know which chromosome is being analyzed
	# We use the files as provided

	String basename_vargroup = basename(variant_group_file)
	Int vargroup_size = ceil(size(variant_group_file, "GB"))
	Int finalDiskSize = vargroup_size + addldisk
	
	command <<<
		set -eux -o pipefail

		cp ~{variant_group_file} ~{basename_vargroup}

		python << CODE
		import os
		
		f = open("aggregate_list.config", "a")

		# This part of the CWL is a bit confusing so let's walk through it line by line

		f.write('variant_group_file "~{basename_vargroup}"\n')

		# If there is a chr in the variant group file, a chr must be present in the output file
		if "~{out_file}" != "":
			f.write('out_file "~{out_file}.chr .RData"\n')  ## IF OUT_FILE IS DEFINED ** PROBLEM WITH TASK OUTPUT
		else:
			f.write('out_file "aggregate_list.chr .RData"\n')

		if "~{aggregate_type}" != "":
			f.write('aggregate_type "~{aggregate_type}"\n')

		if "~{group_id}" != "":
			f.write('group_id "~{group_id}"\n')

		f.write("\n")
		f.close()
	
		CODE

		Rscript /usr/local/analysis_pipeline/R/aggregate_list.R aggregate_list.config --chromosome ~{chromosome}

	>>>

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:c564d54f5a3b9daed7a7677f860155f3b8c310b0771212c2eef1d6338f5c2600" # uwgac/topmed-master:2.12.0
		disks: "local-disk " + finalDiskSize + " HDD"
		maxRetries: 1
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		File aggregate_list = glob("aggregate_list*.RData")[0]
		File config_file = "aggregate_list.config"
	}
}

task assoc_aggregate {
	# This is the meat-and-potatoes of this pipeline. It is parallelized on a segment basis, with
	# each instance of this task getting a zipped file containing all the files associated with a
	# segment. Note that this task contains several workarounds specific to the Terra file system.

	input {	
		File gds_file
		File aggregate_file # an RData file with GRanges object
		File? variant_include_file
		File segment_file # NOT the same as segment
		File null_model_file
		File phenotype_file
		String? out_prefix
		Array[Float]? rho
		String? test # acts as enum
		String? weight_beta
		Int segment
		String? aggregate_type # acts as enum
		Float? alt_freq_max
		Boolean? pass_only
		File? variant_weight_file
		String? weight_user
		String? genome_build # acts as enum
		String chromosome

		# runtime attr
		Int addldisk = 50
		Int cpu = 4
		Int retries = 1
		Int memory = 16
		Int preempt = 1

		# WDL only
		Boolean debug
	}
	
	# estimate disk size required
	Int gds_size = ceil(size(gds_file, "GB"))*5
	Int segment_size = ceil(size(segment_file, "GB"))
	Int null_size = ceil(size(null_model_file, "GB"))
	Int pheno_size = ceil(size(phenotype_file, "GB"))
	Int varweight_size = select_first([ceil(size(variant_weight_file, "GB")), 0])
	Int finalDiskSize = gds_size + segment_size + null_size + pheno_size + varweight_size + addldisk

	command <<<
		set -eux -o pipefail
		
		echo ""
		if [[ "~{variant_include_file}" = "" ]]
		then
		
		R --vanilla << CODE
		library(readr)
		library(SeqArray)
		library(GenomicRanges)
		library(GWASTools)
		annotation <- "~{aggregate_file}"
		agg <- getobj(annotation)

		gds_file <- "~{gds_file}"
		gds <- seqOpen(gds_file)
		if("~{aggregate_type}" == "allele") {
			chr.position.allele <- seqGetData(gds, "\$chrom_pos_allele")
			head(chr.position.allele)
			id <-  seqGetData(gds, "variant.id")
			agg <- data.frame(agg)
			variant_ids_to_include <- id[which(chr.position.allele %in% paste0(agg\$seqnames,":",agg\$start,"_",agg\$ref,"_",agg\$alt))]
		} else {
			seqSetFilter(gds,agg)
			variant_ids_to_include <-  seqGetData(gds, "variant.id")
		}
		seqClose(gds)
		print(paste("Number of variants selected:",length(variant_ids_to_include)))

		save(variant_ids_to_include,file=paste0(basename(annotation),".variantidsRData"))

		CODE
		
		fi
		
		echo "Calling Python..."
		python << CODE
		import os

		gds = "~{gds_file}"
		agg = "~{aggregate_file}"
		if "~{variant_include_file}" == "":
			var = os.path.basename(agg) + '.variantidsRData'
		else:
			var = "~{variant_include_file}"

		chr = "~{chromosome}" # runs on full path in the CWL
		
		dir = os.getcwd()
		if "~{debug}" == "true":
			print("Debug: Current workdir is %s; config file will be written here" % dir)

		f = open("assoc_aggregate.config", "a")
		
		if "~{out_prefix}" != "":
			f.write("out_prefix '~{out_prefix}_chr%s'\n" % chr)
		else:
			data_prefix = os.path.basename(gds).split('chr') # runs on basename in the CWL
			data_prefix2 = os.path.basename(gds).split('.chr')
			if len(data_prefix) == len(data_prefix2):
				f.write('out_prefix "' + data_prefix2[0] + '_aggregate_chr' + chr + '"' + "\n")
			else:
				f.write('out_prefix "' + data_prefix[0]  + 'aggregate_chr'  + chr + '"' + "\n")

		f.write('gds_file "%s"\n' % gds)
		f.write('phenotype_file "~{phenotype_file}"\n')
		f.write('aggregate_variant_file "%s"\n' % agg)
		f.write('null_model_file "~{null_model_file}"\n')
		f.write('variant_include_file "%s"\n' % var)
		
		# CWL accounts for null_model_params but this does not exist in aggregate context
		if "~{rho}" != "":
			f.write("rho ")
			for r in ['~{sep="','" rho}']:
				f.write("%s " % r)
			f.write("\n")
		f.write('segment_file "~{segment_file}"\n') # optional in CWL, never optional in WDL
		if "~{test}" != "":
			f.write('test "~{test}"\n') # cwl has test type, not sure if needed here
		if "~{weight_beta}" != "":
			f.write("weight_beta '~{weight_beta}'\n")
		if "~{aggregate_type}" != "":
			f.write("aggregate_type '~{aggregate_type}'\n")
		if "~{alt_freq_max}" != "":
			f.write("alt_freq_max ~{alt_freq_max}\n")
		
		# pass_only in the CWL:
		# User sets pass_only to true --> inputs.pass_only = true  --> ! --> pass_only not written
		# User sets pass_only to false--> inputs.pass_only = false --> ! --> pass_only set to false
		# User does not set pass_only --> inputs.pass_only = false --> ! --> pass_only not written
		# This works as intended as pass_only has sbg:toolDefaultValue: 'TRUE'
		if "~{pass_only}" == "false":
			f.write("pass_only FALSE\n")
		
		if "~{variant_weight_file}" != "":
			f.write("variant_weight_file '~{variant_weight_file}'\n")
		if "~{weight_user}" != "":
			f.write("weight_user '~{weight_user}'\n")
		if "~{genome_build}" != "":
			f.write("genome_build '~{genome_build}'\n")
		f.close()

		if "~{debug}" == "true":
			dir = os.getcwd()
			ls = os.listdir(dir)
			print("Debug: Python working directory is %s and it contains %s" % (dir, ls))
			print("Debug: Finished python section")

		CODE


		if [[ "~{debug}" = "true" ]]
		then
			echo "Debug: Location of file(s):"
			echo ""
			find -name *.config
			echo ""
		fi

		echo ""
		echo "Running Rscript..."
		Rscript /usr/local/analysis_pipeline/R/assoc_aggregate.R assoc_aggregate.config --segment ~{segment}

		if [[ "~{debug}" = "true" ]]
		then
			echo ""
			echo "Debug: Current contents of working directory are:"
			ls
			echo ""
			echo "Debug: Checking if output exists..."
			POSSIBLE_OUTPUT=(`find -name "*.RData"`)
			if [ ${#POSSIBLE_OUTPUT[@]} -gt 0 ]
			then
				echo "Debug: Output appears to exist."
			else 
				echo "Debug: There appears to be no output. This is not necessarily a problem -- "
				echo "some segments may give no output, especially if you have a lot of segments."
				echo "Verify by checking stdout of Rscript to see if 'exiting gracefully' appears."
			fi
		fi

		echo ""
		echo ""
		echo "Finished. The WDL executor will now attempt to evaluate its outputs."

	>>>

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:c564d54f5a3b9daed7a7677f860155f3b8c310b0771212c2eef1d6338f5c2600" # uwgac/topmed-master:2.12.0
		disks: "local-disk " + finalDiskSize + " SSD"
		maxRetries: "${retries}"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		# Do not change this to Array[File?] as that will break everything. The files within the
		# array cannot be optional, instead, we make the array itself optional to account for 
		# segments that do not give output. Working with Array[File?] is infinitely more difficult 
		# than working with Array[File]?, trust me on this.
		Array[File]? assoc_aggregate = glob("*.RData")
		File config = glob("*.config")[0]
	}
}

task sbg_group_segments_1 {
	input {
		Array[String] assoc_files
		Boolean debug

		# runtime attr
		Int addldisk = 3
		Int cpu = 8
		Int memory = 8
		Int retries = 1
		Int preempt = 2
	}

	Int assoc_size = ceil(size(assoc_files, "GB"))
	Int finalDiskSize = 2*assoc_size+addldisk

	command <<<

		# copy over because output struggles to find the files otherwise
		ASSO_FILES=(~{sep=" " assoc_files})
		for ASSO_FILE in ${ASSO_FILES[@]};
		do
			cp ${ASSO_FILE} .
		done

		python << CODE
		import os
		def split_on_chromosome(file):
			chrom_num = file.split("chr")[1]
			return chrom_num
			
		def find_chromosome(file):
			if "~{debug}" == "true":
				print("Debug: start find_chromosome...")
			chr_array = []
			chrom_num = split_on_chromosome(file)
			if len(chrom_num) == 1:
				acceptable_chrs = [str(integer) for integer in list(range(1,22))]
				acceptable_chrs.extend(["X","Y","M"])
				if chrom_num in acceptable_chrs:
					if "~{debug}" == "true":
						print("Debug: end find_chromosome, returning %s..." % chrom_num)
					return chrom_num
				else:
					print("%s appears to be an invalid chromosome number." % chrom_num)
					exit(1)
			elif (unicode(str(chrom_num[1])).isnumeric()):
				# two digit number
				chr_array.append(chrom_num[0])
				chr_array.append(chrom_num[1])
			else:
				# one digit number or Y/X/M
				chr_array.append(chrom_num[0])
			if "~{debug}" == "true":
				print("Debug: end find_chromosome, returning %s..." % chrom_num)
			return "".join(chr_array)

		print("Grouping...") # line 116 of CWL
		
		python_assoc_files = ['~{sep="','" assoc_files}']
		python_assoc_files_wkdir = []
		for file in python_assoc_files:
			# point to the workdir copies instead to help Terra
			python_assoc_files_wkdir.append(os.path.basename(file))
		assoc_files_dict = dict() 
		grouped_assoc_files = [] # see line 53 of CWL
		output_chromosomes = []  # see line 96 of CWL

		for i in range(0, len(python_assoc_files)):
			chr = find_chromosome(python_assoc_files[i])
			if chr in assoc_files_dict:
				assoc_files_dict[chr].append(python_assoc_files[i])
			else:
				assoc_files_dict[chr] = [python_assoc_files[i]]

		if "~{debug}" == "true":
			print("Debug: Iterating thru keys...")
		for key in assoc_files_dict.keys():
			grouped_assoc_files.append(assoc_files_dict[key]) # see line 65 in CWL
			output_chromosomes.append(key)                    # see line 108 in CWL

		if "~{debug}" == "true":
			for list in grouped_assoc_files:
				print("Debug: List in grouped_assoc_files:")
				print("%s\n" % list)
				for entry in list:
					print("Debug: Entry in list:")
					print("%s\n" % entry)
		
		f = open("output_filenames.txt", "a")
		i = 0
		for list in grouped_assoc_files:
			i += 1
			for entry in list:
				f.write("%s\t" % entry)
			f.write("\n")
		f.close()

		g = open("output_chromosomes.txt", "a")
		for chrom in output_chromosomes:
			g.write("%s\n" % chrom)
		g.close()

		print("Finished. Executor will now attempt to evaulate outputs.")
		CODE
	>>>
	
	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:c564d54f5a3b9daed7a7677f860155f3b8c310b0771212c2eef1d6338f5c2600" # uwgac/topmed-master:2.12.0
		disks: "local-disk " + addldisk + " HDD"
		maxRetries: "${retries}"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}

	output {
		File d_filenames = "output_filenames.txt" # debugging output
		File d_chrs = "output_chromosomes.txt"    # debugging output
		Array[Array[String]] grouped_files_as_strings = read_tsv("output_filenames.txt")
	}
}

task assoc_combine_r {
	input {
		Array[File] assoc_files
		String? assoc_type
		String? out_prefix = "" # not the default in CWL
		File? conditional_variant_file

		Boolean debug
		
		# runtime attr
		Int addldisk = 3
		Int cpu = 8
		Int memory = 8
		Int retries = 1
		Int preempt = 2
	}
	Int assoc_size = ceil(size(assoc_files, "GB"))
	Int cndvr_size = select_first([ceil(size(conditional_variant_file, "GB")), 0])
	Int finalDiskSize = assoc_size + cndvr_size + addldisk

	command <<<

		python << CODE
		import os

		def split_on_chromosome(file):
			chrom_num = file.split("chr")[1]
			return chrom_num
			
		def find_chromosome(file):
			chr_array = []
			chrom_num = split_on_chromosome(file)
			if len(chrom_num) == 1:
				acceptable_chrs = [str(integer) for integer in list(range(1,22))]
				acceptable_chrs.extend(["X","Y","M"])
				if chrom_num in acceptable_chrs:
					return chrom_num
				else:
					print("Error: %s appears to be an invalid chromosome number." % chrom_num)
					exit(1)
			elif (unicode(str(chrom_num[1])).isnumeric()):
				# two digit number
				chr_array.append(chrom_num[0])
				chr_array.append(chrom_num[1])
			else:
				# one digit number or Y/X/M
				chr_array.append(chrom_num[0])
			return "".join(chr_array)
		
		python_assoc_files = ['~{sep="','" assoc_files}']

		chr = find_chromosome(python_assoc_files[0])
		g = open("output_chromosomes.txt", "a")
		g.write("%s" % chr)
		g.close()
		
		f = open("assoc_combine.config", "a")
		f.write('assoc_type "~{assoc_type}"\n')
		data_prefix = os.path.basename(python_assoc_files[0]).split('_chr')[0]
		if "~{out_prefix}" != "":
			f.write('out_prefix "./~{out_prefix}"\n')
		else:
			f.write('out_prefix "./%s"\n' % data_prefix)
		if "~{conditional_variant_file}" != "":
			f.write('conditional_variant_file "~{conditional_variant_file}"\n')
		f.close()
		CODE

		# CWL's commands are scattered in different places so let's break it down here
		# Line numbers reference my fork's commit 196a734c2b40f9ab7183559f57d9824cffec20a1
		# Position   1: softlink RData ins (line 185 of CWL)
		# Position   5: Rscript call       (line 176 of CWL)
		# Position  10: chromosome flag    (line  97 of CWL)
		# Position 100: config file        (line 172 of CWL)
		# Note that chromosome has type Array[String] in CWL, but always has just 1 value

		THIS_CHR=`cat output_chromosomes.txt`

		FILES=(~{sep=" " assoc_files})
		for FILE in ${FILES[@]};
		do
			# Only link files related to this chromosome; the inability to find inputs that are
			# not softlinked or copied to the workdir actually helps us out here!
			if [[ "$FILE" =~ "chr$THIS_CHR" ]];
			then
				if [[ "~{debug}" =~ "true" ]];
				then
					echo "----------------------------"
					echo "File found with this sha1sum: "
					sha1sum ${FILE}
				fi
				cp ${FILE} .
			fi
		done

		if [[ "~{debug}" =~ "true" ]];
		then
			echo "----------------------------"
			echo "Here's the contents of this directory:"
			ls -lha
			echo "----------------------------"
			echo "Now, let's run the Rscript and hope for the best!"
		fi

		Rscript --verbose /usr/local/analysis_pipeline/R/assoc_combine.R --chromosome $THIS_CHR assoc_combine.config

		# Ideally we would now for FILE in ${FILES[@]}; do rm ${FILE}... but it does not work even
		# if we set up the Terra-specific chmod prior. Thankfully, the glob for our output always
		# grabs the correct file in my testing, but that may not be robust, as in theory it might
		# grab an input file by

		if [[ "~{debug}" =~ "true" ]];
		then
			echo "Final contents of directory: "
			ls -lha
		fi

	>>>

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:c564d54f5a3b9daed7a7677f860155f3b8c310b0771212c2eef1d6338f5c2600" # uwgac/topmed-master:2.12.0
		disks: "local-disk " + finalDiskSize + " HDD"
		maxRetries: "${retries}"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}

	output {
		File assoc_combined = glob("*.RData")[0]
		File config_file = glob("*.config")[0]
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

		Boolean debug

		# runtime attr
		Int addldisk = 3
		Int cpu = 8
		Int memory = 8
		Int retries = 1
		Int preempt = 2
	}
	Int assoc_size = ceil(size(assoc_files, "GB"))
	Int finalDiskSize = assoc_size + addldisk

	command <<<

		python << CODE
		import os

		def split_on_chromosome(file):
			chrom_num = file.split("chr")[1]
			return chrom_num
			
		def find_chromosome(file):
			chr_array = []
			chrom_num = split_on_chromosome(file)
			if len(chrom_num) == 1:
				acceptable_chrs = [str(integer) for integer in list(range(1,22))]
				acceptable_chrs.extend(["X","Y","M"])
				if chrom_num in acceptable_chrs:
					return chrom_num
				else:
					print("%s appears to be an invalid chromosome number." % chrom_num)
					exit(1)
			elif (unicode(str(chrom_num[1])).isnumeric()):
				# two digit number
				chr_array.append(chrom_num[0])
				chr_array.append(chrom_num[1])
			else:
				# one digit number or Y/X/M
				chr_array.append(chrom_num[0])
			return "".join(chr_array)

		python_assoc_files = ['~{sep="','" assoc_files}']

		if "~{debug}" == "true":
			print("Debug: Association files are %s" % python_assoc_files)

		f = open("assoc_file.config", "a")

		a_file = python_assoc_files[0]
		chr = find_chromosome(os.path.basename(a_file))
		path = a_file.split('chr'+chr)

		if "~{plots_prefix}" != "":
			f.write('plots_prefix ~{plots_prefix}\n')
			f.write('out_file_manh ~{plots_prefix}_manh.png\n')
			f.write('out_file_qq ~{plots_prefix}_qq.png\n')
		else:
			data_prefix = "testing"
			# CWL has var data_prefix = path[0].split('/').pop(); 
			# but I think that doesn't fit Terra file system
			f.write('out_file_manh %smanh.png\n' % data_prefix)
			f.write('out_file_qq %sqq.png\n' % data_prefix)
			f.write('plots_prefix "plots"\n')
		
		f.write('assoc_type ~{assoc_type}\n')

		assoc_file = path[0].split('/').pop() + 'chr ' + path[1]
		f.write('assoc_file "%s"\n' % assoc_file)

		chr_array = []
		for assoc_file in python_assoc_files:
			chrom_num = find_chromosome(assoc_file)
			chr_array.append(chrom_num)
		chrs = ' '.join(chr_array)
		f.write('chromosomes "%s "' % chrs)
		if "~{disable_thin}" != "":
			f.write('thin ~{disable_thin}\n')
		if "~{thin_npoints}" != "":
			f.write('thin_npoints ~{thin_npoints}\n')
		if "~{thin_nbins}" != "":
			f.write('thin_nbins ~{thin_nbins}\n')
		if "~{known_hits_file}" != "":
			f.write('known_hits_file "~{known_hits_file}"\n')
		if "~{plot_mac_threshold}" != "":
			f.write('plot_mac_threshold ~{plot_mac_threshold}\n')
		if "~{truncate_pval_threshold}" != "":
			f.write('truncate_pval_threshold ~{truncate_pval_threshold}\n')
		# plot qq, plot include file, signif type, signif fixed, qq mac bins, lambda, 
		# outfile lambadas, plot max, and maf threshold not used in the WDL version
		f.close()
		CODE

		# this block is considered prefix 1 in the CWL
		FILES=(~{sep=" " assoc_files})
		for FILE in ${FILES[@]};
		do
			ln -s ${FILE} .
		done

		Rscript /usr/local/analysis_pipeline/R/assoc_plots.R assoc_file.config

	>>>

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:c564d54f5a3b9daed7a7677f860155f3b8c310b0771212c2eef1d6338f5c2600" # uwgac/topmed-master:2.12.0
		disks: "local-disk " + finalDiskSize + " HDD"
		maxRetries: "${retries}"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}

	output {
		Array[File] assoc_plots = glob("*.png")
		File config_file = "assoc_file.config"
	}
}


workflow assoc_agg_one_gds {
	input {
		String       aggregate_type
		Float?       alt_freq_max
		Boolean      debug = false  # WDL only, turns on debug prints
		Boolean?     disable_thin
		String?      genome_build
		String?      group_id
		File?        known_hits_file
		File	     input_gds
		Int?         n_segments=1
		File         null_model_file
		String?      out_prefix
		Boolean?     pass_only
		File         phenotype_file
		Int?         plot_mac_threshold
		Array[Float]? rho
		Int?         segment_length
		String       test
		Int?         thin_nbins
		Int?         thin_npoints
		Float?       truncate_pval_threshold
		File         variant_group_file
		File? 	     variant_include_file
		File?        variant_weight_file
		String?      weight_beta
		String?      weight_user
		String	     chromosome
	}

	# In order to force this to run first, all other tasks that use these "psuedoenums"
	# (Strings that mimic type Enum from CWL) will take them in via outputs of this task
	call wdl_validate_inputs {
		input:
			genome_build = genome_build,
			aggregate_type = aggregate_type,
			test = test,
			chromosome = chromosome
	}

	
	call sbg_gds_renamer {
		input:
			in_variant = input_gds,
			debug = debug,
			noop = wdl_validate_inputs.valid_genome_build
	}
	
	call define_segments_r {
		input:
			segment_length = segment_length,
			n_segments = n_segments,
			genome_build = wdl_validate_inputs.valid_genome_build,
			chromosome = chromosome
	}
	
	call aggregate_list {
		input:
			variant_group_file = variant_group_file,
			aggregate_type = wdl_validate_inputs.valid_aggregate_type,
			group_id = group_id,
			chromosome = chromosome
	}
	
	# the range function returns [0, 1, 2 ..., actual_number_of_segments - 1 ]
	# we want [1, 2, 3 ..., actual_number_of_segments 
	
 	Array[Int] integers = range(define_segments_r.actual_number_of_segments)
	scatter(i in integers) {
		call assoc_aggregate {
				input:
					gds_file = input_gds,
					aggregate_file = aggregate_list.aggregate_list,
					variant_include_file = variant_include_file,
					null_model_file = null_model_file,
					phenotype_file = phenotype_file,
					out_prefix = out_prefix,
					rho = rho,
					segment_file = define_segments_r.define_segments_output,
					test = wdl_validate_inputs.valid_test,
					weight_beta = weight_beta,
					aggregate_type = wdl_validate_inputs.valid_aggregate_type,
					alt_freq_max = alt_freq_max,
					pass_only = pass_only,
					variant_weight_file = variant_weight_file,
					weight_user = weight_user,
					genome_build = wdl_validate_inputs.valid_genome_build,
					debug = debug,
					chromosome = chromosome,
					segment = i + 1
		}
    }
    
	Array[File] flatten_array  = flatten(select_all(assoc_aggregate.assoc_aggregate))
    
	call sbg_group_segments_1 {
			input:
				assoc_files = flatten_array,
				debug = debug
	}

	scatter(thing in sbg_group_segments_1.grouped_files_as_strings) {
		call assoc_combine_r {
			input:
				assoc_files = thing,
				assoc_type = "aggregate",
				debug = debug
		}
	}

	call assoc_plots_r {
		input:
			assoc_files = assoc_combine_r.assoc_combined,
			assoc_type = "aggregate",
			plots_prefix = out_prefix,
			disable_thin = disable_thin,
			known_hits_file = known_hits_file,
			thin_npoints = thin_npoints,
			thin_nbins = thin_nbins,
			plot_mac_threshold = plot_mac_threshold,
			truncate_pval_threshold = truncate_pval_threshold,
			debug = debug
	}

	output {
		Array[File] assoc_combined = assoc_combine_r.assoc_combined
		Array[File] assoc_plots = assoc_plots_r.assoc_plots
	}

	meta {
		author: "Ash O'Farrell / Alisa Manning"
		email: "aofarrel@ucsc.edu"
	}
}
