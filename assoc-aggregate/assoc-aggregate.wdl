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
		preemptibles: 2
	}

	output {
		String? valid_genome_build = genome_build
		String? valid_aggregate_type = aggregate_type
		String? valid_test = test
	}

}

task wdl_terra_permissions_workaround {
	# Terra breaks upon os.rename() and seemingly other attempts to rename or move the file. chmod 777 doesn't help.
	# I can copy it and rename the duplicate, but look at how we get the output... we glob on (*.gds)[0]. 
	# That might match the original or the renamed duplicate.
	# To get this working on Terra, we might be forced to basically remake the entire task as a single regex command,
	# and then have that in a sub() as an input private variable.
	# That's the only way to grab a specific filename in the output section; WDL cannot read variables from the task
	# section, and Terra doesn't allow basing outputs upon other outputs (the Spec will lead you astray on this).
	# And even then, doing that does not work on DRS URIs due to a known bug that hasn't been fixed yet.
	# So what can we do?
	# We break their file extension in an entirely different task.

	input {
		File gds_to_mess_with
	}
	Int gds_size= ceil(size(gds_to_mess_with, "GB"))
	Int finalDiskSize = gds_size*2 + 3

	command {
		cp ~{gds_to_mess_with} .
		python << CODE
		import os
		nameroot = os.path.basename("~{gds_to_mess_with}").rsplit(".", 1)[0]
		oldname = nameroot + ".gds"
		newname = nameroot + ".ofarrell"
		os.rename(oldname, newname)
		CODE
	}
	runtime {
		cpu: 2
		disks: "local-disk " + finalDiskSize + " HDD"
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		memory: "4 GB"
		preemptibles: "3"
	}
	output {
		File gds_with_bad_extension = glob("*.ofarrell")[0]
	}

}

task sbg_gds_renamer {
	# This tool renames GDS file in GENESIS pipelines if they contain suffixes after chromosome (chr##) in the filename.
 	# For example: If GDS file has name data_chr1_subset.gds the tool will rename GDS file to data_chr1.gds.

	input {
		File in_variant
	}
	Int gds_size= ceil(size(in_variant, "GB"))
	Int finalDiskSize = gds_size*2 + 3
	
	command <<<

		# workaround attempt 1
		set -eux -o pipefail
		sudo chmod 777 ~{in_variant} # doesn't work on Terra

		# debugging
		whoami | tee -a "debug-terra.txt"
		ls -lha ~{in_variant} | tee -a "debug-terra.txt"

		# workaround attempt 2
		cp ~{in_variant} . 

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

		print("Debug: Renaming file")
		#os.rename("~{in_variant}", newname)
		oldname = nameroot + ".ofarrell"
		os.rename(oldname, newname)
		CODE

	>>>

	runtime {
		cpu: 2
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: "4 GB"
		preemptibles: 2
	}
	output {
		File renamed_variants = glob("*.gds")[0]
	}
}

task define_segments_r {
	input {
		Int? segment_length
		Int? n_segments
		String? genome_build

		# runtime attributes, which you shouldn't need
		Int addldisk = 1
		Int cpu = 2
		Int memory = 4
		Int preempt = 3
	}
	Int finalDiskSize = addldisk
	
	command <<<
		python << CODE
		import os
		f = open("define_segments.config", "a")
		f.write('out_file "segments.txt"\n')
		if "~{genome_build}" != "":
			f.write('genome_build "~{genome_build}"\n')
		f.close()
		CODE

		# this could be improved
		# this also should be tested a bit more
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
		String? out_file
		String? group_id

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
		if "chr" in "~{basename_vargroup}": #if (inputs.variant_group_file.basename.includes('chr'))
			chr = find_chromosome("~{variant_group_file}") #var chr = find_chromosome(inputs.variant_group_file.path);

			# CWL has:
			# chromosomes_basename = inputs.variant_group_file.path.slice(0,-6).replace(/\/.+\//g,"");
			# This seems that it would turn inputs/304343024/mygroupfile.txt into inputs/304343024/mygroupfi (slice) then into inputsmygroupfi (replace)
			# Surely that cannot be it...? Is this specific to SB's input scheme?
			# All we know is it's probably not equivalent to basename_vargroup because that can just be done with basename, so what is this?
			# Even if we assume nameroot should end in chrW where W is 1-23|X|Y, this would only result in mygroupfilechr for double digit chromosomes

			# This section doesn't seem to do anything? Why iterate through this at all? The next part isn't part of the for loop.
			#for i in range(0, len(chromosomes_basename)): #for(i = chromosomes_basename.length - 1; i > 0; i--)
			#	if chromosomes_basename[i] not in ["X", "Y"]: #	if(chromosomes_basename[i] != 'X' && chromosomes_basename[i] != "Y" && isNaN(chromosomes_basename[i]))
			#		break #	break;
			
			# Then chromosomes_basename gets overwritten anyway?
			chromosomes_basename_1 = "~{basename_vargroup}".split('chr'+chr)[0]
			chromosomes_basename_2 = "chr "
			chromosomes_basename_3 = "~{basename_vargroup}".split('chr'+chr)[1]
			chromosomes_basename = chromosomes_basename_1 + chromosomes_basename_2 + chromosomes_basename_3
			
			f.write('variant_group_file "%s"\n' % chromosomes_basename)
		
		else:
			f.write('variant_group_file "~{basename_vargroup}"\n')

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

		# line 195 of CWL
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
				# Therefore we use the same workaround as before and break
				# this file's extension too.
				nameroot = os.path.basename(output_variant_files[i]).rsplit(".", 1)[0]
				newname = nameroot + ".ofarrell"
				os.rename(output_variant_files[i], newname)
				this_zip.write("%s" % newname)
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
	Int zipped_size = ceil(size(zipped, "GB"))*5 # not sure how much zip compresses them if at all
	Int segment_size = ceil(size(segment_file, "GB"))
	Int null_size = ceil(size(null_model_file, "GB"))
	Int pheno_size = ceil(size(phenotype_file, "GB"))
	Int varweight_size = select_first([ceil(size(variant_weight_file, "GB")), 0])
	Int finalDiskSize = zipped_size + segment_size + null_size + pheno_size + varweight_size + addldisk

	command <<<
		cp ~{zipped} . # copy because I don't want to deal with finding what directory files unzip into
		unzip ./*.zip
		ls
		
		python << CODE
		import os

		def wdl_find_file(extension):
			ls = os.listdir(os.getcwd())
			print("ls is %s" % ls)
			for i in range(0, len(ls)):
				if ls[i].rsplit(".", 1)[0] == extension:
					return ls[i].rsplit(".", 1)[0]
				i += 1
			return None
			
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

		gds = wdl_find_file("gds")
		print(gds)
		agg = wdl_find_file("RData")
		print(agg)
		seg = int(wdl_find_file("integer").rsplit(".", 1)[0])
		var = wdl_find_file("ofarrell")
		if type(var) != None:
			newname = [var.rsplit(".", 1)[0], ".RData"].join
			os.rename(var, newname)

		chr = find_chromosome(gds)
		f = open("assoc_aggregate.config", "a")
		if "~{out_prefix}" != "":
			f.write("out_prefix '~{out_prefix}_chr%s'\n" % chr)
		else:
			pass # todo

		f.write("gds_file '%s'\n" % gds_file)
		
		pass
		CODE

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

## comes after define segs and gds renamer
#task sbg_group_segments_1 {
#	input {
#		Array[File] assoc_files
#	}
#
#	command {
#		touch foo.txt
#		touch bar.txt
#		touch bizz.txt
#	}
#
#	output {
#		Array[File] grouped_assoc_files = ["foo.txt", "bar.txt"]
#		Array[String] chromosome = ["foo", "bar"]
#		File gds_output = "bizz.txt"
#	}
#}
#
## This task is probably not strictly necessary in WDL, as WDL can handle lists of lists better than CWL.
## Nevertheless, it is in this WDL to ensure compatiability with the CWL version.
#task sbg_flatten_lists {
#	input {
#		Array[File] input_list
#	}
#
#	command {
#		python << CODE
#		# Untested and probably not excellent!
#		flat = []
#		for minilist in ['~{sep="','" input_list}']:
#			for component in minilist:
#				flat.append(component)
#		CODE
#
#	}
#
#	output {
#		Array[File] output_list = input_list
#	}
#}
#
#
#task assoc_combine_r {
#	input {
#		Pair[String, File] chr_n_assocfiles
#		String? assoc_type
#		String? out_prefix
#		File? conditional_variant_file
#	}
#
#	command <<<
#		touch foo.txt
#		touch bar.txt
#	>>>
#
#	output {
#		File assoc_combined = glob("*.RData")[0]
#	}
#}
#
#task assoc_plots_r {
#	input {
#		Array[File] assoc_files
#		String assoc_type
#		String? plots_prefix
#		Boolean? disable_thin
#		File? known_hits_file
#		Int? thin_npoints
#		Int? thin_nbins
#		Int? plot_mac_threshold
#		Float? truncate_pval_threshold
#	}
#
#	command {
#		pass
#	}
#}


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

	# Workaround for Terra permissions issue -- this should be deleted if we find a better option
	scatter(gds_file in input_gds_files) {
		call wdl_terra_permissions_workaround {
			input:
				gds_to_mess_with = gds_file
		}
	}

	#scatter(gds_file in input_gds_files) {
	scatter(gds_file in wdl_terra_permissions_workaround.gds_with_bad_extension) {
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

# gds, aggregate, segments, and variant include are represented as a zip file here
# CWL has linkMerge: merge_flattened for all inputs from other tasks, I thiiiiink we're okay here?
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
