# Changelog — PIPA

**P**ipeline for **I**ntegrated **P**rokaryotic **A**ssembly  
Formato basado en [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

## [2.0.0] — R2: Calidad Biológica

### Added
- **HU-11**: Screening taxonómico con **Kraken2** (`modules/local/kraken2.nf`)
  — reemplaza ConFindr; agnóstico al organismo, compatible con cualquier taxón agronómico
- **HU-12**: Evaluación de completitud y contaminación con **CheckM2**
  — ambiente conda aislado (`envs/checkm2.yml`) por conflictos de dependencias ML
- **HU-13**: Resumen QC automático **PASS / WARN / FAIL** por muestra
  — umbrales editables en `qc_conditions.yml` (`bin/qc_summary.py`)
- **HU-14**: Ejecución en **SLURM sin contenedores** vía Mamba (`conf/slurm.config`)
  — activable con `--hpc`; modo local por defecto
- **HU-15**: Labels de recursos (`process_low/medium/high`) + retry automático en OOM
  — `maxRetries=2` en exit codes 137/143/139 (`conf/base.config`)
- **HU-16**: Reportes automáticos de ejecución Nextflow
  — `report.html`, `timeline.html`, `trace.tsv`, `dag.html` en `pipeline_info/`

### Changed
- **Modo de ejecución por defecto**: ahora es `local` (sin SLURM)
  — SLURM se activa con `--hpc` en `run_pipeline.sh` o `-profile slurm` en Nextflow
- **ConFindr eliminado**: reemplazado por Kraken2
  — ConFindr depende de esquemas rMLST diseñados para patógenos clínicos;
    no tiene cobertura adecuada para organismos agronómicos (*Xanthomonas*,
    *Ralstonia*, *Pectobacterium*, *Clavibacter*, PGPR, etc.)

---

## [1.0.0] — R1: Core Assembly

### Added
- **HU-01**: Descubrimiento automático de muestras PE/SE por patrón glob
- **HU-02**: Validación de parámetros obligatorios al inicio del pipeline
- **HU-03**: Control de calidad de lecturas crudas con **FastQC**
- **HU-04**: Trimming y filtrado con **fastp** (PE/SE, auto-detección de adaptadores)
- **HU-05**: Estimación de tamaño del genoma con **Mash** + prescreen opcional
- **HU-06**: Downsampling a profundidad objetivo con **Rasusa** (opcional, `--depth_cutoff`)
- **HU-07**: Ensamblaje de novo con **SPAdes** — modos: `careful`, `meta`, `plasmid`, `rna`
- **HU-08**: Filtrado de contigs por longitud mínima + renombrado con `sample_id`
- **HU-09**: Métricas de ensamblaje con **QUAST** (N50, tamaño total, GC%, contigs)
- **HU-10**: Reporte agregado **MultiQC** (FastQC + fastp + QUAST)

### Design decisions
- Sin Docker, Apptainer ni Singularity — todas las herramientas en ambientes Mamba/Conda
- Orientado a microorganismos de interés agronómico (AGROSAVIA), no a patógenos clínicos
- Ejecución local como modo por defecto; SLURM como opción explícita
- **Rasusa** elegido sobre `seqtk` para downsampling: acepta directamente el tamaño
  del genoma estimado por Mash sin conversión intermedia de bp → número de reads

---

## Roadmap

| Release | Versión | Contenido |
|---------|---------|-----------|
| R3 | v3.0.0 | Tipificación MLST, identificación de especie (GTDB-Tk), detección de plásmidos (MOB-suite) |
| R4 | v4.0.0 | Anotación funcional (Prokka / Bakta), CI/CD GitHub Actions, soporte Nanopore (Flye) |
