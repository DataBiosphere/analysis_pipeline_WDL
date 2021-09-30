version 1.0

task pca_corr_vars {
    input {
        File gds_file
        String chromosome

        File? variant_include_file
        String? out_prefix
        Int? n_corr_vars
        
        # runtime attributes
        Int addldisk = 5
        Int cpu = 2
        Int memory = 4
        Int preempt = 3
    }

    # Estimate disk size required
    Int gds_size        = ceil(size(gds_file, "GB"))
    Int varinclude_size = select_first([ceil(size(variant_include_file, "GB")), 0])
    Int final_disk_dize = gds_size + varinclude_size + addldisk

    # Are optional files defined?
    Boolean defVariantInclude = defined(variant_include_file)
    

    command <<<
        set -eux -o pipefail

        echo "Generating config file"
        
        python << CODE
        import os

        f = open("pca_corr_vars.config", "a")

        if "~{out_prefix}" != "":
            f.write('out_file "~{out_prefix}_pca_corr_vars_chr .RData"\n')
        else:
            f.write('out_file "pca_corr_vars_chr .RData"\n')
        
        if "~{defVariantInclude}" == "true":
            f.write('variant_include_file "~{variant_include_file}"\n') 

        f.write('gds_file "~{gds_file}"\n')

        f.write('segment_file "/usr/local/analysis_pipeline/segments_hg38.txt"\n')

        f.close()

        CODE

        echo "Calling R script pca_corr_vars.R"
        R -q --vanilla --args pca_corr_vars.config --chromosome ~{chromosome} < /usr/local/analysis_pipeline/R/pca_corr_vars.R 
    >>>

    runtime {
        cpu: cpu
        docker: "uwgac/topmed-master@sha256:060ba9b9958f20b0a55995e8eb9edb886616efae3b4e943101048a5924ba8cd5"
        disks: "local-disk " + final_disk_dize + " HDD"
        memory: "${memory} GB"
        preemptibles: "${preempt}"
    }
    output {
        File pca_corr_vars  = glob("*.RData")[0]
        File config_file  = "pca_corr_vars.config"
    }

}

task pca_corr {
    input {
        File gds_file
        File pca_file

        File? variant_include_file
        Int? n_pcs_corr = 32
        String? out_prefix
        Int? chromosome
        
        # runtime attributes
        Int addldisk = 5
        Int cpu = 2
        Int memory = 4
        Int preempt = 3
    }

    # Estimate disk size required
    Int gds_size        = ceil(size(gds_file, "GB"))
    Int pca_size        = ceil(size(pca_file, "GB"))
    Int varinclude_size = select_first([ceil(size(variant_include_file, "GB")), 0])
    Int final_disk_dize = gds_size + pca_size + varinclude_size + addldisk

    # Are optional files defined?
    Boolean defVariantInclude    = defined(variant_include_file)
    

    command <<<
        set -eux -o pipefail

        echo "Generating config file"
        # noquotes = argument has no quotes in the config file to match CWL config EXACTLY
        python << CODE
        import os

        f = open("pca_corr.config", "a")

        if "chr" in "~{gds_file}":
            parts = os.path.splitext(os.path.basename("~{gds_file}"))[0].split("chr")
            outfile_temp = "pca_corr_chr" + parts[1] + ".gds"
        else:
            outfile_temp = "pca_corr.gds"


        if "~{out_prefix}" != "":
            outfile_temp = "~{out_prefix}_" + outfile_temp

        f.write('out_file "%s"\n'%(outfile_temp))
        
        f.write("n_pcs_corr ~{n_pcs_corr}\n")

        if "~{defVariantInclude}" == "true":
            f.write('variant_include_file "~{variant_include_file}"\n') 

        f.write('gds_file "~{gds_file}"\n')

        f.write('pca_file "~{pca_file}"\n')

        f.close()

        CODE

        echo "Calling R script pca_corr.R"
        R -q --vanilla --args pca_corr.config /usr/local/analysis_pipeline/R/pca_corr.R
    >>>

    runtime {
        cpu: cpu
        docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
        disks: "local-disk " + final_disk_dize + " HDD"
        memory: "${memory} GB"
        preemptibles: "${preempt}"
    }
    output {
        File pca_corr_gds  = glob("*.gds")[0]
        File config_file  = "pca_corr.config"
    }

}

task pca_corr_plots {
    input {
        Array[File] corr_file

        Int? n_pcs_plot = 20
        Int? n_perpage  = 4
        String? out_prefix
        
        # runtime attributes
        Int addldisk = 5
        Int cpu = 2
        Int memory = 4
        Int preempt = 3
    }

    # Estimate disk size required
    Int corr_size        = ceil(size(corr_file, "GB"))
    Int final_disk_dize  = corr_size + addldisk
    

    command <<<
        set -eux -o pipefail


        ## Soft link files so they can be addressed from the same directory
        BASH_FILES=(~{sep=" " corr_file})
        for BASH_FILE in ${BASH_FILES[@]};
        do
            ln -s ${BASH_FILE} .
        done


        echo "Generating config file"
        # noquotes = argument has no quotes in the config file to match CWL config EXACTLY
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

        corr_array_fullpath = ['~{sep="','" corr_file}']

        corr_array_basenames = []
        for fullpath in corr_array_fullpath:
            corr_array_basenames.append(os.path.basename(fullpath))

        a_file = corr_array_basenames[0]
        chr = find_chromosome(os.path.basename(a_file));
        path = a_file.split('chr'+chr);


        # make list of all chromosomes found in input files
        chr_array = []
        for corr_file in corr_array_basenames:
            chrom_num = find_chromosome(corr_file)
            chr_array.append(chrom_num)
        
        ## Sort as string to match CWL: "1 10 2 20 21 22 3 8 9 X"
        chr_array = [str(i) for i in chr_array]
        chr_array.sort()
        chrs = ' '.join(chr_array)


        f = open("pca_corr_plots.config", "a")

        f.write('corr_file "' + path[0] + 'chr ' + path[1] + '"\n')

        f.write('chromosomes "' + chrs + '"\n')
        
        f.write('n_pcs ~{n_pcs_plot}\n')

        f.write('n_perpage ~{n_perpage}\n')

        if "~{out_prefix}" != "":
            f.write('out_prefix "~{out_prefix}"\n')

        f.close()

        CODE

        echo "Calling R script pca_corr_plots.R"
        R -q --vanilla --args pca_corr_plots.config /usr/local/analysis_pipeline/R/pca_corr_plots.R 
    >>>

    runtime {
        cpu: cpu
        docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
        disks: "local-disk " + final_disk_dize + " HDD"
        memory: "${memory} GB"
        preemptibles: "${preempt}"
    }
    output {
        Array[File] pca_corr_plots = glob("*.png")
        File config_file  = "pca_corr_plots.config"
    }

}


workflow pc_variant_correlation {
    input {
        Array[File] gds_file_full
        File pca_file

        String? out_prefix
        File? variant_include_file
        Int? n_corr_vars
        Int? n_pcs
        Int? n_pcs_plot
        Int? n_perpage

    }

    scatter(gds_file_full_i in gds_file_full) {
        
        ## Pull chromosome number to pass to pca_corr_var task
        String FILE_PREFIX = basename(gds_file_full_i, ".gds")
        String CHROM = sub(FILE_PREFIX, "^.*chr", "")
        
        Boolean CHR_FOUND = (CHROM!=FILE_PREFIX)
        String CHROM_NUM = if (CHR_FOUND) then CHROM else "NA"


        call pca_corr_vars {
            input:
                gds_file=gds_file_full_i,
                chromosome=CHROM_NUM,
                variant_include_file = variant_include_file,
                out_prefix = out_prefix,
                n_corr_vars = n_corr_vars
        }

        call pca_corr {
            input:
                gds_file=gds_file_full_i,
                variant_include_file = pca_corr_vars.pca_corr_vars,
                pca_file = pca_file,
                n_pcs_corr = n_pcs,
                out_prefix = out_prefix           
        }

    }

    call pca_corr_plots {
        input:
            n_pcs_plot=n_pcs_plot,
            corr_file=pca_corr.pca_corr_gds,
            n_perpage=n_perpage,
            out_prefix=out_prefix
    }


    output {
        Array[File] pc_correlation_plots = pca_corr_plots.pca_corr_plots
        Array[File] pca_corr_gds = pca_corr.pca_corr_gds
    }

    meta {
        author: "Julian Lucas"
        email: "juklucas@ucsc.edu"
    }
}