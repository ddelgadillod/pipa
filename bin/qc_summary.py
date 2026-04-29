#!/usr/bin/env python3
"""
qc_summary.py
─────────────
Aggregate per-sample QC metrics from QUAST, CheckM2, ConFindr, and
filter_stats, then apply pass/warn/fail thresholds from a YAML config.

Outputs:
  qc_summary.tsv        — all samples
  qc_summary_flagged.tsv — only WARN / FAIL samples
"""

import argparse
import csv
import glob
import os
import sys
import yaml


# ─── Metric parsers ───────────────────────────────────────────────────────────

def parse_quast_tsv(path: str) -> dict:
    """Parse QUAST report.tsv and return a flat dict of metrics."""
    metrics = {}
    with open(path) as fh:
        reader = csv.reader(fh, delimiter='\t')
        for row in reader:
            if len(row) < 2:
                continue
            key = row[0].strip().lower().replace(' ', '_').replace('#', 'num').replace('>=', 'ge')
            val = row[1].strip()
            try:
                val = float(val)
                if val == int(val):
                    val = int(val)
            except ValueError:
                pass
            metrics[key] = val
    return metrics


def parse_checkm2_report(path: str) -> dict:
    """Parse CheckM2 quality_report.tsv and return metrics for the first genome."""
    with open(path) as fh:
        reader = csv.DictReader(fh, delimiter='\t')
        for row in reader:
            return {
                'checkm2_completeness':  float(row.get('Completeness', 0)),
                'checkm2_contamination': float(row.get('Contamination', 100)),
                'checkm2_genome_size':   int(row.get('Genome_Size', 0)),
                'checkm2_gc':            float(row.get('GC_Content', 0)),
            }
    return {}


def parse_confindr_report(path: str) -> dict:
    """Parse ConFindr confindr_report.csv and return metrics."""
    with open(path) as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            return {
                'confindr_status':    row.get('ContamStatus', 'NA').strip(),
                'confindr_snvs':      row.get('NumContamSNVs', 'NA').strip(),
                'confindr_genus':     row.get('Genus', 'NA').strip(),
            }
    return {}


def parse_filter_stats(path: str) -> dict:
    """Parse filter_stats.tsv produced by FILTER_CONTIGS."""
    with open(path) as fh:
        reader = csv.DictReader(fh, delimiter='\t')
        for row in reader:
            return {
                'total_contigs_raw': int(row.get('total_contigs', 0)),
                'kept_contigs':      int(row.get('kept_contigs', 0)),
                'total_bp_raw':      int(row.get('total_bp', 0)),
                'kept_bp':           int(row.get('kept_bp', 0)),
            }
    return {}


# ─── QC evaluator ────────────────────────────────────────────────────────────

def evaluate_qc(metrics: dict, conditions: dict) -> tuple[str, list]:
    """
    Apply thresholds from the YAML conditions dict.
    Returns (overall_status, [list_of_flagged_messages]).
    """
    flags = []
    worst = 'PASS'

    def update(level, msg):
        nonlocal worst
        flags.append(f"[{level}] {msg}")
        if level == 'FAIL' or (level == 'WARN' and worst != 'FAIL'):
            worst = level

    asm = conditions.get('assembly', {})
    qc  = conditions.get('reads', {})
    cm2 = conditions.get('checkm2', {})

    # QUAST metrics
    n50 = metrics.get('n50', 0)
    if 'N50' in asm:
        if n50 < asm['N50'].get('fail', 0):
            update('FAIL', f"N50={n50} < fail threshold {asm['N50']['fail']}")
        elif n50 < asm['N50'].get('warn', 0):
            update('WARN', f"N50={n50} < warn threshold {asm['N50']['warn']}")

    total_len = metrics.get('total_length', 0)
    if 'total_length' in asm:
        t = asm['total_length']
        if total_len < t.get('fail_min', 0) or total_len > t.get('fail_max', 1e15):
            update('FAIL', f"Total assembly length {total_len} outside fail range [{t['fail_min']}, {t['fail_max']}]")
        elif total_len < t.get('warn_min', 0) or total_len > t.get('warn_max', 1e15):
            update('WARN', f"Total assembly length {total_len} outside warn range")

    num_contigs = metrics.get('num_contigs', 0)
    if 'num_contigs' in asm:
        if num_contigs > asm['num_contigs'].get('fail', 1e9):
            update('FAIL', f"Contig count {num_contigs} > fail threshold {asm['num_contigs']['fail']}")
        elif num_contigs > asm['num_contigs'].get('warn', 1e9):
            update('WARN', f"Contig count {num_contigs} > warn threshold {asm['num_contigs']['warn']}")

    # CheckM2 metrics
    completeness = metrics.get('checkm2_completeness')
    contamination = metrics.get('checkm2_contamination')
    if completeness is not None and 'completeness' in cm2:
        if completeness < cm2['completeness'].get('fail', 0):
            update('FAIL', f"CheckM2 completeness {completeness:.1f}% < fail threshold {cm2['completeness']['fail']}%")
        elif completeness < cm2['completeness'].get('warn', 0):
            update('WARN', f"CheckM2 completeness {completeness:.1f}% < warn threshold")
    if contamination is not None and 'contamination' in cm2:
        if contamination > cm2['contamination'].get('fail', 100):
            update('FAIL', f"CheckM2 contamination {contamination:.1f}% > fail threshold {cm2['contamination']['fail']}%")
        elif contamination > cm2['contamination'].get('warn', 100):
            update('WARN', f"CheckM2 contamination {contamination:.1f}% > warn threshold")

    # ConFindr
    if metrics.get('confindr_status', '').lower() == 'contaminated':
        update('WARN', f"ConFindr: contamination detected ({metrics.get('confindr_snvs', 'N/A')} SNVs)")

    return worst, flags


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--quast-dir',      required=True)
    ap.add_argument('--checkm2-dir',    required=True)
    ap.add_argument('--confindr-dir',   required=True)
    ap.add_argument('--filter-stats',   required=True)
    ap.add_argument('--qc-conditions',  required=True)
    ap.add_argument('--output',         required=True)
    ap.add_argument('--flagged-output', required=True)
    args = ap.parse_args()

    with open(args.qc_conditions) as fh:
        conditions = yaml.safe_load(fh)

    # ── Discover per-sample files ─────────────────────────────────────────
    quast_files    = glob.glob(f"{args.quast_dir}/**/*_quast/report.tsv",   recursive=True)
    checkm2_files  = glob.glob(f"{args.checkm2_dir}/**/quality_report.tsv", recursive=True)
    confindr_files = glob.glob(f"{args.confindr_dir}/**/confindr_report.csv", recursive=True)
    filter_files   = glob.glob(f"{args.filter_stats}/**/*.filter_stats.tsv", recursive=True)
    # flat collect
    quast_files    += glob.glob(f"{args.quast_dir}/*.tsv")
    checkm2_files  += glob.glob(f"{args.checkm2_dir}/*.tsv")
    confindr_files += glob.glob(f"{args.confindr_dir}/*.csv")
    filter_files   += glob.glob(f"{args.filter_stats}/*.tsv")

    # Index by sample name (first token before _quast / _checkm2 etc.)
    def sample_from_path(p, suffix):
        base = os.path.basename(os.path.dirname(p))
        return base.replace(suffix, '').strip('_') or os.path.basename(p).split('.')[0]

    quast_index    = {sample_from_path(p, '_quast'):    p for p in quast_files}
    checkm2_index  = {sample_from_path(p, '_checkm2'):  p for p in checkm2_files}
    confindr_index = {sample_from_path(p, '_confindr'): p for p in confindr_files}
    filter_index   = {os.path.basename(p).split('.')[0]: p for p in filter_files}

    samples = sorted(set(quast_index.keys()))
    if not samples:
        print("WARNING: No QUAST reports found — summary will be empty.", file=sys.stderr)

    fieldnames = [
        'sample', 'qc_status', 'qc_flags',
        # QUAST
        'num_contigs', 'total_length', 'largest_contig', 'N50', 'N90',
        'GC_%', 'num_contigs_ge_500bp',
        # filter stats
        'total_contigs_raw', 'kept_bp',
        # CheckM2
        'checkm2_completeness', 'checkm2_contamination',
        # ConFindr
        'confindr_status', 'confindr_snvs', 'confindr_genus',
    ]

    rows, flagged = [], []

    for sample in samples:
        metrics = {}

        if sample in quast_index:
            metrics.update(parse_quast_tsv(quast_index[sample]))
        if sample in checkm2_index:
            metrics.update(parse_checkm2_report(checkm2_index[sample]))
        if sample in confindr_index:
            metrics.update(parse_confindr_report(confindr_index[sample]))
        if sample in filter_index:
            metrics.update(parse_filter_stats(filter_index[sample]))

        status, flags = evaluate_qc(metrics, conditions)

        row = {'sample': sample, 'qc_status': status, 'qc_flags': '; '.join(flags)}
        for field in fieldnames[3:]:
            row[field] = metrics.get(field, 'NA')
        rows.append(row)
        if status != 'PASS':
            flagged.append(row)

    def write_tsv(path, data):
        with open(path, 'w', newline='') as fh:
            writer = csv.DictWriter(fh, fieldnames=fieldnames, delimiter='\t',
                                    extrasaction='ignore')
            writer.writeheader()
            writer.writerows(data)

    write_tsv(args.output, rows)
    write_tsv(args.flagged_output, flagged)

    # Print summary to stdout
    total  = len(rows)
    n_pass = sum(1 for r in rows if r['qc_status'] == 'PASS')
    n_warn = sum(1 for r in rows if r['qc_status'] == 'WARN')
    n_fail = sum(1 for r in rows if r['qc_status'] == 'FAIL')
    print(f"\nQC Summary: {total} samples — "
          f"PASS: {n_pass}  WARN: {n_warn}  FAIL: {n_fail}")
    if flagged:
        print("\nFlagged samples:")
        for r in flagged:
            print(f"  [{r['qc_status']}] {r['sample']}: {r['qc_flags']}")


if __name__ == '__main__':
    main()
