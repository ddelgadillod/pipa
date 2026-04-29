process MULTIQC {
    label 'process_low'
    conda "${projectDir}/envs/pipa.yml"

    publishDir "${params.output_dir}/multiqc", mode: 'copy'

    input:
    path(multiqc_files)  // collected flat list of QC files

    output:
    path("multiqc_report.html"), emit: report
    path("multiqc_data"),        emit: data

    script:
    def config_arg = params.multiqc_config ? "--config ${params.multiqc_config}" : ""

    """
    multiqc \\
        ${config_arg} \\
        --force \\
        --outdir . \\
        .
    """
}
