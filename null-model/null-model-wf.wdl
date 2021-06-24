version 1.0

# Most pipelines so far use a .config file to point requiste inputs to the Rscript.
# null_model_r works like this, generating a .config file which is used by null_model.R
# But null_model_report bucks this trend completely. It essentially needs two configs.
# First of all it generates a .config file which only contains the distribution family,
# the outprefix, and n_catagories_boxplot. You would expect it to contain the other
# stuff, such as phenotype_file, in that same configuration file, but it does not.
# Instead, it uses the previous tasks' params file for that stuff. This params file was
# generated in the first task and acts like a copy of the first task's config file. 
# It is this param file from the first task that is used to generated an Rmd (R markdown) file
# in the second task.

# null_model_fast_scoreSE.config is in original repo's testdata, but is not for this workflow

# [1] null_model_r
task null_model_r {
	input {
		# these are in rough alphabetical order here
		# for sanity's sake, but the inline Python
		# follows the original order of the CWL

		# required 
		String outcome
		File phenotype_file
		String family  # required on SB but not in original pipeline

		# optional stuff
		File? conditional_variant_file
		Array[String]? covars
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
	
	command <<<
		set -eux -o pipefail

		# params files output must have basenames, not full paths,
		# otherwise the next task cannot read from this task's params file
		# this also requires copying some things to the workdir

		cp ~{phenotype_file} .

		if ~{isdefined_conditvar}; then
			cp ~{conditional_variant_file} .
		fi

		if ~{isdefined_gds}; then
			GDS_FILESS=(~{sep=" " gds_files})
			for GDS_FILE in ${GDS_FILESS[@]};
			do
				cp ${GDS_FILE} .
			done
		fi
		
		if ~{isdefined_matrix}; then
			cp ~{relatedness_matrix_file} .
		fi
		if ~{isdefined_pca}; then
			cp ~{pca_file} .
		fi
		if ~{isdefined_sample}; then
			cp ~{sample_include_file} .
		fi


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
			f.write('out_phenotype_file "' + phenotype_filename + '"\n')
		
		else:
			f.write('out_prefix "null_model"\n')
			f.write('out_phenotype_file "phenotypes.RData"\n')

		f.write('outcome ~{outcome}\n')
		f.write('phenotype_file "~{base_phenotype}"\n')
		
		if "~{isdefined_gds}" == "true":
			py_gds_array = ['~{sep="','" gds_files}']
			py_gds_split = py_gds_array[0].split("chr")
			py_processed_gds = split_n_space(py_gds_split)[0]
			f.write('gds_file "' + os.path.basename(py_processed_gds) + '"\n')
		
		if "~{isdefined_pca}" == "true":
			base_pca = os.path.basename("~{pca_file}")
			f.write('pca_file "%s"\n' % base_pca)
		
		if "~{isdefined_matrix}" == "true":
			base_matrix = os.path.basename("~{relatedness_matrix_file}")
			f.write('relatedness_matrix_file "%s"\n' % base_matrix)
		
		if "~{family}" != "":
			f.write('family ~{family}\n')
		
		if "~{isdefined_conditvar}" == "true":
			base_conditvar = os.path.basename("~{conditional_variant_file}")
			f.write('conditional_variant_file "%s"\n' % base_conditvar)
		
		if "~{isdefined_covars}" == "true":
			f.write('covars ""~{sep=" " covars}""\n')
		
		if "~{isdefined_group}" == "true":
			f.write('group_var "~{group_var}"\n')
		
		if "~{isdefined_inverse}" == "true":
			f.write('inverse_normal ~{inverse_normal}\n')
		
		if "~{isdefined_npcs}" == "true":
			if int("~{n_pcs}") > 0:  # must be done this way or else syntax err when n_pcs not defined
				f.write('n_pcs ~{n_pcs}\n')
	
		if "~{rescale_variance}" != "":
			f.write('rescale_variance "~{rescale_variance}"\n')
		
		if "~{isdefined_resid}" == "true":
			f.write('reside_covars ~{resid_covars}\n')
		
		if "~{isdefined_sample}" == "true":
			base_sample = os.path.basename("~{sample_include_file}")
			f.write('sample_include_file "%s"\n' % base_sample)
		
		if "~{isdefined_norm}" == "true":
			f.write('norm_bygroup ~{norm_bygroup}\n')

		f.close()
			
		############
		'''
		CWL now has output inherit inputs metadata. But it is not clear to me
		what is being transferred. Is metadata a field in an RData file?

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
		############
		exit()
		CODE
		
		echo "Calling R script null_model.R"
		Rscript /usr/local/analysis_pipeline/R/null_model.R null_model.config
	>>>

	# Estimate disk size required -- recall most inputs are duplicated
	Int phenotype_size = 2*ceil(size(phenotype_file, "GB"))
	# todo: other files, etc
	Int finalDiskSize = phenotype_size + addldisk

	# defined workaround
	#
	# Strictly speaking this is only needed for Array variables
	# But we'll do it for most of 'em for consistency's sake
	Boolean isdefined_conditvar = defined(conditional_variant_file)
	Boolean isdefined_covars = defined(covars)
	Boolean isdefined_gds = defined(gds_files)
	Boolean isdefined_group = defined(group_var)
	Boolean isdefined_inverse = defined(inverse_normal)
	Boolean isdefined_matrix = defined(relatedness_matrix_file)
	Boolean isdefined_npcs = defined(n_pcs)
	Boolean isdefined_norm = defined(norm_bygroup)
	Boolean isdefined_pca = defined(pca_file)
	Boolean isdefined_resid = defined(resid_covars)
	Boolean isdefined_sample = defined(sample_include_file)

	# basename workaround
	String base_phenotype = basename(phenotype_file)
	
	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master:2.10.0"
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		# cwl.output.json on SB has duplicated outputs
		# configs:
		# * null_model.config
		# * ! null_model.config.null_model.params
		# null_model_files:
		# * ! test_null_model_invnorm.RData
		# * test_null_model_invnorm_reportonly.RData
		# * test_null_model_reportonly.RData
		# null_model_output:
		# * ! test_null_model_invnorm.RData
		# null_model_params:
		# * ! null_model.config.null_model.params
		# null_model_phenotypes:
		# * test_phenotypes.RData

		File config_file = "null_model.config"  # CWL globs this with the parameters file, ie, params shows up twice as an ouput
		File null_model_phenotypes = glob("*phenotypes.RData")[0]  # should inherit metadata
		Array[File] null_model_files = glob("${output_prefix}*null_model*RData")
		File null_model_params = glob("*.params")[0]
		# the CWL also has null_model_output but this is already in null_model_files and not repeated here
	}
}


# [2] null_model_report
task null_model_report {
	input {
		# these are in rough alphabetical order here
		# for sanity's sake, but the inline Python
		# follows the original order of the CWL

		# required
		String family
		#String outcome  # not consistent in CWL? check!
		File phenotype_file

		# passed in from previous
		File null_model_params
		Array[File]? null_model_files  # CWL treats as optional


		# optional
		File? conditional_variant_file
		Array[String]? covars
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
		
		# report-specific variable
		Int n_categories_boxplot = 10

		# runtime attr
		Int addldisk = 1
		Int cpu = 2
		Int memory = 4
		Int preempt = 2
	}
	command <<<
		set -eux -o pipefail

		echo "Copying params file into the workdir"
		# workaround for rmd file being unable to param file
		cp ~{null_model_params} .
		cp ~{phenotype_file} .

		if ~{isdefined_null}; then
			NULL_MODEL_FILESS=(~{sep=" " null_model_files})
			for NULL_MODE_FILE in ${NULL_MODEL_FILESS[@]};
			do
				cp ${NULL_MODE_FILE} .
			done
		fi

		if ~{isdefined_conditvar}; then
			cp ~{conditional_variant_file} .
		fi
		if ~{isdefined_gds}; then
			GDS_FILESS=(~{sep=" " gds_files})
			for GDS_FILE in ${GDS_FILESS[@]};
			do
				cp ${GDS_FILE} .
			done
		fi
		if ~{isdefined_matrix}; then
			cp ~{relatedness_matrix_file} .
		fi
		if ~{isdefined_pca}; then
			cp ~{pca_file} .
		fi
		if ~{isdefined_sample}; then
			cp ~{sample_include_file} .
		fi

		echo "Generating config file"
		python << CODE
		import os
		f = open("null_model_report.config", "a")
		f.write("family ~{family}\n")
		if "~{isdefined_inverse}" == "true":
			f.write("inverse_normal ~{inverse_normal}\n")
		if "~{output_prefix}" != "":
			f.write('out_prefix "~{output_prefix}"\n')
		else:
			f.write('out_prefix "null_model"\n')
		f.write("n_categories_boxplot ~{n_categories_boxplot}\n")
		f.close

		CODE
		
		echo "Calling null_model_report.R"
		Rscript /usr/local/analysis_pipeline/R/null_model_report.R null_model_report.config
	>>>
	
	# Estimate disk size required -- recall most inputs are duplicated
	Int phenotype_size = 2*ceil(size(phenotype_file, "GB"))
	# todo: other files
	Int finalDiskSize = phenotype_size + addldisk

	# Workaround
	# Strictly speaking this is only needed for Array variables
	# But we'll do it for most of 'em for consistency's sake
	Boolean isdefined_conditvar = defined(conditional_variant_file)
	Boolean isdefined_covars = defined(covars)
	Boolean isdefined_gds = defined(gds_files)
	Boolean isdefined_inverse = defined(inverse_normal)
	Boolean isdefined_matrix = defined(relatedness_matrix_file)
	Boolean isdefined_norm = defined(norm_bygroup)
	Boolean isdefined_null = defined(null_model_files)
	Boolean isdefined_pca = defined(pca_file)
	Boolean isdefined_resid = defined(resid_covars)
	Boolean isdefined_sample = defined(sample_include_file)
	

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master:2.10.0"
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		File null_model_report_config = "null_model_report.config"  # glob in CWL?
		Array[File] html_reports = glob("*.html")
		Array[File] rmd_files = glob("*.rmd")
	}
}

workflow nullmodel {
	input {

		# These variables are used by all tasks
		# n_categories_boxplot and the runtime
		# attributes are the only task-level ones

		String family
		File phenotype_file
		String outcome

		File? conditional_variant_file
		Array[String]? covars
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
	}
	
	call null_model_r {
		input:
			family = family,
			phenotype_file = phenotype_file,
			outcome = outcome,
			conditional_variant_file = conditional_variant_file,
			covars = covars,
			gds_files = gds_files,
			group_var = group_var,
			inverse_normal = inverse_normal,
			n_pcs = n_pcs,
			norm_bygroup = norm_bygroup,
			output_prefix = output_prefix,
			pca_file = pca_file,
			relatedness_matrix_file = relatedness_matrix_file,
			rescale_variance = rescale_variance,
			resid_covars = resid_covars,
			sample_include_file = sample_include_file
	}

	call null_model_report {
		input:
			family = family,
			inverse_normal = inverse_normal,
			null_model_params = null_model_r.null_model_params,
			phenotype_file = phenotype_file,
			sample_include_file = sample_include_file,
			pca_file = pca_file,
			relatedness_matrix_file = relatedness_matrix_file,
			null_model_files = null_model_r.null_model_files,
			output_prefix = output_prefix,
			conditional_variant_file = conditional_variant_file,
			gds_files = gds_files

	}

	meta {
		author: "Ash O'Farrell"
		email: "aofarrel@ucsc.edu"
	}
}
