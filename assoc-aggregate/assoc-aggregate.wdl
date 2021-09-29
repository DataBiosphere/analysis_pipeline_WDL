version 1.0

task wdl_validate_inputs {
	# WDL Only -- Validate inputs that are type enum in the CWL
	input {
		String? genome_build
		String? aggregate_type
		String? test

		# no runtime attr because this is a trivial task that does not scale
	}

	command <<<
		set -eux -o pipefail
		acceptable_genome_builds=("hg38" "hg19")
		acceptable_aggreg_types=("allele" "position")
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
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		preemptibles: 3
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

		# runtime attributes, which you shouldn't need
		Int addldisk = 3
		Int cpu = 2
		Int memory = 4
		Int preempt = 3
	}
	
	Int gds_size = ceil(size(in_variant, "GB"))
	Int finalDiskSize = gds_size*2 + addldisk
	
	command <<<
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

		print("Debug: Getting nameroot")
		nameroot = os.path.basename("~{in_variant}").rsplit(".", 1)[0]
		chr = find_chromosome(nameroot)
		base = nameroot.split('chr'+chr)[0]
		newname = base+'chr'+chr+".gds"

		os.rename("~{in_variant}", newname)

		CODE

	>>>

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		File renamed_variants = glob("*.gds")[0]
		# Although there are two gds files lying around, only the one that's in the parent directory
		# should get matched here according to my testing.
	}
}

task define_segments_r {
	# This task divides the entire genome into segments, regardless of the number of chromosomes you are working with.
	# For example, if you set n_segments to 100, but only run on chr1 and chr2, you can expect there to be about 15
	# segments as chr1 and chr2 together represent about 15% of the entire genome.
	# These segments exist in attempt to allow for parallel processing of different chunks of the genome in later steps.
	# As an absolute minimum, you will end up with one segment per chromosome.
	input {
		Int? segment_length
		Int? n_segments
		String? genome_build

		# runtime attributes, which you shouldn't need, although in fairness hg38 might need more oomph than this
		Int cpu = 2
		Int memory = 4
		Int preempt = 3
	}
	
	Int finalDiskSize = 10
	
	command <<<
		python << CODE
		import os
		f = open("define_segments.config", "a")
		f.write('out_file "segments.txt"\n')
		if "~{genome_build}" != "":
			f.write('genome_build "~{genome_build}"\n')
		f.close()
		CODE

		# this could probably be improved
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
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
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

		# The parent CWL does not have out_file, but it does have out_prefix
		# The task CWL does not have out_prefix, but it does have out_file
		String? out_file

		# runtime attr
		Int addldisk = 1
		Int cpu = 2
		Int memory = 4
		Int preempt = 2
	}
	# Basenames
	String basename_vargroup = basename(variant_group_file)
	# Estimate disk size required
	Int vargroup_size = ceil(size(variant_group_file, "GB"))
	Int finalDiskSize = vargroup_size + addldisk
	command <<<
		set -eux -o pipefail

		cp ~{variant_group_file} ~{basename_vargroup} # check if should be .

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

		# This part of the CWL is a bit confusing and I'd like some extra eyes on it
		if "chr" in "~{basename_vargroup}": #if (inputs.variant_group_file.basename.includes('chr'))
			chr = find_chromosome("~{variant_group_file}") #var chr = find_chromosome(inputs.variant_group_file.path);
			
			# CWL then has:
			# chromosomes_basename = inputs.variant_group_file.path.slice(0,-6).replace(/\/.+\//g,"");
			# We know that this file is expected to be RData so I assume slice(0,6) is to remove ".RData" leaving a path with no extension.
			# If given inputs/304343024/mygroupfile the regex would return inputsmygroupfile.RData which obviously isn't correct.
			# If given /inputs/304343024/mygroupfile the regex would return mygroupfile which seems to be the intention.
			# This ought to be equivalent to the CWL nameroot function, which these CWLs use extensively, so I'm not sure why they get fancy here.
			chromosomes_basename = os.path.basename("~{variant_group_file}"[:-6])

			# The CWL is then followed by a section that doesn't seem to do anything...
			# This would iterate through the string character-by-character. If it comes across a non-number that isn't X or Y, it stops
			# iterating. But... why iterate in the first place?
			for i in range(0, len(chromosomes_basename)): #for(i = chromosomes_basename.length - 1; i > 0; i--)
				if chromosomes_basename[i] not in ["X","Y","1","2","3","4","5","6","7","8","9","0"]: #	if(chromosomes_basename[i] != 'X' && chromosomes_basename[i] != "Y" && isNaN(chromosomes_basename[i]))
					break #	break;
			
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
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		# https://github.com/UW-GAC/analysis_pipeline_cwl/blob/c2eb59b17fac96412961106be1749692bba12bbb/association/tools/aggregate_list.cwl#L118
		File aggregate_list = glob("aggregate_list*.RData")[0]
		File config_file = "aggregate_list.config"
	}
}

task sbg_prepare_segments_1 {
	# Although the format of the outputs are different from the CWL, the actual
	# contents of each component (gds, segment number, and agg file) should match
	# the CWL perfectly. This code essentially combines the CWL's baseCommand and
	# its multiple outputEvals in one Python block I am perhaps unfairly proud of.
	input {
		Array[File] input_gds_files
		File segments_file
		Array[File] aggregate_files
		Array[File]? variant_include_files

		# runtime attr
		Int addldisk = 1
		Int cpu = 2
		Int memory = 4
		Int preempt = 2
	}

	# disk size calculation goes here
	
	command <<<
		cp ~{segments_file} .

		# The CWL only copies the segments file, but copying everything else
		# will allow us to zip them without the zip having subfolders. I think
		# this is also required to get drs and gs working correctly.

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
				gdss[int(find_chromosome(file_array[i]))] = os.path.basename(file_array[i])
				i += 1
			return gdss

		def pair_chromosome_gds_special(file_array, agg_file):
			gdss = dict()
			for i in range(0, len(file_array)):
				gdss[int(find_chromosome(file_array[i]))] = os.path.basename(agg_file)
			return gdss

		def wdl_get_segments():
			segfile = open(IIsegments_fileII, 'rb')
			segments = str((segfile.read(64000))).split('\n') # var segments = self[0].contents.split('\n');
			segfile.close()
			segments = segments[1:] # segments = segments.slice(1) # cut off the first line
			return segments

		# Prepare GDS output
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

		# Prepare segment output
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
		if max(output_segments) != len(output_segments): # I don't know if this case is actually problematic but I suspect it will be.
			print("ERROR: Subsequent code relies on output_segments being a list of consecutive integers.")
			print("Debug information: Max of list is %s, len of list is %s" % [max(output_segments), len(output_segments)])
			print("Debug information: List is as follows:\n\t%s" % output_segments)
			exit(1)
		segs_output_hack = open("segs_output_debug.txt", "w")
		segs_output_hack.writelines(["%s " % thing for thing in output_segments])
		segs_output_hack.close()

		# Prepare aggregate output
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
		# The CWL accounts for there being no aggregate files, as the CWL considers them an optional
		# input. We don't need to account for that because the way WDL works means it they are a
		# required output of a previous task and a required input of this task. That said, if this
		# code is reused for other WDLs, it may need some adjustments right around here.

		# Prepare variant include output
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

		# Make a bunch of zip files
		for i in range(0, max(output_segments)):
			plusone = i+1
			this_zip = ZipFile("dotprod%s.zip" % plusone, "w")
			this_zip.write("%s" % output_gdss[i])
			this_zip.write("%s.integer" % output_segments[i])
			this_zip.write("%s" % output_aggregate_files[i])
			if IIvariant_include_filesII != [""]: # not sure if this is robust
				# We can only consistently tell zipped files apart by their
				# extension. var include and agg will share the RData ext.
				# Therefore we put varinat include files in a subdirectory.
				os.mkdir("varinclude")
				os.rename(output_variant_files[i], "varinclude/%s" % output_variant_files[i])
				this_zip.write("varinclude/%s" % output_variant_files[i])
				#nameroot = os.path.basename(output_variant_files[i]).rsplit(".", 1)[0]
				#newname = nameroot + ".ofarrell"
				#os.rename(output_variant_files[i], newname)
				#this_zip.write("%s" % newname)
			this_zip.close()
		CODE
	>>>

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + 50 + " HDD" # fix this
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}

	output {
		# This varies heavily from the CWL due to limitations on WDL outputs and dotproduct scatters -- afaik, this is the only way!
		# Each zip contains one GDS, one file with an integer representing seg number, one aggregate RData, and maybe a var include
		Array[File] dotproduct = glob("*.zip")
	}
}

task assoc_aggregate {
	input {
		File zipped

		# other inputs
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
	}
	# Estimate disk size required
	Int zipped_size = ceil(size(zipped, "GB"))*5 # not sure how much zip compresses them if at all
	Int segment_size = ceil(size(segment_file, "GB"))
	Int null_size = ceil(size(null_model_file, "GB"))
	Int pheno_size = ceil(size(phenotype_file, "GB"))
	Int varweight_size = select_first([ceil(size(variant_weight_file, "GB")), 0])
	Int finalDiskSize = zipped_size + segment_size + null_size + pheno_size + varweight_size + addldisk

	command <<<

		echo "Copying and unzipping zipped inputs..."
		cp ~{zipped} . # copy because I don't want to deal with finding what directory these files would otherwise unzip into
		unzip ./*.zip

		echo "Setting the never-been-zipped inputs to modifiable on Terra..."
		# this is to prevent false positive later on when detecting if output RData file exists
		find . -type d -exec sudo chmod -R 777 {} +

		echo ""
		echo "Get the name of all RData input files in the workdir..."
		DESTROY_THIS_FILE=$(find -name "*.RData")
		echo $DESTROY_THIS_FILE
		
		echo ""
		echo "Calling Python..."
		python << CODE
		import os

		def wdl_find_file(extension):
			print("Debug: Looking for %s" % extension)
			ls = os.listdir(os.getcwd())
			for i in range(0, len(ls)):
				debug = ls[i].rsplit(".", 1)
				print("Debug: ls[i].rsplit('.', 1) is %s, we now check its value at index one" % debug)
				if len(ls[i].rsplit('.', 1)) == 2: # avoid stderr and stdout giving IndexError
					if ls[i].rsplit(".", 1)[1] == extension:
						return ls[i].rsplit(".", 1)[0]
				i += 1
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

		gds = wdl_find_file("gds") + ".gds"
		agg = wdl_find_file("RData") + ".RData"
		seg = int(wdl_find_file("integer").rsplit(".", 1)[0])
		if os.path.isdir("varinclude"):
			os.chdir("varinclude") # not sure if that's the right syntax
			var = "/varinclude/" + wdl_find_file("RData") + ".RData"
			if type(var) != None:
				newname = [var.rsplit(".", 1)[0], ".RData"].join
				os.rename(var, newname)
			os.chrdir("..") # not sure if that's the right syntax

		chr = find_chromosome(gds) # runs on FULL PATH in the CWL
		f = open("assoc_aggregate.config", "a")
		
		if "~{out_prefix}" != "":
			f.write("out_prefix '~{out_prefix}_chr%s'\n" % chr)
		else:
			data_prefix = os.path.basename(gds).split('chr') # runs on BASENAME in the CWL
			data_prefix2 = os.path.basename(gds).split('.chr')
			if len(data_prefix) == len(data_prefix2):
				f.write('out_prefix "' + data_prefix2[0] + '_aggregate_chr' + chr + os.path.basename(gds).split('chr'+chr)[1].split('.gds')[0] + '"'+ "\n")
			else:
				f.write('out_prefix "' + data_prefix[0]  + 'aggregate_chr'  + chr + os.path.basename(gds).split('chr'+chr)[1].split('.gds')[0] + '"' + "\n")

		f.write("gds_file '%s'\n" % gds)
		f.write("phenotype_file '~{phenotype_file}'\n")
		f.write("aggregate_variant_file '%s'\n" % agg)
		f.write("null_model_file '~{null_model_file}'\n")
		# CWL accounts for null_model_params but this does not exist in aggregate context
		if "~{rho}" != "":
			f.write("rho ")
			for r in ['~{sep="','" rho}']:
				f.write("%s " % r)
			f.write("\n")
		f.write("segment_file '~{segment_file}'\n") # never optional in WDL
		if "~{test}" != "":
			f.write("test '~{test}'\n")
		# cwl has test type, not sure if needed here
		# cwl has variant include file
		if "~{weight_beta}" != "":
			f.write("weight_beta '~{weight_beta}'\n")
		if "~{aggregate_type}" != "":
			f.write("aggregate_type '~{aggregate_type}'\n")
		if "~{alt_freq_max}" != "":
			f.write("alt_freq_max ~{alt_freq_max}\n")
		
		# pass_only is odd in the CWL. It only gets written to the config file
		# if the user does not set the value at all.
		if "~{pass_only}" == "":
			f.write("pass_only FALSE\n")
		
		if "~{variant_weight_file}" != "":
			f.write("variant_weight_file '~{variant_weight_file}'\n")
		if "~{weight_user}" != "":
			f.write("weight_user '~{weight_user}'\n")
		if "~{genome_build}" != "":
			f.write("genome_build '~{genome_build}'\n")
		f.close()

		CODE

		echo ""
		echo "Current contents of working directory are:"
		ls

		echo ""
		echo "Searching for the segment number..."
		SEGMENT_NUM=$(find -name "*.integer" | sed -e 's/\.integer$//' | sed -e 's/.\///')
		echo $SEGMENT_NUM

		echo ""
		echo "Running Rscript..."
		Rscript /usr/local/analysis_pipeline/R/assoc_aggregate.R assoc_aggregate.config --segment ${SEGMENT_NUM}
		# The CWL has a commented out method for including --chromosome to this
		# It's likely been replaced by the inputBinding for segment number, which we have to extract from
		# a filename rather than an input variable

		echo ""
		echo "Deleting RData input files to avoid globbing the wrong output..."
		# The CWL globs on *.RData (the earlier stuff reliant on out_prefix is multiline commented out) as an output.
		# But our input zip file unzips in the working directory, putting an *input* RData file into workdir.
		# Since it's not in an input folder, this input RData file could get picked up in an output glob("*.RData").
		# It is ornery to predict the output filename before runtime as WDL would require, but it's trivial to
		# just delete the input RData file during runtime.
		# It should be noted that if you do NOT do this and run on the provided test data, it will be okay on local
		# but will grab the wrong file on Terra.
		rm $DESTROY_THIS_FILE

		echo ""
		echo "Current contents of working directory are:"
		ls

		echo ""
		echo "Checking if output exists..."
		POSSIBLE_OUTPUT=(`find -name "*.RData"`) # does this need to be find . -name or is find -name okay??
		if [ ${#POSSIBLE_OUTPUT[@]} -gt 0 ]
		then
			echo "Output appears to exist."
		else 
			echo "There appears to be no output. You can verify by checking stdout of the Rscript to see if'exiting gracefully' appears."
			echo "Due to WDL output limitations we will not create a bogus RData file that should NEVER be used for actual analysis."
			echo "This file will be removed in subsequent tasks. As such we DO NOT recommend taking this task out of this WDL!"
			echo "Please see comments in the output section of this task for further documentation."
			touch BOGUS_FILE_DO_NOT_USE_EVER.RData
		fi

		echo ""
		echo ""
		echo "Finished. WDL will now attempt to evaluate its outputs."

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
		# For some reason glob("*.RData")[0] fails if the array is empty, even though File? is optional
		# But it is very difficult to work with Array[Array[File?]] in WDL.
		#
		# One might think that we can deal with Array[Array[File?]] using flatten to get a flat array.
		# Array[File] flat = flatten(select_all(assoc_aggregate.assoc_aggregate)) doesn’t work because it
		# considers that an illegal coercing of Array[File?] into Array[File].
		#
		# Array[File?] flat = flatten(select_all(assoc_aggregate.assoc_aggregate)) passes womtool but fails
		# when actually used in the next task with "Cannot interpolate Array[File?] into a command string
		# with attribute set [PlaceholderAttributeSet(None,None,None,Some(','))]" which is almost exactly the
		# same error we get when trying to put Array[Array[File?]] in the next task.
		#
		# This is why we cheated in the command section by creating bogus output if necessary -- we want 
		# this output to be File instead of Array[File?] so this scattered task's gathered output is 
		# Array[File] instead of Array[Array[File?]].

		File assoc_aggregate = glob("*.RData")[0]
		File config = glob("*.config")[0]
	}
}

# CWL does not officially support arrays of arrays/lists of lists, so SB engineers created a
# generalizable task called sbg_flatten_lists which is used in several of their CWLs. This task is
# designed to flatten inputs into a single list of files.
#
# The WDL works a bit differently -- the previous task does not output an array of arrays. But we 
# have our own issues involving optional files, so we are still including a task to process the
# previous task's output.
task wdl_echo_lists {
	input {
		Array[File] input_list

		# runtime attr
		Int addldisk = 1
		Int cpu = 2
		Int memory = 4
		Int preempt = 2
	}

	Int in_size = ceil(size(input_list, "GB"))
	Int finalDiskSize = 2*in_size + addldisk # overkill due to deletions but easiest formula to work with

	command <<<

		# Terra workaround to make input files deletable
		find . -type d -exec sudo chmod -R 777 {} +

		ASSO_FILES=(~{sep=" " input_list})
		for ASSO_FILE in ${ASSO_FILES[@]};
		do
			if [[ "${ASSO_FILE}" == *"BOGUS_FILE_DO_NOT_USE_EVER"* ]]
			then
				# Delete bogus output
				rm ${ASSO_FILE}
				echo "${ASSO_FILE} has been deleted"
			else
				# Copy good output, then delete the orignal. On Terra this is much less prone to
				# errors than simply leaving them in place.
				cp ${ASSO_FILE} .
				rm ${ASSO_FILE}
				echo "${ASSO_FILE} has been copied to workdir"
			fi
		done

		ls

	>>>

	runtime {
		disks: "local-disk " + finalDiskSize + " HDD"
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		preemptibles: 3
	}

	output {
		Array[File] output_list = glob("*.RData")
	}
}

task sbg_group_segments_1 {
	input {
		# if not scattered
		#Array[File] assoc_files
		# if scattered
		File assoc_file

		# runtime attr
		Int addldisk = 3
		Int cpu = 8
		Int memory = 8
		Int preempt = 2
	}

	# if not scattered
	#Int assoc_size = ceil(size(assoc_files, "GB"))
	# if scattered
	##Int assoc_size = ceil(size(assoc_file, "GB"))
	##Int finalDiskSize = 2*assoc_size + addldisk

	Int finalDiskSize = 42 # temporary override

	command <<<

		# copy over because output struggles to find the files otherwise

		# if not scattered
		# see above runtime section as womtool cannot detect comments properly
		# if scattered
		cp ~{assoc_file} .

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

		print("Grouping...") # line 116 of CWL
		
		# if not scattered
		# see above runtime block because womtool doesn't parse comments correctly
		# if scattered
		python_assoc_files = ["~{assoc_file}"]
		
		print("Debug: Input association files located at %s" % python_assoc_files)
		python_assoc_files_wkdir = []
		for file in python_assoc_files:
			# point to the workdir copies instead to help Terra
			python_assoc_files_wkdir.append(os.path.basename(file))
		
		print("Debug: We will instead work with the workdir duplicates at %s" % python_assoc_files_wkdir)
		assoc_files_dict = dict() 
		grouped_assoc_files = [] # line 53 of CWL
		output_chromosomes = [] # line 96 of CWL

		for i in range(0, len(python_assoc_files)):
			chr = find_chromosome(python_assoc_files[i])
			if chr in assoc_files_dict:
				assoc_files_dict[chr].append(python_assoc_files[i])
			else:
				assoc_files_dict[chr] = [python_assoc_files[i]]

		for key in assoc_files_dict.keys():
			grouped_assoc_files.append(assoc_files_dict[key]) # line 65 in CWL
			output_chromosomes.append(key) # line 108 in CWL

		f = open("output_filenames.txt", "a")
		for list in grouped_assoc_files:
			#f.write("%s\n" % list)
			for entry in list:
				f.write("%s\n" % entry)
		f.close()

		g = open("output_chromosomes.txt", "a")
		for chrom in output_chromosomes:
			g.write("%s" % chrom)
		g.close()

		CODE
	>>>
	#ASSO_FILES=(~{sep=" " assoc_files})
	#for ASSO_FILE in ${ASSO_FILES[@]};
	#do
	#	cp ${ASSO_FILE} .
	#done

	#python_assoc_files = ['~{sep="','" assoc_files}']
	
	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}

	output {
		# The CWL returns array(array(file)) and array(string) in order to dotproduct scatter in
		# the next task, but we cannot do that in WDL, so we will use a custom struct instead
		
		# if not scattered:
		Assoc_N_Chr group_out = {"grouped_assoc_files":read_lines("output_filenames.txt"),"chromosome":read_lines("output_chromosomes.txt")}
		# if scattered:
		#Assoc_N_Chr_Neo group_out = {"grouped_assoc_files":read_lines("output_filenames.txt"),"chromosome":read_string("output_chromosomes.txt")}
	}
}

# TO CHECK:
# * Right now, does Terra output of assoc_aggregate match that of SB? If NO, the problem is actually upstream
# --> It's complicated. It seems that it happens to have gotten it right so far, but the way we are globbing might
#     pick up the input .RData file instead. --> It turns out that is indeed what Terra was doing! Oops!
#
# PROBLEM: sbg_group_segments_1 has output that is tricky to put in WDL
# OPTION A: Scatter sbg_group_segments_1 and have output as custom Array(File) and String struct
# OPTION B: Scatter, or don't, sbg_group_segments_1 and use read_tsv() to get array(array(string)) which Walt has previously coerced
#           into array(file?) in the topmed variant caller
# OPTION C: Reuse the zip file hack on non-scattered sbg_group_segments_1


struct Assoc_N_Chr {
	Array[File] grouped_assoc_files
	Array[String] chromosome
}

struct Assoc_N_Chr_Neo {
	# Should be closer to what's actually in CWL but doesn't seem to work... are the inputs into the group task valid?
	Array[File] grouped_assoc_files
	String chromosome
}

struct Assoc_N_Chr_Single {
	# Debug attempt to deal with 
	# Cannot construct WomMapType(WomStringType,WomAnyType) with mixed types in map values: [["/call-sbg_group_segments_1/shard-1/inputs/-2084386719/1KG_phase3_subset_aggregate_chr2_seg2.RData"], WomString(2)]
	# but it didn't work, just here to indicate not to use it again
	File grouped_assoc_files
	String chromosome
}

task assoc_combine_r {
	input {
		#Pair[String, File] chr_n_assocfiles
		Assoc_N_Chr chr_n_assocfiles
		#Assoc_N_Chr_Neo chr_n_assocfiles
		String? assoc_type
		String? out_prefix
		File? conditional_variant_file
		
		# runtime attr
		Int addldisk = 3
		Int cpu = 8
		Int memory = 8
		Int preempt = 2
	}
	Int assoc_size = ceil(size(chr_n_assocfiles.grouped_assoc_files, "GB"))
	Int finalDiskSize = 2*assoc_size + addldisk

	command <<<

		# debugging step, delete later
		FILES=(~{sep=" " chr_n_assocfiles.grouped_assoc_files})
		for FILE in ${FILES[@]};
		do
			echo ${FILE}
		done

		python << CODE
		import os
		
		python_assoc_files = ['~{sep="','" chr_n_assocfiles.grouped_assoc_files}']
		
		f = open("assoc_combine.config", "a")
		
		f.write('assoc_type "~{assoc_type}"\n')
		data_prefix = os.path.basename(python_assoc_files[0]).split('_chr')[0]
		if "~{out_prefix}" != "":
			f.write('out_prefix "~{out_prefix}"\n')
		else:
			f.write('out_prefix "%s"\n' % data_prefix)

		if "~{conditional_variant_file}" != "":
			f.write('conditional_variant_file "~{conditional_variant_file}"\n')

		# CWL then has commented out portion for adding assoc files

		f.close()
		CODE

		# CWL's commands are scattered in different places so let's break it down here
		# Line numbers reference my fork's commit 196a734c2b40f9ab7183559f57d9824cffec20a1
		# Position   1: softlink RData ins (line 185 of CWL)
		# Position   5: Rscript call       (line 176 of CWL)
		# Position  10: chromosome flag    (line  97 of CWL -- chromosome has type Array[String] in CWL, but always has just 1 value
		# Position 100: config file        (line 172 of CWL)

		FILES=(~{sep=" " chr_n_assocfiles.grouped_assoc_files})
		for FILE in ${FILES[@]};
		do
			ln -s ${FILE} .
		done

		# chromosome has type Array[String] but only ever has one value
		CHRS=(~{sep=" " chr_n_assocfiles.chromosome})
		for CHR in ${CHRS[@]};
		do
			THIS_CHR=${CHR}
		done

		Rscript /usr/local/analysis_pipeline/R/assoc_combine.R --chromosome $THIS_CHR assoc_combine.config

	>>>

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}

	output {
		File assoc_combined = glob("*.RData")[0] # CWL considers this optional
		File config_file = glob("*.config")[0] # CWL considers this an array but there is always only one
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

		# runtime attr
		Int addldisk = 3
		Int cpu = 8
		Int memory = 8
		Int preempt = 2
	}
	Int assoc_size = ceil(size(assoc_files, "GB"))
	Int finalDiskSize = assoc_size + addldisk


	command <<<
		touch foo.txt

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

		f = open("assoc_file.config", "a")

		# CWL has  argument.push('out_prefix "assoc_single"'); but that doesn't seem valid

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
			# CWL has var data_prefix = path[0].split('/').pop(); but I think that doesn't fit Terra file system, investigate
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
		f.write('chromosomes "%s"' % chrs)

		# CWL might have another boolean/defined bug at line 107, investigate

		if "~{thin_npoints}" != "":
			f.write('thin_npoints ~{thin_npoints}\n')
		if "~{thin_nbins}" != "": # does not match apparent CWL bug
			f.write('plot_mac_threshold ~{plot_mac_threshold}\n')
		if "~{known_hits_file}" != "":
			f.write('known_hits_file "~{known_hits_file}"\n')
		if "~{plot_mac_threshold}" != "":
			f.write('plot_mac_threshold ~{plot_mac_threshold}\n')
		if "~{truncate_pval_threshold}" != "":
			f.write('truncate_pval_threshold ~{truncate_pval_threshold}\n')
		# plot qq, plot include file, signif type, signif fixed, qq mac bins, lambda, outfile lambadas, plot max, and maf threshold not used
		f.close()
		CODE

		# considered prefix 1 in the CWL
		FILES=(~{sep=" " assoc_files})
		for FILE in ${FILES[@]};
		do
			ln -s ${FILE} .
		done

		Rscript /usr/local/analysis_pipeline/R/assoc_plots.R assoc_file.config

	>>>

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}

	output {
		File assoc_combined = "foo.txt"
		Array[File] assoc_plots = glob("*.png")
		File config_file = "assoc_file.config" # array in CWL
		Array[File?] lambdas = glob("*.txt") # non-array in CWL
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

	# In order to force this to run first, all other tasks that use these psuedoenums
	# will take them in via outputs of this task
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
 
 #gds, aggregate, segments, and variant include are represented as a zip file here
 #CWL has linkMerge: merge_flattened for all inputs from other tasks, I thiiiiink we're okay here?
	scatter(gdsegregatevar in sbg_prepare_segments_1.dotproduct) {
		call assoc_aggregate {
			input:
				zipped = gdsegregatevar,
				null_model_file = null_model_file,
				phenotype_file = phenotype_file,
				out_prefix = out_prefix,
				rho = rho,
				segment_file = define_segments_r.define_segments_output, # NOT THE SAME AS SEGMENT IN ZIP
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

	call wdl_echo_lists {
		input:
			input_list = assoc_aggregate.assoc_aggregate
	}

	# CWL has this non-scattered and returns arrays of array(file) paired with arrays of chromosomes.
	# I cannot get that working properly in WDL even with maps and custom structs, so I've decided
	# to take the easy route and just scatter this task. In theory, a non-scattered array(array(file))
	# plus array(string) should equal a scattered array(file) plus string once gathered.
	scatter(assoc_file in wdl_echo_lists.output_list) {
		call sbg_group_segments_1 {
			input:
				assoc_file = assoc_file # if scattered
				#assoc_files = wdl_echo_lists.output_list # if not scattered
		}
	}

	scatter(file_set in sbg_group_segments_1.group_out) {
		call assoc_combine_r {
			input:
				chr_n_assocfiles = file_set,
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

	meta {
		author: "Ash O'Farrell"
		email: "aofarrel@ucsc.edu"
	}
}
