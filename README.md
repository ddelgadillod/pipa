# PIPA — Pipeline for Integrated Prokaryotic Assembly

**P**ipeline for **I**ntegrated **P**rokaryotic **A**ssembly — Nextflow DSL2 pipeline for high-throughput prokaryotic genome assembly from Illumina paired-end (or single-end) reads.

Designed for agronomic research contexts (plant pathogens, biocontrol agents, PGPR) at AGROSAVIA.  
Runs with **Mamba/Conda environments** — no Docker, no Apptainer required.  
**Local execution by default**; SLURM opt-in with `--hpc`.

---

## Pipeline overview

```
Raw reads (FASTQ)
     │
     ├─► FastQC (raw)
     │
     ▼
  fastp ──► trimmed reads
     │
     ├─► Mash ──► genome size estimate
     │
     ├─► [Rasusa] ──► downsampled reads        (optional: --depth_cutoff)
     │
     ├─► [Kraken2] ──► taxonomic screening     (optional: --run_kraken2)
     │
     ▼
  SPAdes ──► scaffolds
     │
     ▼
  Filter contigs (min length)
     │
     ├─► QUAST ──── assembly stats
     │
     ├─► [CheckM2] ─ completeness / contamination   (optional: --run_checkm2)
     │
     ├─► [Prokka / Bakta / PGAP] ─ functional annotation  (optional: --annotation_tool)
     │
     └─► MultiQC ──► aggregated report
          └─► qc_summary.tsv  (PASS / WARN / FAIL per sample)
```

---

## Requirements

| Tool      | Version | Notes                                        |
|-----------|---------|----------------------------------------------|
| Nextflow  | ≥ 23.04 | `mamba install -c bioconda nextflow`         |
| Mamba     | ≥ 1.5   | via Miniforge / Mambaforge                   |

All bioinformatics tools are installed automatically into Conda environments the first time they are needed.

---

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/ddelgadillod/pipa.git
cd pipa
```

### 2. Create the Conda environments

Nextflow creates them automatically on first run, or pre-build manually:

```bash
# Main environment (FastQC, fastp, SPAdes, QUAST, Mash, Kraken2, Rasusa, Prokka…)
mamba env create -f envs/pipa.yml

# CheckM2 — isolated due to heavy ML dependencies (TensorFlow, scikit-learn)
mamba env create -f envs/checkm2.yml

# Bakta — isolated due to its own dependency tree
mamba env create -f envs/bakta.yml
```

### 3. Download databases (as needed)

```bash
# Kraken2 standard database (~8 GB) — required if --run_kraken2 true
kraken2-build --standard --db /path/to/kraken2_db

# CheckM2 database (~1.5 GB) — required if --run_checkm2 true
conda activate checkm2
checkm2 database --download --path /path/to/checkm2_db

# Bakta database — required if --annotation_tool bakta or both
conda activate bakta
bakta_db download --output /path/to/bakta_db --type full   # ~40 GB
# or lightweight version:
bakta_db download --output /path/to/bakta_db --type light  # ~2 GB
```

---

## Usage

### Local (default)

```bash
bash run_pipeline.sh \
    --input_dir  /path/to/reads \
    --output_dir results
```

### SLURM (HPC)

```bash
bash run_pipeline.sh \
    --input_dir  /path/to/reads \
    --output_dir results \
    --hpc
```

### Directly with Nextflow

```bash
# Local
nextflow run main.nf \
    --input_dir  /path/to/reads \
    --output_dir results

# SLURM
nextflow run main.nf \
    --input_dir  /path/to/reads \
    --output_dir results \
    -profile slurm
```

---

## Key parameters

| Parameter               | Default                       | Description                                            |
|-------------------------|-------------------------------|--------------------------------------------------------|
| `--input_dir`           | **required**                  | Directory containing FASTQ files                       |
| `--output_dir`          | `results`                     | Output directory                                       |
| `--fastq_pattern`       | `*{_R,_}{1,2}*.fastq.gz`     | Glob pattern for paired reads                          |
| `--single_end`          | `false`                       | Set `true` for single-end reads                        |
| `--spades_mode`         | `careful`                     | `careful` \| `meta` \| `plasmid` \| `rna`             |
| `--depth_cutoff`        | *(none)*                      | Downsample to N× coverage before assembly              |
| `--min_contig_length`   | `500`                         | Filter contigs shorter than this (bp)                  |
| `--run_kraken2`         | `true`                        | Taxonomic screening with Kraken2                       |
| `--kraken2_db`          | **required if kraken2=true**  | Path to Kraken2 database                               |
| `--run_checkm2`         | `true`                        | Completeness/contamination with CheckM2                |
| `--checkm2_db_path`     | *(auto-download)*             | Path to CheckM2 DIAMOND database                       |
| `--annotation_tool`     | `none`                        | `prokka` \| `bakta` \| `both` \| `pgap` \| `none`     |
| `--bakta_db`            | **required if bakta**         | Path to Bakta database                                 |
| `--annotation_genus`    | *(none)*                      | Organism genus (e.g. `Xanthomonas`)                    |
| `--annotation_species`  | *(none)*                      | Organism species (e.g. `axonopodis`)                   |
| `--hpc`                 | `false`                       | Submit jobs to SLURM (run_pipeline.sh only)            |
| `--slurm_queue`         | `normal`                      | SLURM partition                                        |
| `--slurm_account`       | *(none)*                      | SLURM account / project                                |
| `--max_cpus`            | `16`                          | Cap on CPUs per process                                |
| `--max_memory`          | `64.GB`                       | Cap on memory per process                              |

---

## Output structure

```
results/
├── assemblies/            # Filtered FASTA per sample  ← main deliverable
├── fastqc/                # FastQC HTML + zip (raw reads)
├── fastp/                 # Trimmed FASTQs + JSON/HTML QC reports
├── spades/                # SPAdes scaffolds + logs
├── quast/                 # QUAST reports per sample
├── kraken2/               # Kraken2 taxonomic reports per sample
├── checkm2/               # CheckM2 completeness reports per sample
├── annotation/
│   ├── prokka/            # Prokka annotation per sample (if enabled)
│   ├── bakta/             # Bakta annotation per sample (if enabled)
│   └── pgap_inputs/       # PGAP input files per sample (if enabled)
├── multiqc/               # multiqc_report.html
├── qc_summary.tsv         # All samples: PASS / WARN / FAIL
├── qc_summary_flagged.tsv # Only WARN/FAIL samples
└── pipeline_info/         # Nextflow report, timeline, trace, DAG
```

---

## QC thresholds

Edit `qc_conditions.yml` to adjust PASS/WARN/FAIL thresholds:
- Assembly N50, total length, contig count
- CheckM2 completeness and contamination
- Kraken2 classified reads percentage

---

## Profiles

| Profile | Description                                          |
|---------|------------------------------------------------------|
| `local` | Run all processes locally (default)                  |
| `slurm` | Submit all processes as SLURM jobs                   |
| `test`  | Uses `test_input/`; disables Kraken2 and CheckM2     |

---

## Design decisions

- **No containers**: all tools run in Mamba/Conda environments
- **Agronomic focus**: designed for plant-associated bacteria (*Xanthomonas*,
  *Ralstonia*, *Pectobacterium*, *Clavibacter*, PGPR, biocontrol agents), not clinical pathogens
- **Kraken2 over ConFindr**: ConFindr relies on rMLST schemes biased toward clinical
  pathogens and lacks coverage for most agronomic organisms
- **Local by default**: SLURM is opt-in, making the pipeline usable on any workstation
- **Rasusa over seqtk**: accepts genome size in bp directly from Mash — no intermediate
  conversion from bp to read count required

---

## Citation

If you use PIPA, please cite the underlying tools:

- SPAdes: Bankevich et al., *J. Comput. Biol.* 2012
- QUAST: Gurevich et al., *Bioinformatics* 2013
- CheckM2: Chklovski et al., *Nat. Methods* 2023
- fastp: Chen et al., *Bioinformatics* 2018
- Kraken2: Wood et al., *Genome Biol.* 2019
- Mash: Ondov et al., *Genome Biol.* 2016
- Rasusa: Hall, *JOSS* 2022
- Prokka: Seemann, *Bioinformatics* 2014
- Bakta: Schwengers et al., *Microbial Genomics* 2021