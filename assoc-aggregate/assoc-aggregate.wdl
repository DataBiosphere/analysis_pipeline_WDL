version 1.0

task make_files {
	input {
		File? no

		# runtime attr
		Int addldisk = 3
		Int cpu = 8
		Int memory = 8
		Int preempt = 2
	}

	command <<<
		touch chr1seg1.txt
		touch chr1seg2.txt
		touch chr2seg3.txt
		touch chr2seg4.txt
		touch chr3seg5.txt
		touch chr3seg6.txt
		touch chr19seg7.txt
		touch chr19seg8.txt
		touch chr20seg9.txt
		touch chr20seg10.txt
	>>>

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + addldisk + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}

	output {
		Array[File] the_files = glob("*.txt")
	}
}

task group_files {
	input {
		Array[String] file_locations
		Boolean debug = true

		# runtime attr
		Int addldisk = 3
		Int cpu = 8
		Int memory = 8
		Int preempt = 2
	}

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

		print("Grouping...") # line 116 of CWL
		
		python_assoc_files = ['~{sep="','" file_locations}']
		if "~{debug}" == "true":
			print("Debug: Input association files located at %s" % python_assoc_files)
		python_assoc_files_wkdir = []
		for file in python_assoc_files:
			# point to the workdir copies instead to help Terra
			python_assoc_files_wkdir.append(os.path.basename(file))
		if "~{debug}" == "true":
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

		if "~{debug}" == "true":
			print("Debug: Iterating thru keys...")
		for key in assoc_files_dict.keys():
			grouped_assoc_files.append(assoc_files_dict[key]) # line 65 in CWL
			output_chromosomes.append(key) # line 108 in CWL
			
		# debugging
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
			#if i != len(list):
			# do not write on last iteration; removing trailing newlines is kind of awkward
			f.write("\n")
		f.close()

		g = open("output_chromosomes.txt", "a")
		for chrom in output_chromosomes:
			g.write("%s\n" % chrom)
		g.close()

		if "~{debug}" == "true":
			print("Debug: Finished. Executor will now attempt to evaulate outputs.")
		CODE
	>>>
	
	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + addldisk + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}

	output {
		File d_filenames = "output_filenames.txt"
		File d_chrs = "output_chromosomes.txt"
		Array[Array[String]] grouped_files_as_strings = read_tsv("output_filenames.txt")
	}
}

task combine_files {
	input {
		String chr = 1
		Array[File] assoc_files
		String? assoc_type = "aggregate"
		String? out_prefix = "combined" # NOT the default in cwl
		File? conditional_variant_file

		Boolean debug = true
		
		# runtime attr
		Int addldisk = 3
		Int cpu = 8
		Int memory = 8
		Int preempt = 2
	}
	Int finalDiskSize = 100 # override, replace me!

	command <<<

		python << CODE
		import os

		########### ripped from the grouping task, should be whittled down #############
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

		print("Grouping...") # line 116 of CWL
		
		python_assoc_files = ['~{sep="','" assoc_files}']
		if "~{debug}" == "true":
			print("Debug: Input association files located at %s" % python_assoc_files)
		python_assoc_files_wkdir = []
		for file in python_assoc_files:
			# point to the workdir copies instead to help Terra
			python_assoc_files_wkdir.append(os.path.basename(file))
		if "~{debug}" == "true":
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

		if "~{debug}" == "true":
			print("Debug: Iterating thru keys...")
		for key in assoc_files_dict.keys():
			grouped_assoc_files.append(assoc_files_dict[key]) # line 65 in CWL
			output_chromosomes.append(key) # line 108 in CWL

		g = open("output_chromosomes.txt", "a")
		for chrom in output_chromosomes:
			g.write("%s" % chrom) # no newline for combine task's version
		g.close()
		########### end stuff taken from grouping task #############
		print(output_chromosomes) # in this task, this should only have one value
		
		python_assoc_files = ['~{sep="','" assoc_files}']
		
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

		#CHRS=(~{sep=" " chr})
		#for CHR in ${CHRS[@]};
		#do
		#	THIS_CHR=${CHR}
		#done

		THIS_CHR=`cat output_chromosomes.txt`

		FILES=(~{sep=" " assoc_files})
		for FILE in ${FILES[@]};
		do
			# only link files related to this chromosome; the inability to find inputs that are
			# not softlinked or copied to the workdir actually helps us out here!
			if [[ "$FILE" =~ "chr$THIS_CHR" ]];
			then
				echo "$FILE"
				ln -s ${FILE} .
			fi
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
		File config_file = glob("*.config")[0]   # CWL considers this an array but there is always only one
	}
}

workflow test_pipeline_of_testing {
	input {
		Int? nada
	}

	call make_files
	call group_files {
		input:
			file_locations = make_files.the_files
	}
	scatter(group_of_files in group_files.grouped_files_as_strings) {
		call combine_files {
			input:
				assoc_files = group_of_files
		}
	}

}