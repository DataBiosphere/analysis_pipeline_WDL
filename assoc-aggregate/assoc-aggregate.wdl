version 1.0
# WDL Author: Ash O'Farrell (UCSC)
# Based on code from the University of Washington Genome Analysis Center
# Please see https://doi.org/10.1093/bioinformatics/btz567

task wdl_validate_inputs {
	# WDL Only -- Validate inputs that are type enum in the CWL
	#
	# It is acceptable for the user to put nothing for these values. The R files
	# will fall back on the falling defaults if nothing is defined:
	# * genome_build: "hg38"
	# * aggregate_type: "allele"
	# * test: "burden" (note lowercase-B, not uppercase-B as indicated in CWL)
	
	input {
		String? genome_build
		String? aggregate_type
		String? test
		Int? num_gds_files

		# no runtime attr because this is a trivial task that does not scale
	}

	command <<<
		set -eux -o pipefail

		if [[ ~{num_gds_files} = 1 ]]
		then
			echo "Invalid input - you need to put it at least two GDS files (preferably consecutive ones, like chr1 and chr2)"
			exit 1
		fi

		#acceptable genome builds: ("hg38" "hg19")
		#acceptable aggreg types:  ("allele" "position")
		acceptable_test_values=("burden" "skat" "smmat" "fastskat" "skato")

		if [[ ! ~{genome_build} = "" ]]
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

		# this is ignored by the script itself, but including this stops this task from firing
		# before wdl_validate_inputs finishes
		String? noop

		Boolean debug = false

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
				Rscript /usr/local/analysis_pipeline/R/define_segments.R --segment_length ~{segment_length} --n_segments ~{n_segments} define_segments.config
			else
				# has only seg length
				Rscript /usr/local/analysis_pipeline/R/define_segments.R --segment_length ~{segment_length} define_segments.config
			fi
		else
			if [[ ! "~{n_segments}" = "" ]]
			then
				# has only n segs
				Rscript /usr/local/analysis_pipeline/R/define_segments.R --n_segments ~{n_segments} define_segments.config
			else
				# has no args
				Rscript /usr/local/analysis_pipeline/R/define_segments.R define_segments.config
			fi
		fi

	>>>
	
	runtime {
		cpu: cpu
		disks: "local-disk " + finalDiskSize + " HDD"
		docker: "uwgac/topmed-master@sha256:c564d54f5a3b9daed7a7677f860155f3b8c310b0771212c2eef1d6338f5c2600" # uwgac/topmed-master:2.12.0
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		File config_file = "define_segments.config"
		File define_segments_output = "segments.txt"
	}
}

task aggregate_list {
	input {
		File variant_group_file
		String? aggregate_type
		String? group_id

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

	String basename_vargroup = basename(variant_group_file)
	Int vargroup_size = ceil(size(variant_group_file, "GB"))
	Int finalDiskSize = vargroup_size + addldisk
	
	command <<<
		set -eux -o pipefail

		cp ~{variant_group_file} ~{basename_vargroup}

		python << CODE
		import os
		def find_chromosome(file):
			chr_array = []
			chrom_num = split_on_chromosome(file)
			if len(chrom_num) == 1:
				acceptable_chrs = [str(integer) for integer in list(range(1,22))]
				acceptable_chrs.extend(["X","Y","M"])
				print(acceptable_chrs)
				print(type(chrom_num))
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

		f = open("aggregate_list.config", "a")

		# This part of the CWL is a bit confusing so let's walk through it line by line

		#if (inputs.variant_group_file.basename.includes('chr'))
		if "chr" in "~{basename_vargroup}":

			#var chr = find_chromosome(inputs.variant_group_file.path);
			chr = find_chromosome("~{variant_group_file}")
			
			# The next part of the CWL is:
			#
			# chromosomes_basename = inputs.variant_group_file.path.slice(0,-6).replace(/\/.+\//g,"");
			#
			# We know that inputs.variant_group_file is RData, so slice(0,6) removes ".RData",
			# leaving a path with no extension. Then comes the regex in .replace():
			#
			# If given inputs/304343024/mygroupfile  --regex--> inputsmygroupfile.RData
			# If given /inputs/304343024/mygroupfile --regex--> mygroupfile
			#
			# The second is the clear intention, and seems to match CWL's behavior of including the
			# leading slash in file names. Interestingly, this seems to be equivalent to the CWL
			# built-in nameroot function. CWL nameroot = python basename iff we drop the extension,
			# so we mimic their slicing of the last six characters, but not the regex.
			chromosomes_basename = os.path.basename("~{variant_group_file}"[:-6])

			
			# for(i = chromosomes_basename.length - 1; i > 0; i--)
			for i in range(0, len(chromosomes_basename)):

				#if(chromosomes_basename[i] != 'X' && chromosomes_basename[i] != "Y" && isNaN(chromosomes_basename[i]))
				if chromosomes_basename[i] not in ["X","Y","1","2","3","4","5","6","7","8","9","0"]:
					
					#break;
					break
			
			# Finally, after all that, chromosomes_basename gets overwritten anyway
			chromosomes_basename_1 = "~{basename_vargroup}".split('chr'+chr)[0]
			chromosomes_basename_2 = "chr "
			chromosomes_basename_3 = "~{basename_vargroup}".split('chr'+chr)[1]
			chromosomes_basename = chromosomes_basename_1 + chromosomes_basename_2 + chromosomes_basename_3
			
			f.write('variant_group_file "%s"\n' % chromosomes_basename)
		
		else:
			f.write('variant_group_file "~{basename_vargroup}"\n')

		# If there is a chr in the variant group file, a chr must be present in the output file
		if "~{out_file}" != "":
			if "chr" in "~{out_file}":
				f.write('out_file "~{out_file} .RData"\n')
			else:
				f.write('out_file "~{out_file}.RData"\n')
		else:
			if "chr" in "~{basename_vargroup}":
				f.write('out_file "aggregate_list_chr .RData"\n')
			else:
				f.write('out_file "aggregate_list.RData"\n')

		if "~{aggregate_type}" != "":
			f.write('aggregate_type "~{aggregate_type}"\n')

		if "~{group_id}" != "":
			f.write('group_id "~{group_id}"\n')

		f.write("\n")
		f.close()

		# this corresponds to line 195 of CWL
		if "chr" in "~{basename_vargroup}":
			chromosome = find_chromosome("~{variant_group_file}")
			g = open("chromosome", "a")
			g.write("--chromosome %s" % chromosome)
			g.close()
		CODE

		BASH_CHR=./chromosome
		if test -f "$BASH_CHR"
		then
			Rscript /usr/local/analysis_pipeline/R/aggregate_list.R aggregate_list.config $(cat ./chromosome)
		else
			Rscript /usr/local/analysis_pipeline/R/aggregate_list.R aggregate_list.config
		fi
	>>>

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:c564d54f5a3b9daed7a7677f860155f3b8c310b0771212c2eef1d6338f5c2600" # uwgac/topmed-master:2.12.0
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		File aggregate_list = glob("aggregate_list*.RData")[0]
		File config_file = "aggregate_list.config"
	}
}

task sbg_prepare_segments_1 {
	# Actually creates segment files.
	#
	# This implementation combines the CWL's baseCommand and its multiple outputEvals in one Python 
	# block, as WDL does not have an outputEval equivalent. The Python block is mirrored in this
	# repo as prepare_segments_1.py and I recommend you use that if you are modifying this task.
	#
	# Although the format of the outputs are different from the CWL, the actual contents of each
	# component (gds, segment number, and agg file) should match the CWL perfectly (barring compute
	# platform differences, etc). The format is a zip file containing each segment's components in
	# order to work around WDL's limitations. Essentially, CWL easily scatters on the dot-product
	# multiple arrays, but trying to that in WDL is painful. See cwl-vs-wdl-dev.md for more info.

	input {
		Array[File] input_gds_files
		File segments_file
		Array[File] aggregate_files
		Array[File]? variant_include_files

		# runtime attr
		Int addldisk = 10
		Int cpu = 2
		Int memory = 4
		Int preempt = 2
	}

	# estimate disk size required
	Int gds_size = 2 * ceil(size(input_gds_files, "GB"))
	Int seg_size = 2 * ceil(size(segments_file, "GB"))
	Int agg_size = 2 * ceil(size(aggregate_files, "GB"))
	Int dsk_size = gds_size + seg_size + agg_size + addldisk
	
	command <<<
		set -eux -o pipefail
		cp ~{segments_file} .

		# The CWL only copies the segments file, but this implementation copies everything else so
		# we can zip them at the end more easily. This may also be required for drs:// inputs.

		GDS_FILES=(~{sep=" " input_gds_files})
		for GDS_FILE in ${GDS_FILES[@]};
		do
			cp ${GDS_FILE} .
		done
		
		AGG_FILES=(~{sep=" " aggregate_files})
		for AGG_FILE in ${AGG_FILES[@]};
		do
			cp ${AGG_FILE} .
		done

		if [[ ! "~{sep="" variant_include_files}" = "" ]]
		then
			VAR_FILES=(~{sep=" " variant_include_files})
			for VAR_FILE in ${VAR_FILES[@]};
			do
				cp ${VAR_FILE} .
			done
		fi

		python << CODE
		IIsegments_fileII = "~{segments_file}"
		IIinput_gds_filesII = ['~{sep="','" input_gds_files}']
		IIvariant_include_filesII = ['~{sep="','" variant_include_files}']
		IIaggregate_filesII = ['~{sep="','" aggregate_files}']

		from zipfile import ZipFile
		import os
		import shutil

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

		def pair_chromosome_gds(file_array):
			gdss = dict() # forced to use constructor due to WDL syntax issues
			for i in range(0, len(file_array)): 
				# Key is chr number, value is associated GDS file
				this_chr = find_chromosome(file_array[i])
				if this_chr == "X":
					gdss[23] = os.path.basename(file_array[i])
				elif this_chr == "Y":
					gdss[24] = os.path.basename(file_array[i])
				elif this_chr == "M":
					gdss[25] = os.path.basename(file_array[i])
				else:
					gdss[int(this_chr)] = os.path.basename(file_array[i])
			return gdss

		def pair_chromosome_gds_special(file_array, agg_file):
			gdss = dict()
			for i in range(0, len(file_array)):
				gdss[int(find_chromosome(file_array[i]))] = os.path.basename(agg_file)
			return gdss

		def wdl_get_segments():
			segfile = open(IIsegments_fileII, 'rb')
			segments = str((segfile.read(64000))).split('\n') # CWL x.contents only gets 64000 bytes
			segfile.close()
			segments = segments[1:] # remove first line
			return segments

		# prepare GDS output
		input_gdss = pair_chromosome_gds(IIinput_gds_filesII)
		output_gdss = []
		gds_segments = wdl_get_segments()
		for i in range(0, len(gds_segments)): # for(var i=0;i<segments.length;i++){
			try:
				chr = int(gds_segments[i].split('\t')[0])
			except ValueError: # chr X, Y, M
				chr = gds_segments[i].split('\t')[0]
			if(chr in input_gdss):
				output_gdss.append(input_gdss[chr])
		gds_output_hack = open("gds_output_debug.txt", "w")
		gds_output_hack.writelines(["%s " % thing for thing in output_gdss])
		gds_output_hack.close()

		# prepare segment output
		input_gdss = pair_chromosome_gds(IIinput_gds_filesII)
		output_segments = []
		actual_segments = wdl_get_segments()
		for i in range(0, len(actual_segments)): # for(var i=0;i<segments.length;i++){
			try:
				chr = int(actual_segments[i].split('\t')[0])
			except ValueError: # chr X, Y, M
				chr = actual_segments[i].split('\t')[0]
			if(chr in input_gdss):
				seg_num = i+1
				output_segments.append(seg_num)
				output_seg_as_file = open("%s.integer" % seg_num, "w")
		
		# I don't know for sure if this case is actually problematic, but I suspect it will be.
		if max(output_segments) != len(output_segments):
			print("ERROR: output_segments needs to be a list of consecutive integers.")
			print("Debug: Max of list: %s. Len of list: %s." % 
				[max(output_segments), len(output_segments)])
			print("Debug: List is as follows:\n\t%s" % output_segments)
			exit(1)
		segs_output_hack = open("segs_output_debug.txt", "w")
		segs_output_hack.writelines(["%s " % thing for thing in output_segments])
		segs_output_hack.close()

		# prepare aggregate output
		# The CWL accounts for there being no aggregate files as the CWL considers them an optional
		# input. We don't need to account for that because the way WDL works means it they are a
		# required output of a previous task and a required input of this task. That said, if this
		# code is reused for other WDLs, it may need some adjustments right around here.
		input_gdss = pair_chromosome_gds(IIinput_gds_filesII)
		agg_segments = wdl_get_segments()
		if 'chr' in os.path.basename(IIaggregate_filesII[0]):
			input_aggregate_files = pair_chromosome_gds(IIaggregate_filesII)
		else:
			input_aggregate_files = pair_chromosome_gds_special(IIinput_gds_filesII, IIaggregate_filesII[0])
		output_aggregate_files = []
		for i in range(0, len(agg_segments)): # for(var i=0;i<segments.length;i++){
			try: 
				chr = int(agg_segments[i].split('\t')[0])
			except ValueError: # chr X, Y, M
				chr = agg_segments[i].split('\t')[0]
			if(chr in input_aggregate_files):
				output_aggregate_files.append(input_aggregate_files[chr])
			elif (chr in input_gdss):
				output_aggregate_files.append(None)

		# prepare variant include output
		input_gdss = pair_chromosome_gds(IIinput_gds_filesII)
		var_segments = wdl_get_segments()
		if IIvariant_include_filesII != [""]:
			input_variant_files = pair_chromosome_gds(IIvariant_include_filesII)
			output_variant_files = []
			for i in range(0, len(var_segments)):
				try:
					chr = int(var_segments[i].split('\t')[0])
				except ValueError: # chr X, Y, M
					chr = var_segments[i].split('\t')[0]
				if(chr in input_variant_files):
					output_variant_files.append(input_variant_files[chr])
				elif(chr in input_gdss):
					output_variant_files.append(None)
				else:
					pass
		else:
			null_outputs = []
			for i in range(0, len(var_segments)):
				try:
					chr = int(var_segments[i].split('\t')[0])
				except ValueError: # chr X, Y, M
					chr = var_segments[i].split('\t')[0]
				if(chr in input_gdss):
					null_outputs.append(None)
			output_variant_files = null_outputs
		var_output_hack = open("variant_output_debug.txt", "w")
		var_output_hack.writelines(["%s " % thing for thing in output_variant_files])
		var_output_hack.close()

		# We can only consistently tell output files apart by their extension. If var include files 
		# and agg files are both outputs, this is problematic, as they both share the RData ext.
		# Therefore we put var include files in a subdir.
		if IIvariant_include_filesII != [""]:
			os.mkdir("varinclude")
			os.mkdir("temp")

		# make a bunch of zip files
		for i in range(0, max(output_segments)):
			plusone = i+1
			this_zip = ZipFile("dotprod%s.zip" % plusone, "w", allowZip64=True)
			this_zip.write("%s" % output_gdss[i])
			this_zip.write("%s.integer" % output_segments[i])
			this_zip.write("%s" % output_aggregate_files[i])
			if IIvariant_include_filesII != [""]:
				print("We detected %s as an output variant file." % output_variant_files[i])
				try:
					# Both the CWL and the WDL basically have duplicated output wherein each
					# segment for a given chromosome get the same var include output. If you
					# have six segments that cover chr2, then each segment will get the same
					# var include file for chr2.
					# Because we are handling output with zip files, we need to keep copying
					# the variant include file. The CWL does not need to do this.

					# make a temporary copy in the temp directory
					shutil.copy(output_variant_files[i], "temp/%s" % output_variant_files[i])
					
					# move the not-copy into the varinclude subdirectory
					os.rename(output_variant_files[i], "varinclude/%s" % output_variant_files[i])
					
					# return the copy to the workdir
					shutil.move("temp/%s" % output_variant_files[i], output_variant_files[i])
				
				except OSError:
					# Variant include for this chr has already been taken up and zipped.
					# The earlier copy should stop this but permissions can get iffy on
					# Terra, so we should at least catch the error here for debugging.
					print("Variant include file appears unavailable. Exiting disgracefully...")
					exit(1)
				
				this_zip.write("varinclude/%s" % output_variant_files[i])
			this_zip.close()
		CODE
	>>>

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:c564d54f5a3b9daed7a7677f860155f3b8c310b0771212c2eef1d6338f5c2600" # uwgac/topmed-master:2.12.0
		disks: "local-disk " + dsk_size + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}

	output {
		# Each zip contains one GDS, one file w/ an integer representing seg number, one aggregate
		# RData file, and maybe a var include.
		Array[File] dotproduct = glob("*.zip")
	}
}

task assoc_aggregate {
	# This is the meat-and-potatoes of this pipeline. It is parallelized on a segment basis, with
	# each instance of this task getting a zipped file containing all the files associated with a
	# segment. Note that this task contains several workarounds specific to the Terra file system.

	input {
		File zipped # from the previous task; replaces some of the CWL inputs
		File segment_file # NOT the same as segment
		File null_model_file
		File phenotype_file
		String? out_prefix
		Array[Float]? rho
		String? test # acts as enum
		String? weight_beta
		Int? segment # not used in WDL
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

		Boolean debug = false
	}
	
	# estimate disk size required
	Int zipped_size = ceil(size(zipped, "GB"))*5 # not sure how much zip compresses them if at all
	Int segment_size = ceil(size(segment_file, "GB"))
	Int null_size = ceil(size(null_model_file, "GB"))
	Int pheno_size = ceil(size(phenotype_file, "GB"))
	Int varweight_size = select_first([ceil(size(variant_weight_file, "GB")), 0])
	Int finalDiskSize = zipped_size + segment_size + null_size + pheno_size + varweight_size + addldisk

	command <<<

		# Unzipping in the inputs directory leads to a host of issues as depending on the platform
		# they will end up in different places. Copying them to our own directory avoids an awkward
		# workaround, at the cost of relying on permissions cooperating.
		echo "Copying zipped inputs..."
		mkdir ins
		cp ~{zipped} ./ins
		cd ins
		echo "Unzipping..."
		unzip ./*.zip
		cd ..

		if [[ "~{debug}" = "true" ]]
		then
			echo "Debug: Contents of makeshift input dir (NOT the standard Cromwell inputs dir) is:"
			ls ins/
			echo "Debug: Contents of current workdir is:"
			ls
		fi

		echo ""
		echo "Calling Python..."
		python << CODE
		import os

		def wdl_find_file(extension):
			dir = os.getcwd()
			ls = os.listdir(dir)
			if "~{debug}" == "true":
				print("Debug: Looking for %s in %s which contains %s" % (extension, dir, ls))
			for i in range(0, len(ls)):
				debug_split = ls[i].rsplit(".", 1)
				if "~{debug}" == "true":
					print("Debug: ls[i].rsplit('.', 1) is %s" % debug_split)
				if len(ls[i].rsplit('.', 1)) == 2: # avoid stderr and stdout giving IndexError
					if ls[i].rsplit(".", 1)[1] == extension:
						return ls[i].rsplit(".", 1)[0]
			return None

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

		os.chdir("ins")
		gds = wdl_find_file("gds") + ".gds"
		agg = wdl_find_file("RData") + ".RData"
		seg = int(wdl_find_file("integer").rsplit(".", 1)[0]) # not used in Python context

		# If there is a varinclude dir, then there is a variant include file. We briefly chdir into
		# the varinclude dir to avoid grabbing the assoc RData file by mistake.
		if os.path.isdir("varinclude"):
			os.chdir("varinclude")
			name_no_ext = wdl_find_file("RData")
			os.chdir("..")
			if type(name_no_ext) != None:
				source = "".join([os.getcwd(), "/varinclude/", name_no_ext, ".RData"])
				destination = "".join([os.getcwd(), "/", name_no_ext, ".RData"])
				if "~{debug}" == "true":
					# Terra permissions can get a little tricky
					print("Debug: Source is %s" % source)
					print("Debug: Destination is %s" % destination)
					print("Debug: Renaming...")
				os.rename(source, destination)
				var = destination

		chr = find_chromosome(gds) # runs on full path in the CWL
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
				f.write('out_prefix "' + data_prefix2[0] + '_aggregate_chr' + chr + os.path.basename(gds).split('chr'+chr)[1].split('.gds')[0] + '"'+ "\n")
			else:
				f.write('out_prefix "' + data_prefix[0]  + 'aggregate_chr'  + chr + os.path.basename(gds).split('chr'+chr)[1].split('.gds')[0] + '"' + "\n")

		dir = os.getcwd()
		f.write('gds_file "%s/%s"\n' % (dir, gds))
		f.write('phenotype_file "~{phenotype_file}"\n')
		f.write('aggregate_variant_file "%s/%s"\n' % (dir, agg))
		f.write('null_model_file "~{null_model_file}"\n')
		# CWL accounts for null_model_params but this does not exist in aggregate context
		if "~{rho}" != "":
			f.write("rho ")
			for r in ['~{sep="','" rho}']:
				f.write("%s " % r)
			f.write("\n")
		f.write('segment_file "~{segment_file}"\n') # optional in CWL, never optional in WDL
		if "~{test}" != "":
			f.write('test "~{test}"\n') # cwl has test type, not sure if needed here
		if os.path.isdir("varinclude"):
			# although moved to the workdir, the folder previously containing it should still exist
			f.write('variant_include_file "%s"\n' % var)
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

		# copy config file; it's in a subdirectory at the moment
		cp ./ins/assoc_aggregate.config .

		if [[ "~{debug}" = "true" ]]
		then
			echo "Debug: Location of file(s):"
			echo ""
			find -name *.config
			echo "Debug: Location of file(s) representing chromosome number:"
			echo ""
			find -name *.integer
			echo ""
			echo "Debug: Searching for the segment number or letter in input directory..."
		fi
		
		cd ins/
		SEGMENT_NUM=$(find -name "*.integer" | sed -e 's/\.integer$//' | sed -e 's/.\///')
		cd ..

		if [[ "~{debug}" = "true" ]]
		then
			echo "Debug: Segment number is: "
			echo $SEGMENT_NUM
		fi

		echo ""
		echo "Running Rscript..."
		Rscript /usr/local/analysis_pipeline/R/assoc_aggregate.R assoc_aggregate.config --segment ${SEGMENT_NUM}
		# The CWL has a commented out method for adding --chromosome to this. It's been replaced by
		# the inputBinding for segment number, which we have to extract from a filename rather than
		# an input variable.

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
		bootDiskSizeGb: 6
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		# Do not change this to Array[File?] as that will break everything. The files within the
		# array cannot be optional, instead, we make the array itself optional to account for 
		# segments that do not give output. Working with Array[File?] is infinitely more difficult 
		# than working with Array[File]?, trust me on this.
		Array[File]? assoc_aggregate = glob("*.RData")
		File config = glob("ins/*.config")[0]
	}
}

task sbg_group_segments_1 {
	input {
		Array[String] assoc_files
		Boolean debug = false

		# runtime attr
		Int addldisk = 3
		Int cpu = 8
		Int memory = 8
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

		Boolean debug = true
		
		# runtime attr
		Int addldisk = 3
		Int cpu = 8
		Int memory = 8
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
			f.write('out_prefix "~{out_prefix}"\n')
		else:
			f.write('out_prefix "%s"\n' % data_prefix)
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

		Boolean debug = false

		# runtime attr
		Int addldisk = 3
		Int cpu = 8
		Int memory = 8
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

		# hardcoded in the CWL
		f.write('out_prefix "assoc_single"\n')

		a_file = python_assoc_files[0]
		chr = find_chromosome(os.path.basename(a_file))
		path = a_file.split('chr'+chr)
		extension = path[1].rsplit('.')[-1] # note different logic from CWL

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
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}

	output {
		Array[File] assoc_plots = glob("*.png")
		File config_file = "assoc_file.config"
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

	Int num_gds_files = length(input_gds_files)

	# In order to force this to run first, all other tasks that use these "psuedoenums"
	# (Strings that mimic type Enum from CWL) will take them in via outputs of this task
	call wdl_validate_inputs {
		input:
			genome_build = genome_build,
			aggregate_type = aggregate_type,
			test = test,
			num_gds_files = num_gds_files
	}

	scatter(gds_file in input_gds_files) {
		call sbg_gds_renamer {
			input:
				in_variant = gds_file,
				noop = wdl_validate_inputs.valid_genome_build
		}
	}
	
	call define_segments_r {
		input:
			segment_length = segment_length,
			n_segments = n_segments,
			genome_build = wdl_validate_inputs.valid_genome_build
	}

	scatter(variant_group_file in variant_group_files) {
		call aggregate_list {
			input:
				variant_group_file = variant_group_file,
				aggregate_type = wdl_validate_inputs.valid_aggregate_type,
				group_id = group_id
		}
	}

	call sbg_prepare_segments_1 {
		input:
			input_gds_files = sbg_gds_renamer.renamed_variants,
			segments_file = define_segments_r.define_segments_output,
			aggregate_files = aggregate_list.aggregate_list,
			variant_include_files = variant_include_files
	}
 
    # gds, aggregate, segments, and variant include are represented as a zip file here
	scatter(gdsegregatevar in sbg_prepare_segments_1.dotproduct) {
		call assoc_aggregate {
			input:
				zipped = gdsegregatevar,
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
				genome_build = wdl_validate_inputs.valid_genome_build
	
		}
	}

	Array[File] flatten_array = flatten(select_all(assoc_aggregate.assoc_aggregate))
	call sbg_group_segments_1 {
			input:
				assoc_files = flatten_array
	}

	scatter(thing in sbg_group_segments_1.grouped_files_as_strings) {
		call assoc_combine_r {
			input:
				assoc_files = thing,
				assoc_type = "aggregate"
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
			truncate_pval_threshold = truncate_pval_threshold
	}

	output {
		Array[File] assoc_combined = assoc_combine_r.assoc_combined
		Array[File] assoc_plots = assoc_plots_r.assoc_plots
	}

	meta {
		author: "Ash O'Farrell"
		email: "aofarrel@ucsc.edu"
	}
}
