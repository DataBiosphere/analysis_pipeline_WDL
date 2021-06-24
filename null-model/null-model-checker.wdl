version 1.0

# Caveat programmator: This runs the null model workflow NINE times.
# It is currently configured to only run locally at the moment, and
# does not have any truth files for the time being.

import "https://raw.githubusercontent.com/DataBiosphere/analysis_pipeline_WDL/implement-null-model/null-model/null-model-wf.wdl" as nullmodel

workflow checker_ldprune {
	input {

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
	}

	##############################
	#        SB WS Example       #
	##############################
	call nullmodel.null_model_r as aaa__nullmodelr {
		input:
			#conditional_variant_file = 
			covars = ["sex", "age", "study", "PC1", "PC2", "PC3", "PC4", "PC5"],
			family = "gaussian",
			#gds_files =
			group_var = "study",
			inverse_normal = false,
			#n_pcs = 
			#norm_bygroup
			outcome = "height",
			output_prefix = "Null_model_mixed",
			#pca_file = 
			phenotype_file = phenotype_file_alternative,
			relatedness_matrix_file = relatedness_matrix_file_alternative,
			#rescale_variance = 
			#resid_covars = 
			#sample_include_file = 
	}
	call nullmodel.null_model_report as aaa__nullmodelreport {
		input:
			null_model_files = aaa__nullmodelr.null_model_files,
			null_model_params = aaa__nullmodelr.null_model_params,#
			
			#conditional_variant_file = 
			covars = ["sex", "age", "study", "PC1", "PC2", "PC3", "PC4", "PC5"],
			family = "gaussian",
			#gds_files =
			group_var = "study",
			inverse_normal = false,
			#n_pcs = 
			#norm_bygroup
			output_prefix = "Null_model_mixed",
			#pca_file = 
			phenotype_file = phenotype_file_alternative,
			relatedness_matrix_file = relatedness_matrix_file_alternative,
			#rescale_variance = 
			#resid_covars = 
			#sample_include_file = 
	}#

	##############################
	#          base case         #
	##############################
	call nullmodel.null_model_r as basecase__nullmodelr {
		input:
			#conditional_variant_file = 
			covars = ["sex", "Population"],
			family = "gaussian",
			#gds_files =
			#group_var = 
			#inverse_normal = 
			n_pcs = 4,
			#norm_bygroup
			outcome = "outcome",
			output_prefix = output_prefix,
			pca_file = pca_file,
			phenotype_file = phenotype_file,
			relatedness_matrix_file = relatedness_matrix_file,
			#rescale_variance = 
			#resid_covars = 
			sample_include_file = sample_include_file_unrelated
	}
	call nullmodel.null_model_report as basecase__nullmodelreport {
		input:
			null_model_files = basecase__nullmodelr.null_model_files,
			null_model_params = basecase__nullmodelr.null_model_params,
			
			#conditional_variant_file = 
			covars = ["sex", "Population"],
			family = "gaussian",
			#gds_files =
			#group_var = 
			#inverse_normal = 
			n_pcs = 4,
			#norm_bygroup
			output_prefix = output_prefix,
			pca_file = pca_file,
			phenotype_file = phenotype_file,
			relatedness_matrix_file = relatedness_matrix_file,
			#rescale_variance = 
			#resid_covars = 
			sample_include_file = sample_include_file_unrelated
	}

	##############################
	#           binary           #
	##############################

	call nullmodel.null_model_r as binary__nullmodelr {
		input:
			#conditional_variant_file = 
			covars = ["sex", "Population"],
			family = "gaussian",
			#gds_files =
			#group_var = 
			#inverse_normal = 
			n_pcs = 4,
			#norm_bygroup
			outcome = "outcome",
			output_prefix = output_prefix,
			pca_file = pca_file,
			phenotype_file = phenotype_file,
			relatedness_matrix_file = relatedness_matrix_file,
			#rescale_variance = 
			#resid_covars = 
			#sample_include_file = 
	}
	call nullmodel.null_model_report as binary__nullmodelreport {
		input:
			null_model_files = binary__nullmodelr.null_model_files,
			null_model_params = binary__nullmodelr.null_model_params,

			#conditional_variant_file = 
			covars = ["sex", "Population"],
			family = "gaussian",
			#gds_files =
			#group_var = 
			#inverse_normal = 
			n_pcs = 4,
			#norm_bygroup
			output_prefix = output_prefix,
			pca_file = pca_file,
			phenotype_file = phenotype_file,
			relatedness_matrix_file = relatedness_matrix_file,
			#rescale_variance = 
			#resid_covars = 
			#sample_include_file = 
	}
	##############################
	#        conditional         #
	##############################
	call nullmodel.null_model_r as conditional__nullmodelr {
		input:
			conditional_variant_file = conditional_variant_file,
			covars = ["sex", "Population"],
			family = "gaussian",
			gds_files = gds_files,
			#group_var = 
			#inverse_normal = 
			n_pcs = 4,
			#norm_bygroup = 
			outcome = "outcome",
			output_prefix = output_prefix,
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
			#inverse_normal = 
			n_pcs = 4,
			#norm_bygroup = 
			output_prefix = output_prefix,
			pca_file = pca_file,
			phenotype_file = phenotype_file,
			relatedness_matrix_file = relatedness_matrix_file,
			#rescale_variance = 
			#resid_covars = 
			sample_include_file = sample_include_file_typical
	}
	##############################
	#            grm             #
	##############################

	call nullmodel.null_model_r as grm__nullmodelr {
		input:
			#conditional_variant_file = 
			covars = ["sex", "Population"],
			family = "gaussian",
			#gds_files = 
			#group_var = 
			#inverse_normal = 
			n_pcs = 0,
			#norm_bygroup = 
			outcome = "outcome",
			output_prefix = output_prefix,
			#pca_file = 
			phenotype_file = phenotype_file,
			relatedness_matrix_file = relatedness_matrix_file_grm,
			rescale_variance = "marginal",
			#resid_covars = 
			sample_include_file = sample_include_file_typical
	}
	call nullmodel.null_model_report as grm__nullmodelreport {
		input:
			null_model_files = grm__nullmodelr.null_model_files,
			null_model_params = grm__nullmodelr.null_model_params,
			
			#conditional_variant_file = 
			covars = ["sex", "Population"],
			family = "gaussian",
			#gds_files = 
			#group_var = 
			#inverse_normal = 
			n_pcs = 0,
			#norm_bygroup = 
			output_prefix = output_prefix,
			pca_file = pca_file,
			phenotype_file = phenotype_file,
			relatedness_matrix_file = relatedness_matrix_file_grm,
			rescale_variance = "marginal",
			#resid_covars = 
			sample_include_file = sample_include_file_typical
	}
	##############################
	#           group            #
	##############################
	call nullmodel.null_model_r as group__nullmodelr {
		input:
			#conditional_variant_file = 
			covars = ["sex", "Population"],
			family = "gaussian",
			#gds_files =
			group_var = "Population",
			#inverse_normal = 
			n_pcs = 4,
			norm_bygroup = true,
			outcome = "outcome",
			output_prefix = output_prefix,
			pca_file = pca_file,
			phenotype_file = phenotype_file,
			relatedness_matrix_file = relatedness_matrix_file,
			#rescale_variance = 
			#resid_covars = 
			#sample_include_file = 
	}
	call nullmodel.null_model_report as group__nullmodelreport {
		input:
			null_model_files = group__nullmodelr.null_model_files,
			null_model_params = group__nullmodelr.null_model_params,
			
			#conditional_variant_file = 
			covars = ["sex", "Population"],
			family = "gaussian",
			#gds_files =
			group_var = "Population",
			#inverse_normal = 
			n_pcs = 4,
			norm_bygroup = true,
			output_prefix = output_prefix,
			pca_file = pca_file,
			phenotype_file = phenotype_file,
			relatedness_matrix_file = relatedness_matrix_file,
			#rescale_variance = 
			#resid_covars = 
			#sample_include_file = 
	}
	##############################
	#        norm bygroup        #
	##############################
	call nullmodel.null_model_r as norm__nullmodelr {
		input:
			#conditional_variant_file = 
			covars = ["sex", "Population"],
			family = "gaussian",
			#gds_files =
			group_var = "Population",
			#inverse_normal = 
			n_pcs = 4,
			norm_bygroup = true,
			outcome = "outcome",
			output_prefix = output_prefix,
			pca_file = pca_file,
			phenotype_file = phenotype_file,
			relatedness_matrix_file = relatedness_matrix_file,
			#rescale_variance = 
			#resid_covars = 
			#sample_include_file = 
	}
	call nullmodel.null_model_report as norm__nullmodelreport {
		input:
			null_model_files = norm__nullmodelr.null_model_files,
			null_model_params = norm__nullmodelr.null_model_params,
			
			#conditional_variant_file = 
			covars = ["sex", "Population"],
			family = "gaussian",
			#gds_files =
			group_var = "Population",
			#inverse_normal = 
			n_pcs = 4,
			norm_bygroup = true,
			output_prefix = output_prefix,
			pca_file = pca_file,
			phenotype_file = phenotype_file,
			relatedness_matrix_file = relatedness_matrix_file,
			#rescale_variance = 
			#resid_covars = 
			#sample_include_file = 
	}
	##############################
	#        no transform        #
	##############################
	call nullmodel.null_model_r as notransform__nullmodelr {
		input:
			#conditional_variant_file = 
			covars = ["sex", "Population"],
			family = "gaussian",
			#gds_files =
			group_var = "Population",
			inverse_normal = false,
			n_pcs = 4,
			#norm_bygroup = 
			outcome = "outcome",
			output_prefix = output_prefix,
			pca_file = pca_file,
			phenotype_file = phenotype_file,
			relatedness_matrix_file = relatedness_matrix_file,
			rescale_variance = "none",
			#resid_covars = 
			sample_include_file = sample_include_file_typical
	}
	call nullmodel.null_model_report as notransform__nullmodelreport {
		input:
			null_model_files = notransform__nullmodelr.null_model_files,
			null_model_params = notransform__nullmodelr.null_model_params,
			
			#conditional_variant_file = 
			covars = ["sex", "Population"],
			family = "gaussian",
			#gds_files =
			group_var = "Population",
			inverse_normal = false,
			n_pcs = 4,
			#norm_bygroup = 
			output_prefix = output_prefix,
			pca_file = pca_file,
			phenotype_file = phenotype_file,
			relatedness_matrix_file = relatedness_matrix_file,
			rescale_variance = "none",
			#resid_covars = 
			sample_include_file = sample_include_file_typical
	}
	##############################
	#        unrel binary        #
	##############################
	call nullmodel.null_model_r as unrelbin__nullmodelr {
		input:
			#conditional_variant_file = 
			covars = ["sex"],
			family = "binomial",
			#gds_files =
			#group_var = 
			#inverse_normal = 
			n_pcs = 4,
			#norm_bygroup = 
			outcome = "status",
			output_prefix = output_prefix,
			pca_file = pca_file,
			phenotype_file = phenotype_file,
			#relatedness_matrix_file = 
			#rescale_variance = 
			#resid_covars = 
			sample_include_file = sample_include_file_unrelated
	}
	call nullmodel.null_model_report as unrelbin__nullmodelreport {
		input:
			null_model_files = unrelbin__nullmodelr.null_model_files,
			null_model_params = unrelbin__nullmodelr.null_model_params,
			
			#conditional_variant_file = 
			covars = ["sex"],
			family = "binomial",
			#gds_files =
			#group_var = 
			#inverse_normal = 
			n_pcs = 4,
			#norm_bygroup = 
			output_prefix = output_prefix,
			pca_file = pca_file,
			phenotype_file = phenotype_file,
			#relatedness_matrix_file = 
			#rescale_variance = 
			#resid_covars = 
			sample_include_file = sample_include_file_unrelated
	}
	##############################
	#          unrelated         #
	##############################
	call nullmodel.null_model_r as unrelated__nullmodelr {
		input:
			#conditional_variant_file = 
			covars = ["sex", "Population"],
			family = "gaussian",
			#gds_files =
			#group_var = 
			#inverse_normal = 
			n_pcs = 4,
			#norm_bygroup = 
			outcome = "outcome",
			output_prefix = output_prefix,
			pca_file = pca_file,
			phenotype_file = phenotype_file,
			#relatedness_matrix_file = 
			#rescale_variance = 
			#resid_covars = 
			sample_include_file = sample_include_file_unrelated
	}
	call nullmodel.null_model_report as unrelated__nullmodelreport {
		input:
			null_model_files = unrelated__nullmodelr.null_model_files,
			null_model_params = unrelated__nullmodelr.null_model_params,
			
			#conditional_variant_file = 
			covars = ["sex"],
			family = "gaussian",
			#gds_files =
			#group_var = 
			#inverse_normal = 
			n_pcs = 4,
			#norm_bygroup = 
			output_prefix = output_prefix,
			pca_file = pca_file,
			phenotype_file = phenotype_file,
			#relatedness_matrix_file = 
			#rescale_variance = 
			#resid_covars = 
			sample_include_file = sample_include_file_unrelated
	}
	meta {
		author: "Ash O'Farrell"
		email: "aofarrel@ucsc.edu"
	}
}
