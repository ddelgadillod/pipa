process CHECKM2 {
    tag "$sample_id"
    label 'process_high'
    // CheckM2 has heavy ML dependencies; kept in its own env to avoid conflicts
    conda "${projectDir}/envs/checkm2.yml"

    publishDir "${params.output_dir}/checkm2/${sample_id}", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly)

    output:
    tuple val(sample_id), path("${sample_id}_checkm2"),                           emit: results
    tuple val(sample_id), path("${sample_id}_checkm2/quality_report.tsv"),        emit: report

    script:
    def db_arg = params.checkm2_db_path
                 ? "--database_path ${params.checkm2_db_path}"
                 : ""

    """
    # CheckM2 expects a directory of FASTA files, not a single file
    mkdir -p checkm2_input
    cp ${assembly} checkm2_input/${sample_id}.fasta

    checkm2 predict \\
        --input            checkm2_input \\
        --output-directory ${sample_id}_checkm2 \\
        --threads          ${task.cpus} \\
        --extension        fasta \\
        ${db_arg} \\
        --force

    # Rename report for clarity
    mv ${sample_id}_checkm2/quality_report.tsv ${sample_id}_checkm2/quality_report.tsv || true
    """
}
