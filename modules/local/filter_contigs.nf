process FILTER_CONTIGS {
    tag "$sample_id"
    label 'process_low'
    conda "${projectDir}/envs/pipa.yml"

    publishDir "${params.output_dir}/assemblies", mode: 'copy'

    input:
    tuple val(sample_id), path(scaffolds)

    output:
    tuple val(sample_id), path("${sample_id}.fasta"),            emit: fasta
    tuple val(sample_id), path("${sample_id}.filter_stats.tsv"), emit: stats

    script:
    """
    python3 - <<'PYEOF'
import sys, os

sample   = "${sample_id}"
min_len  = ${params.min_contig_length}
in_file  = "${scaffolds}"
out_fa   = f"{sample}.fasta"
out_stat = f"{sample}.filter_stats.tsv"

total_n, kept_n = 0, 0
total_bp, kept_bp = 0, 0

def parse_fasta(path):
    header, seq = None, []
    with open(path) as fh:
        for line in fh:
            line = line.rstrip()
            if line.startswith('>'):
                if header is not None:
                    yield header, ''.join(seq)
                header, seq = line[1:], []
            else:
                seq.append(line)
    if header is not None:
        yield header, ''.join(seq)

idx = 1
with open(out_fa, 'w') as fout:
    for header, seq in parse_fasta(in_file):
        total_n  += 1
        total_bp += len(seq)
        if len(seq) >= min_len:
            kept_n  += 1
            kept_bp += len(seq)
            fout.write(f">{sample}_{idx:05d} {header}\\n{seq}\\n")
            idx += 1

with open(out_stat, 'w') as fs:
    fs.write("sample\\ttotal_contigs\\tkept_contigs\\ttotal_bp\\tkept_bp\\tfilter_len\\n")
    fs.write(f"{sample}\\t{total_n}\\t{kept_n}\\t{total_bp}\\t{kept_bp}\\t{min_len}\\n")

if kept_n == 0:
    sys.stderr.write(f"ERROR: All contigs filtered out for {sample} (min_len={min_len}). "
                     f"Longest contig = {total_bp} bp.\\n")
    sys.exit(1)

print(f"Filtered: {kept_n}/{total_n} contigs kept ({kept_bp}/{total_bp} bp)")
PYEOF
    """
}
