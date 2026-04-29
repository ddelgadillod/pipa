process PROKKA {
    tag "$sample_id"
    label 'process_medium'
    conda "${projectDir}/envs/pipa.yml"

    publishDir "${params.output_dir}/annotation/prokka/${sample_id}", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly)

    output:
    tuple val(sample_id), path("${sample_id}.gff"),  emit: gff
    tuple val(sample_id), path("${sample_id}.gbk"),  emit: gbk
    tuple val(sample_id), path("${sample_id}.faa"),  emit: faa       // proteínas
    tuple val(sample_id), path("${sample_id}.ffn"),  emit: ffn       // genes (nt)
    tuple val(sample_id), path("${sample_id}.tsv"),  emit: tsv       // tabla de features
    tuple val(sample_id), path("${sample_id}.txt"),  emit: stats     // resumen
    tuple val(sample_id), path("${sample_id}.log"),  emit: log

    script:
    def genus_arg   = params.annotation_genus   ? "--genus   '${params.annotation_genus}'"   : ""
    def species_arg = params.annotation_species ? "--species '${params.annotation_species}'" : ""
    def strain_arg  = params.annotation_strain  ? "--strain  '${params.annotation_strain}'"  : ""
    def locus_arg   = params.locus_tag_prefix   ? "--locustag '${params.locus_tag_prefix}'"  : "--locustag '${sample_id}'"
    def proteins_arg = params.prokka_proteins   ? "--proteins '${params.prokka_proteins}'"   : ""

    """
    prokka \\
        --outdir    prokka_out \\
        --prefix    ${sample_id} \\
        --cpus      ${task.cpus} \\
        --kingdom   Bacteria \\
        --rfam \\
        --compliant \\
        ${genus_arg} \\
        ${species_arg} \\
        ${strain_arg} \\
        ${locus_arg} \\
        ${proteins_arg} \\
        --force \\
        ${assembly} \\
        2>&1 | tee ${sample_id}.log

    # Promote outputs to working directory
    for ext in gff gbk faa ffn fna tsv txt; do
        [ -f prokka_out/${sample_id}.\$ext ] && cp prokka_out/${sample_id}.\$ext . || true
    done

    # Verify mandatory outputs exist
    for ext in gff faa tsv; do
        if [ ! -f ${sample_id}.\$ext ]; then
            echo "ERROR: Prokka did not produce ${sample_id}.\$ext" >&2
            cat ${sample_id}.log >&2
            exit 1
        fi
    done

    # Print quick summary
    echo "--- Prokka annotation summary for ${sample_id} ---" >&2
    grep -E "^(CDS|rRNA|tRNA|repeat_region|tmRNA)" ${sample_id}.tsv \\
        | awk -F'\\t' '{count[\$2]++} END {for(t in count) print t": "count[t]}' \\
        | sort >&2 || true
    """
}
