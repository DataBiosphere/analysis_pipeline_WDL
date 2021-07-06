version 1.0

# Caveat programmator: This runs the null model workflow TEN times.

import "https://raw.githubusercontent.com/DataBiosphere/analysis_pipeline_WDL/implement-null-model/null-model/null-model-wf.wdl" as nullmodel

task md5sum {
	input {
		Array[File] test
		Array[File] truth
		Float? tolerance = 0.00000001  # 1.0e-8
	}

	command <<<

	# the md5 stuff pulls from the files in /inputs/
	# the Rscript pulls from the copied files
	for j in ~{sep=' ' test}
	do
		
		# md5
		md5sum ${j} > sum.txt
		test_basename="$(basename -- ${j})"

		# R
		cp ${j} .
		mv ${test_basename} "testcopy_${test_basename}"

		for i in ~{sep=' ' truth}
		do
			truth_basename="$(basename -- ${i})"
			if [ "${test_basename}" == "${truth_basename}" ]; then
				# md5
				actual_truth="$i"

				# R
				cp ${i} .
				mv ${truth_basename} "truthcopy_${truth_basename}"
				
				break
			fi
		done

		# md5
		if ! echo "$(cut -f1 -d' ' sum.txt)" $actual_truth | md5sum --check
		then
			# R
			echo "Calling Rscript for approximate comparison"
			if Rscript /opt/are_outputs_kinda_equal.R testcopy_$test_basename truthcopy_$truth_basename ~{tolerance}
			then
				echo "Outputs are not identical, but are mostly equivalent."
				# do not exit, check the others
			else
				echo "Outputs vary beyond accepted tolerance (default:1.0e-8)."
				echo "This is considered a failure and should be reported on Github, unless"
				echo "this workflow is running the conditionalinv case."
				exit 1
			fi
		fi
	done

	>>>

	runtime {
		docker: "quay.io/aofarrel/rchecker:1.0.9"
		memory: "2 GB"
		preemptible: 2
	}

}

workflow checker_nullmodel {
	input {

		# run the one known configuration which is likely to error out
		# only useful to brave debuggers; we don't know what causes this
		Boolean run_conditionalinv = true 


		# commented out variables, included here for clarity,
		# change depending on specific run and are set manually elsewhere
		File? conditional_variant_file
		#Array[String]? covars
		#String family
		Array[File]? gds_files
		String? group_var
		Boolean? inverse_normal
		#Int? n_pcs  
		Boolean? norm_bygroup
		#String outcome
		String? output_prefix
		File? pca_file
		File phenotype_file
		File phenotype_file_alternative
		File? relatedness_matrix_file
		File? relatedness_matrix_file_alternative
		File? relatedness_matrix_file_grm
		String? rescale_variance
		Boolean? resid_covars
		File? sample_include_file_typical
		File? sample_include_file_unrelated

		# truth files
		File truth__Null_model_mixed_nullmodel
		File truth__Null_model_mixed_pheno
		File truth__Null_model_mixed_report
		File truth__basecase_nullmodel
		File truth__basecase_pheno
		File truth__basecase_report
		File truth__basecase_report_invnorm
		File truth__binary_nullmodel
		File truth__binary_pheno
		File truth__binary_report
		File truth__binary_nullmodel
		File truth__conditional_nullmodel
		File truth__conditional_pheno
		File truth__conditional_report
		File truth__conditional_nullmodel_invnorm  # conditionalinv
		File truth__conditional_report_invnorm  # conditionalinv
		File truth__grm_nullmodel
		File truth__grm_pheno
		File truth__grm_report
		File truth__grm_report_invnorm
		File truth__group_nullmodel
		File truth__group_pheno
		File truth__group_report
		File truth__group_report_invnorm
		File truth__norm_nullmodel
		File truth__norm_pheno
		File truth__norm_report
		File truth__norm_report_invnorm
		File truth__notransform_nullmodel
		File truth__notransform_pheno
		File truth__notransform_report
		File truth__unrelbin_nullmodel
		File truth__unrelbin_pheno
		File truth__unrelbin_report
		File truth__unrelated_nullmodel
		File truth__unrelated_pheno
		File truth__unrelated_report
		File truth__unrelated_report_invnorm
	}

#	##############################
#	#        SB WS Example       #
#	##############################
#	call nullmodel.null_model_r as Null_model_mixed__nullmodelr {
#		input:
#			#conditional_variant_file = 
#			covars = ["sex", "age", "study", "PC1", "PC2", "PC3", "PC4", "PC5"],
#			family = "gaussian",
#			#gds_files =
#			group_var = "study",
#			inverse_normal = false,
#			#n_pcs = 
#			#norm_bygroup
#			outcome = "height",
#			output_prefix = "Null_model_mixed",
#			#pca_file = 
#			phenotype_file = phenotype_file_alternative,
#			relatedness_matrix_file = relatedness_matrix_file_alternative,
#			#rescale_variance = 
#			#resid_covars = 
#			#sample_include_file = 
#	}
#	call nullmodel.null_model_report as Null_model_mixed__nullmodelreport {
#		input:
#			null_model_files = Null_model_mixed__nullmodelr.null_model_files,
#			null_model_params = Null_model_mixed__nullmodelr.null_model_params,
#			
#			#conditional_variant_file = 
#			covars = ["sex", "age", "study", "PC1", "PC2", "PC3", "PC4", "PC5"],
#			family = "gaussian",
#			#gds_files =
#			group_var = "study",
#			inverse_normal = false,
#			#n_pcs = 
#			#norm_bygroup
#			output_prefix = "Null_model_mixed",
#			#pca_file = 
#			phenotype_file = phenotype_file_alternative,
#			relatedness_matrix_file = relatedness_matrix_file_alternative,
#			#rescale_variance = 
#			#resid_covars = 
#			#sample_include_file = 
#	}
#	call md5sum as Null_model_mixed_md5 {
#		input:
#			test = [Null_model_mixed__nullmodelr.null_model_files[0], Null_model_mixed__nullmodelr.null_model_phenotypes, Null_model_mixed__nullmodelreport.rmd_files[0]],
#			truth = [truth__Null_model_mixed_nullmodel, truth__Null_model_mixed_pheno, truth__Null_model_mixed_report]
#	}
#	##############################
#	#          base case         #
#	##############################
#	call nullmodel.null_model_r as basecase__nullmodelr {
#		input:
#			#conditional_variant_file = 
#			covars = ["sex", "Population"],
#			family = "gaussian",
#			#gds_files =
#			#group_var = 
#			#inverse_normal = 
#			n_pcs = 4,
#			#norm_bygroup
#			outcome = "outcome",
#			output_prefix = "basecase",
#			pca_file = pca_file,
#			phenotype_file = phenotype_file,
#			relatedness_matrix_file = relatedness_matrix_file,
#			#rescale_variance = 
#			#resid_covars = 
#			sample_include_file = sample_include_file_typical
#	}
#	call nullmodel.null_model_report as basecase__nullmodelreport {
#		input:
#			null_model_files = basecase__nullmodelr.null_model_files,
#			null_model_params = basecase__nullmodelr.null_model_params,
#			
#			#conditional_variant_file = 
#			covars = ["sex", "Population"],
#			family = "gaussian",
#			#gds_files =
#			#group_var = 
#			#inverse_normal = 
#			n_pcs = 4,
#			#norm_bygroup
#			output_prefix = "basecase",
#			pca_file = pca_file,
#			phenotype_file = phenotype_file,
#			relatedness_matrix_file = relatedness_matrix_file,
#			#rescale_variance = 
#			#resid_covars = 
#			sample_include_file = sample_include_file_typical
#	}#
#	call md5sum as basecase_md5 {
#		input:
#			test = [basecase__nullmodelr.null_model_files[0], basecase__nullmodelr.null_model_phenotypes, basecase__nullmodelreport.rmd_files[0], basecase__nullmodelreport.rmd_files[1]],
#			truth = [truth__basecase_nullmodel, truth__basecase_pheno, truth__basecase_report, truth__basecase_report_invnorm]
#	}
#	##############################
#	#           binary           #
#	###############################
#	call nullmodel.null_model_r as binary__nullmodelr {
#		input:
#			#conditional_variant_file = 
#			covars = ["sex"],
#			family = "binomial",
#			#gds_files =
#			#group_var = 
#			#inverse_normal = 
#			n_pcs = 4,
#			#norm_bygroup = 
#			outcome = "status",
#			output_prefix = "binary",
#			pca_file = pca_file,
#			phenotype_file = phenotype_file,
#			relatedness_matrix_file = relatedness_matrix_file,
#			#rescale_variance = 
#			#resid_covars = 
#			#sample_include_file = 
#	}
#	call nullmodel.null_model_report as binary__nullmodelreport {
#		input:
#			null_model_files = binary__nullmodelr.null_model_files,
#			null_model_params = binary__nullmodelr.null_model_params,#
#			#conditional_variant_file = 
#			covars = ["sex"],
#			family = "binomial",
#			#gds_files =
#			#group_var = 
#			#inverse_normal = 
#			n_pcs = 4,
#			#norm_bygroup = 
#			output_prefix = "binary",
#			pca_file = pca_file,
#			phenotype_file = phenotype_file,
#			relatedness_matrix_file = relatedness_matrix_file,
#			#rescale_variance = 
#			#resid_covars = 
#			#sample_include_file = 
#	}
#	call md5sum as binary_md5 {
#		input:
#			test = [binary__nullmodelr.null_model_files[0], binary__nullmodelr.null_model_phenotypes, binary__nullmodelreport.rmd_files[0]],
#			truth = [truth__binary_nullmodel, truth__binary_pheno, truth__binary_report]
#	}
	##############################
	#   conditional one-step     #
	#                            #
	# This one does NOT perform  #
	# the inverse norm step, and #
	# should NOT error out.      #
	##############################
	call nullmodel.null_model_r as conditional__nullmodelr {
		input:
			conditional_variant_file = conditional_variant_file,
			covars = ["sex", "Population"],
			family = "gaussian",
			gds_files = gds_files,
			#group_var = 
			inverse_normal = false,
			n_pcs = 4,
			#norm_bygroup = 
			outcome = "outcome",
			output_prefix = "conditional",
			pca_file = pca_file,
			phenotype_file = phenotype_file,
			relatedness_matrix_file = relatedness_matrix_file,
			#rescale_variance = 
			#resid_covars = 
			sample_include_file = sample_include_file_typical
	}
	call nullmodel.null_model_report as conditional__nullmodelreport {
		input:
			null_model_files = conditional__nullmodelr.null_model_files,
			null_model_params = conditional__nullmodelr.null_model_params,
			
			conditional_variant_file = conditional_variant_file,
			covars = ["sex", "Population"],
			family = "gaussian",
			gds_files = gds_files,
			#group_var = 
			inverse_normal = false,
			n_pcs = 4,
			#norm_bygroup = 
			output_prefix = "conditional",
			pca_file = pca_file,
			phenotype_file = phenotype_file,
			relatedness_matrix_file = relatedness_matrix_file,
			#rescale_variance = 
			#resid_covars = 
			sample_include_file = sample_include_file_typical
	}
	call md5sum as conditional_md5 {
		input:
			test = [conditional__nullmodelr.null_model_files[0], conditional__nullmodelr.null_model_phenotypes, conditional__nullmodelreport.rmd_files[0]],
			truth = [truth__conditional_nullmodel, truth__conditional_pheno, truth__conditional_report]
	}

	if(run_conditionalinv) {
		##############################
		#   conditional inv norm     #
		#                            #
		# This one DOES perform the  #
		# the inverse norm step, and #
		# MIGHT error out.           #
		##############################
		call nullmodel.null_model_r as conditionalinv__nullmodelr {
			input:
				conditional_variant_file = conditional_variant_file,
				covars = ["sex", "Population"],
				family = "gaussian",
				gds_files = gds_files,
				#group_var = 
				inverse_normal = true,
				n_pcs = 4,
				#norm_bygroup = 
				outcome = "outcome",
				output_prefix = "conditionalinv",
				pca_file = pca_file,
				phenotype_file = phenotype_file,
				relatedness_matrix_file = relatedness_matrix_file,
				#rescale_variance = 
				#resid_covars = 
				sample_include_file = sample_include_file_typical
		}
		call nullmodel.null_model_report as conditionalinv__nullmodelreport {
			input:
				null_model_files = conditionalinv__nullmodelr.null_model_files,
				null_model_params = conditionalinv__nullmodelr.null_model_params,
				
				conditional_variant_file = conditional_variant_file,
				covars = ["sex", "Population"],
				family = "gaussian",
				gds_files = gds_files,
				#group_var = 
				inverse_normal = true,
				n_pcs = 4,
				#norm_bygroup = 
				output_prefix = "conditionalinv",
				pca_file = pca_file,
				phenotype_file = phenotype_file,
				relatedness_matrix_file = relatedness_matrix_file,
				#rescale_variance = 
				#resid_covars = 
				sample_include_file = sample_include_file_typical
		}
		call md5sum as conditionalinv_md5 {
			input:
				test = [conditionalinv__nullmodelr.null_model_files[0], conditionalinv__nullmodelr.null_model_phenotypes, conditionalinv__nullmodelreport.rmd_files[0], conditionalinv__nullmodelreport.rmd_files[1]],
				truth = [truth__conditional_nullmodel_invnorm, truth__conditional_pheno, truth__conditional_report, truth__conditional_report_invnorm]
		}
	}
#	##############################
#	#            grm             #
#	###############################
#	call nullmodel.null_model_r as grm__nullmodelr {
#		input:
#			#conditional_variant_file = 
#			covars = ["sex", "Population"],
#			family = "gaussian",
#			#gds_files = 
#			#group_var = 
#			#inverse_normal = 
#			n_pcs = 0,
#			#norm_bygroup = 
#			outcome = "outcome",
#			output_prefix = "grm",
#			#pca_file = 
#			phenotype_file = phenotype_file,
#			relatedness_matrix_file = relatedness_matrix_file_grm,
#			rescale_variance = "marginal",
#			#resid_covars = 
#			sample_include_file = sample_include_file_typical
#	}
#	call nullmodel.null_model_report as grm__nullmodelreport {
#		input:
#			null_model_files = grm__nullmodelr.null_model_files,
#			null_model_params = grm__nullmodelr.null_model_params,
#			
#			#conditional_variant_file = 
#			covars = ["sex", "Population"],
#			family = "gaussian",
#			#gds_files = 
#			#group_var = 
#			#inverse_normal = 
#			n_pcs = 0,
#			#norm_bygroup = 
#			output_prefix = "grm",
#			pca_file = pca_file,
#			phenotype_file = phenotype_file,
#			relatedness_matrix_file = relatedness_matrix_file_grm,
#			rescale_variance = "marginal",
#			#resid_covars = 
#			sample_include_file = sample_include_file_typical
#	}
#	call md5sum as grm_md5 {
#		input:
#			test = [grm__nullmodelr.null_model_files[0], grm__nullmodelr.null_model_phenotypes, grm__nullmodelreport.rmd_files[0], grm__nullmodelreport.rmd_files[1]],
#			truth = [truth__grm_nullmodel, truth__grm_pheno, truth__grm_report, truth__grm_report_invnorm]
#	}
#	##############################
#	#           group            #
#	##############################
#	call nullmodel.null_model_r as group__nullmodelr {
#		input:
#			#conditional_variant_file = 
#			covars = ["sex", "Population"],
#			family = "gaussian",
#			#gds_files =
#			group_var = "Population",
#			#inverse_normal = 
#			n_pcs = 4,
#			#norm_bygroup = 
#			outcome = "outcome",
#			output_prefix = "group",
#			pca_file = pca_file,
#			phenotype_file = phenotype_file,
#			relatedness_matrix_file = relatedness_matrix_file,
#			#rescale_variance = 
#			#resid_covars = 
#			#sample_include_file = 
#	}
#	call nullmodel.null_model_report as group__nullmodelreport {
#		input:
#			null_model_files = group__nullmodelr.null_model_files,
#			null_model_params = group__nullmodelr.null_model_params,
#			
#			#conditional_variant_file = 
#			covars = ["sex", "Population"],
#			family = "gaussian",
#			#gds_files =
#			group_var = "Population",
#			#inverse_normal = 
#			n_pcs = 4,
#			#norm_bygroup = 
#			output_prefix = "group",
#			pca_file = pca_file,
#			phenotype_file = phenotype_file,
#			relatedness_matrix_file = relatedness_matrix_file,
#			#rescale_variance = 
#			#resid_covars = 
#			#sample_include_file = 
#	}
#	call md5sum as group_md5 {
#		input:
#			test = [group__nullmodelr.null_model_files[0], group__nullmodelr.null_model_phenotypes, group__nullmodelreport.rmd_files[0], group__nullmodelreport.rmd_files[1]],
#			truth = [truth__group_nullmodel, truth__group_pheno, truth__group_report, truth__group_report_invnorm]
#	}
#	##############################
#	#        norm bygroup        #
#	##############################
#	call nullmodel.null_model_r as norm__nullmodelr {
#		input:
#			#conditional_variant_file = 
#			covars = ["sex", "Population"],
#			family = "gaussian",
#			#gds_files =
#			group_var = "Population",
#			#inverse_normal = 
#			n_pcs = 4,
#			norm_bygroup = true,
#			outcome = "outcome",
#			output_prefix = "norm",
#			pca_file = pca_file,
#			phenotype_file = phenotype_file,
#			relatedness_matrix_file = relatedness_matrix_file,
#			#rescale_variance = 
#			#resid_covars = 
#			#sample_include_file = 
#	}
#	call nullmodel.null_model_report as norm__nullmodelreport {
#		input:
#			null_model_files = norm__nullmodelr.null_model_files,
#			null_model_params = norm__nullmodelr.null_model_params,
#			
#			#conditional_variant_file = 
#			covars = ["sex", "Population"],
#			family = "gaussian",
#			#gds_files =
#			group_var = "Population",
#			#inverse_normal = 
#			n_pcs = 4,
#			norm_bygroup = true,
#			output_prefix = "norm",
#			pca_file = pca_file,
#			phenotype_file = phenotype_file,
#			relatedness_matrix_file = relatedness_matrix_file,
#			#rescale_variance = 
#			#resid_covars = 
#			#sample_include_file = 
#	}
#	call md5sum as norm_md5 {
#		input:
#			test = [norm__nullmodelr.null_model_files[0], norm__nullmodelr.null_model_phenotypes, norm__nullmodelreport.rmd_files[0], norm__nullmodelreport.rmd_files[1]],
#			truth = [truth__norm_nullmodel, truth__norm_pheno, truth__norm_report, truth__norm_report_invnorm]
#	}
#	##############################
#	#        no transform        #
#	##############################
#	call nullmodel.null_model_r as notransform__nullmodelr {
#		input:
#			#conditional_variant_file = 
#			covars = ["sex", "Population"],
#			family = "gaussian",
#			#gds_files =
#			group_var = "Population",
#			inverse_normal = false,
#			n_pcs = 4,
#			#norm_bygroup = 
#			outcome = "outcome",
#			output_prefix = "notransform",
#			pca_file = pca_file,
#			phenotype_file = phenotype_file,
#			relatedness_matrix_file = relatedness_matrix_file,
#			rescale_variance = "none",
#			#resid_covars = 
#			sample_include_file = sample_include_file_typical
#	}
#	call nullmodel.null_model_report as notransform__nullmodelreport {
#		input:
#			null_model_files = notransform__nullmodelr.null_model_files,
#			null_model_params = notransform__nullmodelr.null_model_params,
#			
#			#conditional_variant_file = 
#			covars = ["sex", "Population"],
#			family = "gaussian",
#			#gds_files =
#			group_var = "Population",
#			inverse_normal = false,
#			n_pcs = 4,
#			#norm_bygroup = 
#			output_prefix = "notransform",
#			pca_file = pca_file,
#			phenotype_file = phenotype_file,
#			relatedness_matrix_file = relatedness_matrix_file,
#			rescale_variance = "none",
#			#resid_covars = 
#			sample_include_file = sample_include_file_typical
#	}
#	call md5sum as notransform_md5 {
#		input:
#			# notransform only have one report
#			test = [notransform__nullmodelr.null_model_files[0], notransform__nullmodelr.null_model_phenotypes, notransform__nullmodelreport.rmd_files[0]],
#			truth = [truth__notransform_nullmodel, truth__notransform_pheno, truth__notransform_report]
#	}
#	##############################
#	#        unrel binary        #
#	##############################
#	call nullmodel.null_model_r as unrelbin__nullmodelr {
#		input:
#			#conditional_variant_file = 
#			covars = ["sex"],
#			family = "binomial",
#			#gds_files =
#			#group_var = 
#			#inverse_normal = 
#			n_pcs = 4,
#			#norm_bygroup = 
#			outcome = "status",
#			output_prefix = "unrelbin",
#			pca_file = pca_file,
#			phenotype_file = phenotype_file,
#			#relatedness_matrix_file = 
#			#rescale_variance = 
#			#resid_covars = 
#			sample_include_file = sample_include_file_unrelated
#	}
#	call nullmodel.null_model_report as unrelbin__nullmodelreport {
#		input:
#			null_model_files = unrelbin__nullmodelr.null_model_files,
#			null_model_params = unrelbin__nullmodelr.null_model_params,
#			
#			#conditional_variant_file = 
#			covars = ["sex"],
#			family = "binomial",
#			#gds_files =
#			#group_var = 
#			#inverse_normal = 
#			n_pcs = 4,
#			#norm_bygroup = 
#			output_prefix = "unrelbin",
#			pca_file = pca_file,
#			phenotype_file = phenotype_file,
#			#relatedness_matrix_file = 
#			#rescale_variance = 
#			#resid_covars = 
#			sample_include_file = sample_include_file_unrelated
#	}
#	call md5sum as unrelbin_md5 {
#		input:
#			# binary models only have one report
#			test = [unrelbin__nullmodelr.null_model_files[0], unrelbin__nullmodelr.null_model_phenotypes, unrelbin__nullmodelreport.rmd_files[0]],
#			truth = [truth__unrelbin_nullmodel, truth__unrelbin_pheno, truth__unrelbin_report]
#	}
#	##############################
#	#          unrelated         #
#	##############################
#	call nullmodel.null_model_r as unrelated__nullmodelr {
#		input:
#			#conditional_variant_file = 
#			covars = ["sex", "Population"],
#			family = "gaussian",
#			#gds_files =
#			#group_var = 
#			#inverse_normal = 
#			n_pcs = 4,
#			#norm_bygroup = 
#			outcome = "outcome",
#			output_prefix = "unrelated",
#			pca_file = pca_file,
#			phenotype_file = phenotype_file,
#			#relatedness_matrix_file = 
#			#rescale_variance = 
#			#resid_covars = 
#			sample_include_file = sample_include_file_unrelated
#	}
#	call nullmodel.null_model_report as unrelated__nullmodelreport {
#		input:
#			null_model_files = unrelated__nullmodelr.null_model_files,
#			null_model_params = unrelated__nullmodelr.null_model_params,
#			
#			#conditional_variant_file = 
#			covars = ["sex", "Population"],
#			family = "gaussian",
#			#gds_files =
#			#group_var = 
#			#inverse_normal = 
#			n_pcs = 4,
#			#norm_bygroup = 
#			output_prefix = "unrelated",
#			pca_file = pca_file,
#			phenotype_file = phenotype_file,
#			#relatedness_matrix_file = 
#			#rescale_variance = 
#			#resid_covars = 
#			sample_include_file = sample_include_file_unrelated
#	}
#	call md5sum as unrelated_md5 {
#		input:
#			test = [unrelated__nullmodelr.null_model_files[0], unrelated__nullmodelr.null_model_phenotypes, unrelated__nullmodelreport.rmd_files[0], unrelated__nullmodelreport.rmd_files[1]],
#			truth = [truth__unrelated_nullmodel, truth__unrelated_pheno, truth__unrelated_report, truth__unrelated_report_invnorm]
#	}


	meta {
		author: "Ash O'Farrell"
		email: "aofarrel@ucsc.edu"
	}
}
