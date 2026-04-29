process KRAKEN2 {
    tag "$sample_id"
    label 'process_medium'
    conda "${projectDir}/envs/pipa.yml"

    publishDir "${params.output_dir}/kraken2/${sample_id}", mode: 'copy'

    input:
    tuple val(sample_id), path(reads)

    output:
    tuple val(sample_id), path("${sample_id}.kraken2.report"),   emit: report
    tuple val(sample_id), path("${sample_id}.kraken2.output.gz"),emit: output
    tuple val(sample_id), path("${sample_id}.kraken2_summary.tsv"), emit: summary

    script:
    def single_end = reads instanceof Path || reads.size() == 1
    def reads_args = single_end
                     ? "--input ${reads[0]}"
                     : "--paired ${reads[0]} ${reads[1]}"
    def db_arg     = params.kraken2_db
                     ? "--db ${params.kraken2_db}"
                     : "--db ${projectDir}/kraken2_db"

    """
    kraken2 \\
        ${reads_args} \\
        ${db_arg} \\
        --threads    ${task.cpus} \\
        --report     ${sample_id}.kraken2.report \\
        --output     - \\
        --gzip-compressed \\
        --report-minimizer-data 2>/dev/null \\
        | gzip > ${sample_id}.kraken2.output.gz

    # ── Parse report → summary TSV ────────────────────────────────────────
    python3 - <<'PYEOF'
import csv, os, sys

sample   = "${sample_id}"
report   = "${sample_id}.kraken2.report"
out_tsv  = "${sample_id}.kraken2_summary.tsv"
min_pct  = ${params.kraken2_min_pct}

rows = []
top_genus   = ("unclassified", 0.0)
top_species = ("unclassified", 0.0)
unclassified_pct = 0.0

with open(report) as fh:
    for line in fh:
        parts = line.rstrip().split("\\t")
        if len(parts) < 6:
            continue
        pct    = float(parts[0].strip())
        rank   = parts[3].strip()
        name   = parts[5].strip()

        if name == "unclassified":
            unclassified_pct = pct
        if rank == "G" and pct > top_genus[1]:
            top_genus = (name, pct)
        if rank == "S" and pct > top_species[1]:
            top_species = (name, pct)
        if pct >= min_pct:
            rows.append({"sample": sample, "rank": rank, "name": name, "pct": pct})

classified_pct = 100.0 - unclassified_pct

# Flag if dominant genus < 80% (possible contamination or wrong species)
flag = "WARN" if top_genus[1] < 80.0 else "PASS"

with open(out_tsv, "w", newline="") as fh:
    writer = csv.DictWriter(
        fh,
        fieldnames=["sample", "flag", "classified_pct", "top_genus",
                    "top_genus_pct", "top_species", "top_species_pct"],
        delimiter="\\t"
    )
    writer.writeheader()
    writer.writerow({
        "sample":          sample,
        "flag":            flag,
        "classified_pct":  round(classified_pct, 2),
        "top_genus":       top_genus[0],
        "top_genus_pct":   round(top_genus[1], 2),
        "top_species":     top_species[0],
        "top_species_pct": round(top_species[1], 2),
    })

if flag == "WARN":
    sys.stderr.write(
        f"[KRAKEN2 WARN] {sample}: top genus '{top_genus[0]}' "
        f"covers only {top_genus[1]:.1f}% of reads. "
        f"Check for contamination or unexpected organism.\\n"
    )
print(f"[kraken2] {sample}: {classified_pct:.1f}% classified | "
      f"top genus: {top_genus[0]} ({top_genus[1]:.1f}%) | "
      f"top species: {top_species[0]} ({top_species[1]:.1f}%)")
PYEOF
    """
}
