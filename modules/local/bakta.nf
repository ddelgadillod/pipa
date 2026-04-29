process BAKTA {
    tag "$sample_id"
    label 'process_medium'
    conda "${projectDir}/envs/bakta.yml"

    publishDir "${params.output_dir}/annotation/bakta/${sample_id}", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly)

    output:
    tuple val(sample_id), path("${sample_id}.gff3"),  emit: gff3
    tuple val(sample_id), path("${sample_id}.gbff"),  emit: gbff
    tuple val(sample_id), path("${sample_id}.faa"),   emit: faa
    tuple val(sample_id), path("${sample_id}.ffn"),   emit: ffn
    tuple val(sample_id), path("${sample_id}.fna"),   emit: fna
    tuple val(sample_id), path("${sample_id}.tsv"),   emit: tsv
    tuple val(sample_id), path("${sample_id}.txt"),   emit: stats
    tuple val(sample_id), path("${sample_id}.json"),  emit: json  // machine-readable, único en Bakta
    tuple val(sample_id), path("${sample_id}.log"),   emit: log

    script:
    def db_arg      = params.bakta_db
                      ? "--db ${params.bakta_db}"
                      : error("ERROR: --bakta_db is required when annotation_tool includes 'bakta'")
    def genus_arg   = params.annotation_genus   ? "--genus   '${params.annotation_genus}'"   : ""
    def species_arg = params.annotation_species ? "--species '${params.annotation_species}'" : ""
    def strain_arg  = params.annotation_strain  ? "--strain  '${params.annotation_strain}'"  : ""
    def locus_arg   = params.locus_tag_prefix   ? "--locus-tag '${params.locus_tag_prefix}'" : "--locus-tag '${sample_id}'"
    def topology    = params.genome_topology    ?: "linear"
    def proteins_arg = params.bakta_proteins    ? "--proteins '${params.bakta_proteins}'"    : ""
    def db_type_arg  = params.bakta_db_type == 'light' ? "--skip-pseudo" : ""

    """
    bakta \\
        --output    bakta_out \\
        --prefix    ${sample_id} \\
        --threads   ${task.cpus} \\
        ${db_arg} \\
        ${genus_arg} \\
        ${species_arg} \\
        ${strain_arg} \\
        ${locus_arg} \\
        ${proteins_arg} \\
        ${db_type_arg} \\
        --keep-contig-headers \\
        --force \\
        ${assembly} \\
        2>&1 | tee ${sample_id}.log

    # Promote outputs to working directory
    for ext in gff3 gbff faa ffn fna tsv txt json; do
        [ -f bakta_out/${sample_id}.\$ext ] && cp bakta_out/${sample_id}.\$ext . || true
    done

    # Verify mandatory outputs
    for ext in gff3 faa tsv; do
        if [ ! -f ${sample_id}.\$ext ]; then
            echo "ERROR: Bakta did not produce ${sample_id}.\$ext" >&2
            cat ${sample_id}.log >&2
            exit 1
        fi
    done

    # Quick summary from .txt report
    echo "--- Bakta annotation summary for ${sample_id} ---" >&2
    grep -E "^[[:space:]]+(tRNAs|tmRNAs|rRNAs|ncRNAs|CRISPRs|CDSs|sORFs)" \\
        ${sample_id}.txt >&2 || true
    """
}
