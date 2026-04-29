process QUAST {
    tag "$sample_id"
    label 'process_low'
    conda "${projectDir}/envs/pipa.yml"

    publishDir "${params.output_dir}/quast/${sample_id}", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly)

    output:
    tuple val(sample_id), path("${sample_id}_quast"),            emit: results
    tuple val(sample_id), path("${sample_id}_quast/report.tsv"), emit: tsv

    script:
    """
    quast.py \\
        ${assembly} \\
        --output-dir ${sample_id}_quast \\
        --threads    ${task.cpus} \\
        --min-contig ${params.min_contig_length} \\
        --no-icarus \\
        --label      ${sample_id}
    """
}
