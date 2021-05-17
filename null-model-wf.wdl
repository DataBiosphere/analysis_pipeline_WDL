version 1.0

# [1] null_model_r
task null_model_r {
	input {
		# these are in rough alphabetical order here
		# for sanity's sake, but the inline Python
		# follows the original order of the CWL

		# required files
		String outcome
		File phenotype_file

		# optional stuff
		File? conditional_variant_file
		Array[String]? covars
		String? family
		Array[File]? gds_files
		String? group_var
		Boolean? inverse_normal
		Int? n_pcs
		Boolean? norm_bygroup
		String? output_prefix
		File? pca_file
		File? relatedness_matrix_file
		String? rescale_variance
		Boolean? resid_covars
		File? sample_include_file
		
		# runtime attributes
		Int addldisk = 1
		Int cpu = 2
		Int memory = 4
		Int preempt = 3
	}

	# Estimate disk size required
	Int phenotype_size = ceil(size(phenotype_file, "GB"))
	# other files, etc
	Int finalDiskSize = phenotype_size + addldisk

	# Workaround
	# Strictly speaking this is only needed for Array variables
	# But we'll do it for most of 'em for consistency's sake
	Boolean isdefined_conditvar = defined(conditional_variant_file)
	Boolean isdefined_covars = defined(covars)
	Boolean isdefined_gds = defined(gds_files)
	Boolean isdefined_matrix = defined(relatedness_matrix_file)
	Boolean isdefined_pca = defined(pca_file)
	Boolean isdefined_sample = defined(sample_include_file)
	

	command <<<
		set -eux -o pipefail

		echo "Generating config file"
		python << CODE
		import os
		def split_n_space(py_splitstring):
		# Return [file name with chr name replaced by space, chr name]
		# Ex: test_data_chrX.gdsreturns ["test_data_chr .gds", "X"]
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

		f = open("null_model.config", "a")
		if "~{output_prefix}" != "":
			filename = "~{output_prefix}_null_model"
			f.write('out_prefix "' + filename + '"\n')
			phenotype_filename = "~{output_prefix}_phenotypes.RData"
			f.write('out_phenotype_file"' + phenotype_filename + '"\n')
		}
		else{
			f.write('out_prefix "null_model"')
			f.write('out_phenotype_file "phenotypes.RData"')
		}

		f.write('outcome ~{outcome}')
		f.write('phenotype_file ~{phenotype_file}')
		if "~{isdefined_gds}" == "true":  # double check this isn't supposed to be capital-T True
			py_gds_array = ['~{sep="','" gds_files}']
			gds = py_gds_array[0]
			py_splitup = split_n_space(gds)[0]
			chr = split_n_space(gds)[1]
			f.write('gds_file "' + py_splitup + chr + '"')
		if "~{isdefined_pca}" == "true":
			f.write('pca_file "~{pca_file}"\n')
		if "~{isdefined_thematrix}" == "true":
			f.write('related_matrix_file "~{related_matrix_file}"\n')
		if "~{family}" != "":
			f.write('family ~{family}\n')
		if "~{isdefined_conditvar}" == "true":
			f.write('conditional_variant_file "~{conditional_variant_file}"\n')
		if "~{isdefined_covars}" == "true":
			f.write('covars "~{sep="," covars}"\n')
			 
		############
		  if(inputs.covars){
			  temp = []
			  for(var i=0; i<inputs.covars.length; i++){
				  temp.push(inputs.covars[i])
			  }
			  arguments.push('covars "' + temp.join(' ') + '"')
		  }
		  if(inputs.group_var){
			  arguments.push('group_var "' + inputs.group_var + '"')
		  }
		  if(inputs.inverse_normal){
			  arguments.push('inverse_normal ' + inputs.inverse_normal)
		  }
		  if(inputs.n_pcs){
			  if(inputs.n_pcs > 0)
				  arguments.push('n_pcs ' + inputs.n_pcs)
		  }
		  if(inputs.rescale_variance){
			  arguments.push('rescale_variance "' + inputs.rescale_variance + '"')
		  }
		  if(inputs.resid_covars){
			  arguments.push('resid_covars ' + inputs.resid_covars)
		  }
		  if(inputs.sample_include_file){
			  arguments.push('sample_include_file "' + inputs.sample_include_file.path + '"')
		  }
		  if(inputs.norm_bygroup){
			  arguments.push('norm_bygroup ' + inputs.norm_bygroup)
		  }
		f.close()

		'''
		The CWL then contains this. I... do not know what it does.

		class: InlineJavascriptRequirement
		  expressionLib:
		  - |2-

			var setMetadata = function(file, metadata) {
				if (!('metadata' in file))
					file['metadata'] = metadata;
				else {
					for (var key in metadata) {
						file['metadata'][key] = metadata[key];
					}
				}
				return file
			};

			var inheritMetadata = function(o1, o2) {
				var commonMetadata = {};
				if (!Array.isArray(o2)) {
					o2 = [o2]
				}
				for (var i = 0; i < o2.length; i++) {
					var example = o2[i]['metadata'];
					for (var key in example) {
						if (i == 0)
							commonMetadata[key] = example[key];
						else {
							if (!(commonMetadata[key] == example[key])) {
								delete commonMetadata[key]
							}
						}
					}
				}
				if (!Array.isArray(o1)) {
					o1 = setMetadata(o1, commonMetadata)
				} else {
					for (var i = 0; i < o1.length; i++) {
						o1[i] = setMetadata(o1[i], commonMetadata)
					}
				}
				return o1;
			};
		'''





		exit()
		CODE


		

		echo "Calling R script null_model.R"
		Rscript /usr/local/analysis_pipeline/R/null_model.R null_model.config
	>>>
	
	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master:2.10.0"
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		File null_model_output = output_file_name
		File config_file = "vcf2gds.config"
	}
}

# [2] null_model_report
task null_model_report {
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
		echo "Copying inputs into the workdir"
		BASH_FILES=(~{sep=" " gdss})
		for BASH_FILE in ${BASH_FILES[@]};
		do
			cp ${BASH_FILE} .
		done

		echo "Generating config file"
		python << CODE
		import os

		
		CODE
		
		echo "Calling null_model_report.R"
		Rscript /usr/local/analysis_pipeline/R/null_model_report.R null_model_report.config
	>>>
	# Estimate disk size required
	Int gdss_size = ceil(size(gdss, "GB"))
	Int finalDiskSize = 2*gdss_size + addldisk

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master:2.10.0"
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		Array[File] null_model_report_output = glob("*.html")
	}
}

workflow nullmodel {
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

	meta {
		author: "Ash O'Farrell"
		email: "aofarrel@ucsc.edu"
	}
}
