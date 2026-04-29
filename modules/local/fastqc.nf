process FASTQC {
    tag "$sample_id"
    label 'process_low'
    conda "${projectDir}/envs/pipa.yml"

    publishDir "${params.output_dir}/fastqc/${sample_id}", mode: 'copy'

    input:
    tuple val(sample_id), path(reads)

    output:
    tuple val(sample_id), path("*.html"), emit: html
    tuple val(sample_id), path("*.zip"),  emit: zip

    script:
    """
    fastqc \\
        --threads ${task.cpus} \\
        --outdir . \\
        ${reads}
    """
}
