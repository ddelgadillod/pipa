process QC_SUMMARY {
    label 'process_low'
    conda "${projectDir}/envs/pipa.yml"

    publishDir "${params.output_dir}", mode: 'copy'

    input:
    path(quast_tsvs)               // collected from QUAST.out.tsv
    path(checkm2_reports)          // collected from CHECKM2.out.report (may be empty)
    path(confindr_reports)         // collected from CONFINDR.out.report (may be empty)
    path(filter_stats)             // collected from FILTER_CONTIGS.out.stats
    path(qc_conditions)

    output:
    path("qc_summary.tsv"),        emit: tsv
    path("qc_summary_flagged.tsv"),emit: flagged  // only WARN/FAIL samples

    script:
    """
    python3 ${projectDir}/bin/qc_summary.py \\
        --quast-dir       . \\
        --checkm2-dir     . \\
        --confindr-dir    . \\
        --filter-stats    . \\
        --qc-conditions   ${qc_conditions} \\
        --output          qc_summary.tsv \\
        --flagged-output  qc_summary_flagged.tsv
    """
}
