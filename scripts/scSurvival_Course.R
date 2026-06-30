# =============================================================================
# Single-Cell Survival Course with Seurat v5 (CITE-seq, RNA + ADT)
# Autors: Thais e Evelia
# GSE149689 | Wilk et al., Nature Medicine 2021
# -----------------------------------------------------------------------------

# HOW TO USE
#   Run interactively, section by section (Ctrl+Enter / Cmd+Enter), from top
#   to bottom. Do NOT source() the whole file in one go: several chunks are
#   deliberate errors meant to be read, and Block 8 is optional take-home
#   work that depends on a file released separately after the session.
#
# DELIBERATE ERRORS
#   Five steps are designed to fail (v4 slot access, GetAssayData slot=,
#   wrong filter thresholds, dims > npcs, plotting a label before adding it).
#   They are wrapped in try() so the error prints to the console without
#   halting a full run. Read the message, then continue.
#
# WORKING DIRECTORY
#   Set the working directory to the folder holding this script and the data/
#   subfolder (Session > Set Working Directory > To Source File Location).
# =============================================================================


# =============================================================================
# BLOCK 0  |  Setup
# =============================================================================

#Instructor only
source("instructor_answers.R")

# -----------------------------------------------------------------------------
# Step 0.1 | Install packages
# -----------------------------------------------------------------------------

# Checks each package before installing. If install.packages() fails, retries
# via BiocManager. Safe to run multiple times.

if (!requireNamespace("BiocManager", quietly = TRUE))
  install.packages("BiocManager")

all_pkgs <- c(
  "Seurat", "SeuratObject", "ggplot2", "patchwork",
  "dplyr", "tidyr", "Matrix", "harmony", "scales", "ggrepel",
  "SingleR", "celldex", "BiocParallel", "scDblFinder",
  "SingleCellExperiment"
)

for (pkg in all_pkgs) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    message("Installing: ", pkg)
    tryCatch(install.packages(pkg, quiet = TRUE),
             error   = function(e) NULL,
             warning = function(w) NULL)
    if (!requireNamespace(pkg, quietly = TRUE)) {
      message("  CRAN failed. Retrying via BiocManager...")
      tryCatch(
        BiocManager::install(pkg, ask = FALSE, update = FALSE),
        error   = function(e) message("  FAILED: ", e$message),
        warning = function(w) NULL
      )
    }
    if (requireNamespace(pkg, quietly = TRUE))
      message("  OK: ", pkg, " (", as.character(packageVersion(pkg)), ")")
    else
      message("  FAILED: ", pkg, ". Run the fallback chunk below.")
  } else {
    message("Already installed: ", pkg,
            " (", as.character(packageVersion(pkg)), ")")
  }
}

# -----------------------------------------------------------------------------
# Step 0.2 | Verify and load all libraries
# -----------------------------------------------------------------------------

# All packages are loaded here. No library() calls appear later in the script.
# If you see "namespace 'ggplot2' is imported by 'Seurat'..." that is not an
# error; the package is already active. Always do Session > Restart R before
# opening the script.

pkgs <- c("Seurat", "SeuratObject", "ggplot2", "patchwork",
          "dplyr", "tidyr", "Matrix", "SingleR", "celldex",
          "harmony", "scales", "ggrepel", "BiocParallel",
          "scDblFinder", "SingleCellExperiment")

for (pkg in pkgs)
  cat(sprintf("  %-18s %s\n", pkg,
              ifelse(requireNamespace(pkg, quietly = TRUE), "OK", "MISSING")))

cat("\nSeurat version:", as.character(packageVersion("Seurat")), "\n")

suppressPackageStartupMessages({
  library(Seurat);   library(SeuratObject); library(ggplot2)
  library(patchwork); library(dplyr);     library(tidyr);       library(Matrix)
  library(SingleR);  library(celldex);      library(BiocParallel)
  library(harmony);  library(scales);       library(ggrepel)
})
cat("\nAll libraries loaded.\n")

# -----------------------------------------------------------------------------
# Step 0.3 | Folder structure
# -----------------------------------------------------------------------------

dir.create("data",    showWarnings = FALSE)
dir.create("outputs", showWarnings = FALSE)
cat("Folders ready.\n")

FILE_ID <- "1mCg4VD91qK7pg-zL1iYUUBFWBr7fmmCM"
options(timeout = 600)
download.file(
  url      = paste0("https://drive.google.com/uc?export=download&confirm=t&id=",
                    FILE_ID),
  destfile = "data/gse149689_subset_3k.rds",
  mode     = "wb"
)
cat("File exists:", file.exists("data/gse149689_subset_3k.rds"), "\n")
cat("Size (MB)  :", round(file.size("data/gse149689_subset_3k.rds") / 1e6, 1), "\n")


# -----------------------------------------------------------------------------
# Step 0.4 | reveal() helper (instructor use only)
# -----------------------------------------------------------------------------

# Prints the answer + live-demo code for any QUESTION or PUZZLE in this script.
# Answers are NOT in this file. They live in a separate instructor_answers.R
# that only the instructor loads with source() before class. Students running
# reveal() in a fresh session see a brief notice and nothing else.

reveal <- function(qid) {
  if (!exists(".answers", inherits = TRUE)) {
    cat("Instructor answers not loaded in this session.\n")
    cat("Ask the instructor for the answer to ", qid, ".\n", sep = "")
    return(invisible(NULL))
  }
  if (!qid %in% names(.answers)) {
    cat("ID '", qid, "' not found. Available IDs:\n", sep = "")
    print(names(.answers))
    return(invisible(NULL))
  }
  x   <- .answers[[qid]]
  bar <- strrep("=", 76)
  cat(bar, "\n", sep = "")
  cat(x$kind, " ", qid, "  (Block ", x$block, ", Step ", x$step, ")\n",
      sep = "")
  cat("\nPROMPT:\n", x$prompt, "\n", sep = "")
  cat("\nANSWER:\n", x$answer, "\n", sep = "")
  if (nzchar(x$demo)) cat("\nLIVE DEMO:\n", x$demo, sep = "")
  if (nzchar(x$plot)) cat("\nPLOT / OUTPUT: ", x$plot, "\n", sep = "")
  cat(bar, "\n", sep = "")
  invisible(x)
}

# Quick check: is the answer file already loaded?
if (exists(".answers", inherits = TRUE)) {
  cat("Instructor answers detected (", length(.answers), " entries). ",
      "Use reveal(\"1.2b\") for questions or reveal(\"1.9/A\") for puzzles.\n", sep = "")
} else {
  cat("Student session: reveal() is available but answers are not loaded.\n")
}

# ID format:
#   Questions: the number after "QUESTION" in the prompt, e.g. reveal("1.2b")
#   Puzzles:   the number after "PUZZLE" in the prompt, e.g. reveal("1.9/A")
#              (puzzle labels now include their step, so what you see in the
#              comment is exactly what you type)

# -----------------------------------------------------------------------------
# Step 0.5 | Namespace-safe accessor wrappers
# -----------------------------------------------------------------------------

# Seurat's Assays()/Layers()/Reductions() generics are defined in the
# SeuratObject package and re-exported by Seurat, but re-exports differ
# across versions (Layers() has failed as "not exported from Seurat" in one
# observed version while Assays() worked). Loading Bioconductor packages
# (SingleR, BiocParallel, celldex) can also introduce competing S4 generics
# that intercept calls when namespace resolution is ambiguous, producing
# errors like "no method for coercing this S4 class to a vector" on a call
# that looks completely ordinary. These wrappers try SeuratObject first,
# fall back to Seurat, then to a bare lookup, so the rest of the script does
# not depend on guessing which package exports what in your installed
# version.
.safe_accessor <- function(fname) {
  function(...) {
    if (exists(fname, where = asNamespace("SeuratObject"), inherits = FALSE)) {
      return(get(fname, envir = asNamespace("SeuratObject"))(...))
    }
    if (requireNamespace("Seurat", quietly = TRUE) &&
        exists(fname, where = asNamespace("Seurat"), inherits = FALSE)) {
      return(get(fname, envir = asNamespace("Seurat"))(...))
    }
    get(fname, mode = "function")(...)
  }
}
SafeAssays     <- .safe_accessor("Assays")
SafeLayers     <- .safe_accessor("Layers")
SafeReductions <- .safe_accessor("Reductions")

# =============================================================================
# BLOCK 1  |  Object inspection (RNA + ADT)
# =============================================================================

# We will inspect the RNA assay, contrast it with the
# ADT assay, walk through the layer system, the metadata, and the reductions
# slot.

# -----------------------------------------------------------------------------
# Step 1.1 | Load the object
# -----------------------------------------------------------------------------

# Loads the injected object (with embedded errors) when present, otherwise
# the clean object.
 
main_candidates <- c("data/gse149689_subset_3k_errors.rds",
                     "data/gse149689_subset_3k.rds")
main_path <- main_candidates[file.exists(main_candidates)][1]
if (is.na(main_path)) stop("No dataset found in data/. Expected one of: ",
                           paste(main_candidates, collapse = ", "))
sobj <- readRDS(main_path)
cat("Loaded:", main_path, "\n")
print(sobj)

# QUESTION 1.1: how many cells, how many features, how many assays? Which is
# the active (default) assay? Run the line below to get all four numbers.
cat("\nAnswer to QUESTION 1.1:\n")
cat("  Cells         :", ncol(sobj), "\n")
cat("  Features (RNA):", nrow(sobj[["RNA"]]), "\n")
cat("  Features (ADT):", nrow(sobj[["ADT"]]), "\n")
cat("  Assays        :", length(SafeAssays(sobj)), "(", paste(SafeAssays(sobj), collapse = ", "), ")\n")
cat("  Default assay :", DefaultAssay(sobj), "\n")

# -----------------------------------------------------------------------------
# Step 1.1b | Add mitochondrial genes (this panel does not ship with any)
# -----------------------------------------------------------------------------

# The 500-gene panel used for this course was curated around lineage and
# activation markers; it does not include MT- genes. Every QC step that
# depends on percent.mt (Block 2) needs a real signal to be useful, so we
# add 9 synthetic MT- genes here, with counts correlated to each cell's
# total library size and a stress component for a subset of cells.

set.seed(7)
mt_gene_names <- c("MT-ND1", "MT-ND2", "MT-CO1", "MT-CO2", "MT-ATP8",
                    "MT-ATP6", "MT-CO3", "MT-ND3", "MT-CYB")

if (!any(grepl("^MT-", rownames(sobj[["RNA"]])))) {
  rna_counts  <- LayerData(sobj, assay = "RNA", layer = "counts")
  total_count <- Matrix::colSums(rna_counts)

  # A log-normal draw gives a continuous, right-skewed distribution: most
  # cells sit at a low, biologically typical fraction, with a gradual tail
  # toward the small subset of stressed/dying cells. This mirrors real PBMC
  # data, where percent.mt has no gap between "healthy" and "stressed"; it
  # is one continuous distribution that QC thresholds cut into at some
  # chosen point.
  n_cells     <- ncol(rna_counts)
  target_frac <- rlnorm(n_cells, meanlog = log(0.035), sdlog = 0.6)
  target_frac <- pmin(target_frac, 0.35)  # cap at a biologically plausible ceiling

  mt_total_per_cell <- round(total_count * target_frac)
  mt_total_per_cell[mt_total_per_cell < length(mt_gene_names)] <- length(mt_gene_names)

  # Spread each cell's MT total across the 9 genes with unequal weights
  # (mirrors real data, where MT-CO1/MT-CO3/MT-CYB are usually the highest).
  gene_weights <- c(0.10, 0.08, 0.22, 0.14, 0.03, 0.07, 0.18, 0.06, 0.12)
  mt_mat <- sapply(seq_len(n_cells), function(i) {
    as.integer(round(mt_total_per_cell[i] * gene_weights))
  })
  rownames(mt_mat) <- mt_gene_names
  colnames(mt_mat) <- colnames(rna_counts)
  mt_mat_sparse <- as(mt_mat, "CsparseMatrix")

  rna_counts_with_mt <- rbind(rna_counts, mt_mat_sparse)
  # The warning here ("Different cells and/or features from existing assay
  # RNA") comes from the [[<- replacement method noticing the new assay has
  # 509 features instead of 500, not from CreateAssay5Object itself. It is
  # the expected, harmless side effect of adding genes to an assay; wrap the
  # whole assignment so it does not look like an error in the console.
  new_rna_assay <- CreateAssay5Object(counts = rna_counts_with_mt)
  suppressWarnings(sobj[["RNA"]] <- new_rna_assay)
  DefaultAssay(sobj) <- "RNA"

  cat("Added", length(mt_gene_names), "synthetic MT- genes to the RNA assay.\n")
  cat("RNA assay now has", nrow(sobj[["RNA"]]), "features (was 500).\n")
} else {
  cat("MT- genes already present; skipping synthesis.\n")
}

# -----------------------------------------------------------------------------
# Step 1.2 | Seurat v4 vs v5: how the count matrix is stored
# -----------------------------------------------------------------------------

# Seurat v5 changed how count matrices live inside an assay. v4 code that
# directly accesses @counts or uses slot= will error. The two patterns below
# are deliberate failures: read each error message.

# >>> DELIBERATE ERROR - read the message, then continue. <<<
try({
  # In Seurat v4, this was the standard way to get the count matrix.
  counts_old <- sobj@assays$RNA@counts
})

# >>> DELIBERATE ERROR - read the message, then continue. <<<
try({
  counts_old2 <- GetAssayData(sobj, slot = "counts")
})

# The `@counts` slot no longer exists in Seurat v5 `Assay5` objects. 

# The v5 argument is `layer=`. 
# Both of these errors are extremely common when receiving objects from collaborators or running old
# pipeline scripts.

# Pattern 1: LayerData(). Recommended for v5.
counts_rna <- LayerData(sobj, assay = "RNA", layer = "counts")
cat("RNA counts matrix dimensions (genes x cells):\n")
cat(" ", dim(counts_rna), "\n\n")

# Pattern 1b: three equivalent ways to pull ONE gene's counts without
# converting the whole sparse matrix to dense.
fetched <- FetchData(sobj, vars = "CD4", layer = "counts")[, 1]
indexed <- LayerData(sobj, assay = "RNA", layer = "counts")["CD4", ]
get_ad  <- GetAssayData(sobj, assay = "RNA", layer = "counts")["CD4", ]
cat("Three equivalent accessors for one gene's counts:\n")
cat("  FetchData            length:", length(fetched), " class:", class(fetched), "\n")
cat("  LayerData[gene, ]    length:", length(indexed), " class:", class(indexed), "\n")
cat("  GetAssayData[gene, ] length:", length(get_ad),  " class:", class(get_ad),  "\n")
cat("  All identical        :", all(fetched == indexed) && all(indexed == get_ad), "\n\n")

# Pattern 2: assay class
cat("RNA assay class :", class(sobj[["RNA"]]), "\n")
cat("ADT assay class :", class(sobj[["ADT"]]), "\n\n")

# Pattern 3: available layers
cat("RNA layers      :", paste(SafeLayers(sobj[["RNA"]]), collapse = ", "), "\n")
cat("ADT layers      :", paste(SafeLayers(sobj[["ADT"]]), collapse = ", "), "\n\n")

# Pattern 4: Seurat object version
cat("Object version  :", as.character(sobj@version), "\n")

# QUESTION 1.2: What is the class of the RNA assay? And the ADT assay? Why
# might they be the same class even though the data behave very differently?

# QUESTION 1.2c: FetchData(), LayerData()[gene, ], and GetAssayData()[gene, ]
# are all equivalent here. Why might they NOT be equivalent for normalized
# data instead of raw counts? (Think about what each function defaults to
# for the layer argument.)

# -----------------------------------------------------------------------------
# Step 1.2b | Full slot map of a Seurat object
# -----------------------------------------------------------------------------

# A Seurat object has more slots than most tutorials show. Some hold raw data,
# some hold derived results, some are caches, some are metadata about the
# analysis history. The same value often lives in two or three places by
# design. Knowing the map prevents three classes of bug:
#   1. Reading from the wrong copy after one is updated.
#   2. Failing to find data that exists under a slot you did not know.
#   3. Trusting downstream results when an upstream slot was overwritten.

# A.1 - Top-level slots: print every slot name and a 1-line description of each.
cat("\n== TOP-LEVEL SLOTS ==\n")
top_slots <- slotNames(sobj)
for (s in top_slots) cat(sprintf("  @%-15s class: %s\n", s, class(slot(sobj, s))[1]))

# A.2 - @assays: list of assays. Each assay is an Assay5 (v5) or Assay (v4).
cat("\n== @assays ==\n")
cat("  Assay names              :", paste(names(sobj@assays), collapse = ", "), "\n")
cat("  Active assay             :", DefaultAssay(sobj), "\n")
cat("  Number of assays         :", length(sobj@assays), "\n")

# Inside one assay (v5 Assay5), the slot map is different from v4
cat("\n  [inside sobj[['RNA']] (v5 Assay5)]\n")
rna_assay_slots <- slotNames(sobj[["RNA"]])
for (s in rna_assay_slots) {
  val <- slot(sobj[["RNA"]], s)
  cat(sprintf("    @%-15s class: %-15s length/dim: %s\n",
              s, class(val)[1],
              if (is.list(val))    paste0("list of ", length(val))
              else if (is.null(dim(val))) paste0("len ", length(val))
              else paste(dim(val), collapse = " x ")))
}

# A.3 - @meta.data: cell-level metadata data.frame.
# Rows = cells. Columns = whatever was added during preprocessing.
cat("\n== @meta.data (cell-level) ==\n")
cat("  Dimensions       :", dim(sobj@meta.data)[1], "cells x",
                            dim(sobj@meta.data)[2], "columns\n")
cat("  Column names     :\n")
print(colnames(sobj@meta.data))

# A.4 - @active.ident: a FACTOR over cells. The current "identity" used by
# downstream Seurat functions (FindMarkers, DimPlot group.by = NULL default).
# It is independent of the metadata columns and is set by SetIdent / Idents().
cat("\n== @active.ident ==\n")
cat("  Class            :", class(sobj@active.ident), "\n")
cat("  Levels currently :", paste(head(levels(sobj@active.ident), 5), collapse = ", "),
                             ifelse(length(levels(sobj@active.ident)) > 5, " ...", ""), "\n")
cat("  First 5 cells    :\n")
print(head(sobj@active.ident, 5))

# A.5 - @reductions: list of DimReduc objects (pca, umap, harmony, etc.).
# Each one has its OWN slots: cell.embeddings (cells x dims), feature.loadings
# (features x dims), stdev (per-dim variance), key (column prefix), assay.used.
cat("\n== @reductions ==\n")
cat("  Reductions present:", paste(names(sobj@reductions), collapse = ", "), "\n")
if (length(sobj@reductions) > 0) {
  for (red_name in names(sobj@reductions)) {
    red <- sobj@reductions[[red_name]]
    cat(sprintf("  [%s]\n", red_name))
    cat(sprintf("    cell.embeddings : %s\n", paste(dim(red@cell.embeddings), collapse = " x ")))
    cat(sprintf("    feature.loadings: %s\n", paste(dim(red@feature.loadings), collapse = " x ")))
    cat(sprintf("    stdev length    : %d\n", length(red@stdev)))
    cat(sprintf("    key             : %s\n", red@key))
    cat(sprintf("    assay.used      : %s\n", red@assay.used))
  }
} else {
  cat("  (none yet; PCA/UMAP happen in Block 4)\n")
}

# A.6 - @graphs and @neighbors: caches filled by FindNeighbors. Empty here.
cat("\n== @graphs and @neighbors ==\n")
cat("  Graphs    :", ifelse(length(sobj@graphs)    == 0, "empty (filled by FindNeighbors)",
                            paste(names(sobj@graphs), collapse = ", ")), "\n")
cat("  Neighbors :", ifelse(length(sobj@neighbors) == 0, "empty (filled by FindNeighbors)",
                            paste(names(sobj@neighbors), collapse = ", ")), "\n")

# A.7 - @commands: every Seurat function call ever made on this object, with
# all arguments, providing a full analysis history. If you ever wonder "what
# arguments did the previous user pass to NormalizeData?", check here.
cat("\n== @commands (analysis history) ==\n")
cat("  Commands recorded:", length(sobj@commands), "\n")
if (length(sobj@commands) > 0) {
  cat("  First 5 command names:\n")
  print(head(names(sobj@commands), 5))
  # Inspect one command in detail
  first_cmd <- sobj@commands[[1]]
  cat(sprintf("\n  [detail of first command: %s]\n", names(sobj@commands)[1]))
  cat("    call.string   :", first_cmd@call.string[1], "\n")
  cat("    time.stamp    :", as.character(first_cmd@time.stamp), "\n")
  cat("    assay.used    :", first_cmd@assay.used, "\n")
  cat("    params (names):", paste(names(first_cmd@params), collapse = ", "), "\n")
}

# A.8 - @misc, @tools, @project.name, @version: small administrative slots.
cat("\n== Administrative slots ==\n")
cat("  @project.name :", sobj@project.name, "\n")
cat("  @version      :", as.character(sobj@version), "\n")
cat("  @misc names   :", ifelse(length(sobj@misc) == 0, "empty",
                                paste(names(sobj@misc), collapse = ", ")), "\n")
cat("  @tools names  :", ifelse(length(sobj@tools) == 0, "empty",
                                paste(names(sobj@tools), collapse = ", ")), "\n")

# A.9 - Same data, different paths: a common source of confusion. The values
# below are IDENTICAL, but accessed through different slots/accessors.
cat("\n== Same data, different paths (sanity proofs) ==\n")
cat("Test 1: assay access\n")
cat("  identical(sobj@assays$RNA, sobj[['RNA']])           :",
    identical(sobj@assays$RNA, sobj[["RNA"]]), "\n")

cat("Test 2: metadata column access (4 equivalent paths)\n")
v1 <- sobj$nFeature_RNA
v2 <- sobj@meta.data$nFeature_RNA
v3 <- sobj[[]]$nFeature_RNA
v4 <- FetchData(sobj, vars = "nFeature_RNA")[, 1]
# identical() is sensitive to attributes (names, integer vs numeric storage)
# that differ across these four accessors even when every value is the same.
# Strip names and coerce type before comparing, since the point here is
# value equality, not attribute equality.
all_match <- all(unname(as.numeric(v1)) == unname(as.numeric(v2))) &&
             all(unname(as.numeric(v2)) == unname(as.numeric(v3))) &&
             all(unname(as.numeric(v3)) == unname(as.numeric(v4)))
cat("  all four return the same values                     :", all_match, "\n")
cat("  (identical() can still report FALSE here; that compares attributes\n")
cat("   like names or integer-vs-numeric storage, not the values themselves)\n")

cat("Test 3: cell name access (3 equivalent paths)\n")
cat("  identical(Cells(sobj), colnames(sobj))              :",
    identical(Cells(sobj), colnames(sobj)), "\n")
cat("  identical(Cells(sobj), rownames(sobj@meta.data))    :",
    identical(Cells(sobj), rownames(sobj@meta.data)), "\n")

cat("Test 4: feature name access (varies with default assay)\n")
cat("  rownames(sobj) returns features of the ACTIVE assay only\n")
cat("  default assay is", DefaultAssay(sobj), "\n")
cat("  identical(rownames(sobj), Features(sobj))           :",
    identical(rownames(sobj), Features(sobj)), "\n")
cat("  identical(rownames(sobj), rownames(sobj[['RNA']])) :",
    identical(rownames(sobj), rownames(sobj[["RNA"]])), "\n")
cat("  identical(rownames(sobj), rownames(sobj[['ADT']])) :",
    identical(rownames(sobj), rownames(sobj[["ADT"]])), "\n")
cat("  >> rownames depends on DefaultAssay. Always pass assay= explicitly.\n")

# A.10 - SLOT PUZZLES: where would you look to find each item below?
# Try to write the answer in your head before running.
cat("\n== SLOT PUZZLES (try before running) ==\n")

# PUZZLE 1.2b/1: Where is the original Seurat version that created this object?
cat("\nPUZZLE 1: original Seurat version that created this object?\n")
cat("  Answer: sobj@version (top-level slot)\n")
cat("  Value :", as.character(sobj@version), "\n")

# QUESTION 1.2b: For each of the 4 sanity-proof tests above (A.9), which one
# is GUARANTEED to be identical regardless of analysis state, and which one
# DEPENDS on DefaultAssay? Why is the distinction important when sharing code?

# -----------------------------------------------------------------------------
# Step 1.3 | Inspecting the RNA assay (intermediate)
# -----------------------------------------------------------------------------

# Three properties of a single-cell RNA count matrix that drive every later
# decision: sparsity, memory footprint, and layer state. Inspect them now,
# before any normalization or scaling. The ADT counterpart to this step
# opens Block 6, once the CITE-seq workflow actually needs it.

# Sparsity = fraction of zero entries. Drives normalization decisions.

counts_mat <- LayerData(sobj, assay = "RNA", layer = "counts")
total_entries  <- prod(dim(counts_mat))
nonzero        <- Matrix::nnzero(counts_mat)
sparsity       <- 1 - nonzero / total_entries

cat("RNA count matrix:\n")
cat("  Genes   :", nrow(counts_mat), "\n")
cat("  Cells   :", ncol(counts_mat), "\n")
cat("  Total entries  :", format(total_entries, big.mark = ","), "\n")
cat("  Non-zero entries:", format(nonzero, big.mark = ","), "\n")
cat("  Sparsity        :", round(sparsity * 100, 1), "%\n\n")

# QUESTION 1.3a: A typical full-transcriptome PBMC dataset shows RNA sparsity
# above 90%. This 500+9-gene panel is lower. What does the sparsity value you
# just printed tell you about gene panel size versus dropout rate?

# Dense vs sparse storage matters at scale. A full 10x experiment with
# 50,000 cells and 33,000 genes as a dense matrix exceeds 50 GB.

# Compare sparse (counts) vs dense (after scaling) memory
counts_rna_sz <- object.size(LayerData(sobj, assay = "RNA", layer = "counts"))
cat("RNA counts layer (sparse):", format(counts_rna_sz, units = "Mb"), "\n")

# The full object
obj_size <- object.size(sobj)
cat("Full Seurat object       :", format(obj_size, units = "Mb"), "\n\n")

cat("\nscale.data is a DENSE genes-by-cells matrix.\n")
cat("On full datasets, scale only the genes used in PCA to keep memory bounded.\n")

# QUESTION 1.3b: The counts layer is sparse, the scale.data layer is dense.
# Project this to a 50,000-cell, 33,000-gene experiment: what is the memory
# implication, and what does it tell you about how to use ScaleData?

# -----------------------------------------------------------------------------
# Step 1.6 | Metadata
# -----------------------------------------------------------------------------

# Reductions (PCA, UMAP, Harmony, etc.) are computed in Block 4 onward. At
# this point in the script, none exist yet. Confirm that explicitly instead
# of assuming it: it is the same habit as checking DefaultAssay() before
# trusting any accessor. The access patterns for cell.embeddings and
# feature.loadings are covered in Step 4.4, once PCA actually exists.

cat("Reductions in the object:\n")
print(SafeReductions(sobj))
cat("(empty; PCA happens in Block 4.)\n\n")

cat("Metadata columns and types:\n")
str(sobj@meta.data)
# -----------------------------------------------------------------------------

# Real analysis constantly requires subsetting or querying cells by
# combinations of metadata. Practice the patterns here.

# How many cells per donor?
cat("Cells per donor:\n")
print(table(sobj$donor_id))

# How many cells per condition?
cat("\nCells per condition:\n")
print(table(sobj$condition))

# Cells from COVID-19 donors with more than 40 genes detected. The threshold
# is calibrated to this panel: nFeature_RNA sits in the 27-96 range here, not
# the 200+ range typical of a full transcriptome, so a number borrowed from
# a full-transcriptome tutorial would silently match zero cells.
covid_highgene <- sobj@meta.data %>%
  filter(condition == "COVID19", nFeature_RNA > 40)
cat("\nCOVID-19 cells with nFeature_RNA > 40:", nrow(covid_highgene), "\n")

# Cross-tabulation: condition x severity
cat("\nCondition x Severity:\n")
print(table(sobj$condition, sobj$severity))

# Same idea, different variable: severity by donor. The tabulation reveals
# the donor-condition design (which donors are Healthy vs which severity
# level each COVID-19 donor was assigned).
cat("\nSeverity by donor:\n")
print(table(sobj$severity, sobj$donor_id, useNA = "ifany"))

# -----------------------------------------------------------------------------
# Step 1.7 | ADT feature naming
# -----------------------------------------------------------------------------

# ADT feature names often differ from RNA gene names.
# CD3 protein != CD3E gene. CD8a protein != CD8A gene.
# This mismatch is a frequent source of confusion.

cat("ADT protein names:\n")
print(rownames(sobj[["ADT"]]))

cat("\nRNA marker names for comparison:\n")
rna_markers <- c("CD3E", "CD4", "CD8A", "CD14", "CD19", "NCAM1")
cat(rna_markers, "\n")

cat("\nImportant: 'CD8a' in ADT vs 'CD8A' in RNA.\n")
cat("FetchData() handles this transparently, but FeaturePlot()\n")
cat("requires you to be on the correct DefaultAssay first.\n")

# Demonstrate: what happens when you try to access an ADT feature
# using the RNA gene name
cat("\nDoes 'CD8A' exist in ADT?\n")
cat("'CD8A' in ADT rownames:", "CD8A" %in% rownames(sobj[["ADT"]]), "\n")
cat("'CD8a' in ADT rownames:", "CD8a" %in% rownames(sobj[["ADT"]]), "\n")

# -----------------------------------------------------------------------------
# Step 1.8 | Marker stored under an alias
# -----------------------------------------------------------------------------

# Gene symbols have synonyms: NCAM1 = CD56, FCGR3A = CD16, MS4A1 = CD20.
# If an object stores a gene under its alias, FeaturePlot("FCGR3A") returns
# "feature not found" and the marker reads as absent when the data are intact.
# Confirm canonical markers exist under their expected symbol before plotting
# or annotating.

canonical <- c("CD3E", "CD4", "CD8A", "CD14", "CD19", "MS4A1", "NCAM1", "FCGR3A")
present   <- canonical %in% rownames(sobj[["RNA"]])

cat("Canonical RNA markers present under expected symbol:\n")
for (i in seq_along(canonical))
  cat(sprintf("  %-8s %s\n", canonical[i], ifelse(present[i], "OK", "MISSING")))

# If something is MISSING, search for known aliases in the rownames
aliases <- list(FCGR3A = "CD16", NCAM1 = "CD56", MS4A1 = "CD20")
missing <- canonical[!present]
if (length(missing) > 0) {
  cat("\nMISSING markers detected. Searching for aliases:\n")
  rna_counts <- LayerData(sobj, assay = "RNA", layer = "counts")
  rn <- rownames(rna_counts)
  changed <- FALSE
  for (m in missing) {
    al <- aliases[[m]]
    if (!is.null(al) && al %in% rn) {
      cat(sprintf("  %s is stored as alias '%s'. Renaming back.\n", m, al))
      rn[rn == al] <- m
      changed <- TRUE
    }
  }
  if (changed) {
    # v5-safe rename: rebuild the RNA assay from counts with corrected names.
    # Run before normalization (Block 4), so only the counts layer exists,
    # matching the structure of the assay it replaces. suppressWarnings()
    # wraps the assignment itself, since any "different features" notice
    # would come from the [[<- replacement method, not from
    # CreateAssay5Object().
    rownames(rna_counts) <- rn
    new_rna_assay <- CreateAssay5Object(counts = rna_counts)
    suppressWarnings(sobj[["RNA"]] <- new_rna_assay)
    DefaultAssay(sobj) <- "RNA"
  }
  cat("\nAfter fix, all canonical markers present:",
      all(canonical %in% rownames(sobj[["RNA"]])), "\n")
}

# QUESTION 1.8: What other RNA aliases would you check for routinely in a
# PBMC dataset?

# =============================================================================
# BLOCK 2  |  Quality control metrics (RNA)
# =============================================================================

# Goal: compute QC metrics, look at their distributions across donors, and
# filter cells using thresholds chosen from the data, not from a tutorial.

# -----------------------------------------------------------------------------
# Step 2.1 | Compute QC metrics
# -----------------------------------------------------------------------------

# Mitochondrial fraction (percent.mt) is a death/stress indicator. Ribosomal
# fraction (percent.ribo) flags cells dominated by housekeeping transcripts.

sobj[["percent.mt"]]   <- PercentageFeatureSet(sobj, pattern = "^MT-")
sobj[["percent.ribo"]] <- PercentageFeatureSet(sobj, pattern = "^RP[SL]")

summary(sobj@meta.data[, c("nFeature_RNA", "nCount_RNA", "percent.mt")])

# -----------------------------------------------------------------------------
# Step 2.2 | Sanity check: did percent.mt actually compute?
# -----------------------------------------------------------------------------

# percent.mt depends entirely on the '^MT-' pattern matching real gene names.
# This is worth confirming explicitly rather than assuming it worked: a
# renamed or missing MT- prefix (which is exactly what the injected object
# simulates) returns percent.mt = 0 for every cell, and any filter based on
# it then either does nothing or rejects every cell.

mt_genes <- grep("^MT-", rownames(sobj), value = TRUE)
cat("Genes matching '^MT-':", length(mt_genes), "\n")
if (length(mt_genes) > 0) print(mt_genes)

cat("\nAre rownames symbols or Ensembl IDs? First 5 rownames:\n")
print(head(rownames(sobj), 5))

cat("\nmax(percent.mt):", round(max(sobj$percent.mt), 4), "\n")
if (max(sobj$percent.mt) == 0) {
  cat("\nWARNING: percent.mt is 0 for all cells. The '^MT-' pattern matched\n")
  cat("no genes. Do NOT filter on percent.mt here: it is uninformative in\n")
  cat("this panel. Report this limitation; do not claim an mt-based QC.\n")
} else {
  cat("MT- pattern matched", length(mt_genes), "genes. percent.mt is usable.\n")
}

# QUESTION 2.2: If max(percent.mt) is 0 across every cell, what are the two
# possible explanations, and how do you tell them apart?

# -----------------------------------------------------------------------------
# Step 2.3 | Visualize QC distributions
# -----------------------------------------------------------------------------

VlnPlot(sobj,
        features = c("nFeature_RNA", "nCount_RNA", "percent.mt"),
        ncol = 3, pt.size = 0.05, alpha = 0.3)

p1 <- FeatureScatter(sobj, "nCount_RNA", "nFeature_RNA") +
  ggtitle("Counts vs genes detected") +
  theme(plot.title = element_text(size = 10))
p2 <- FeatureScatter(sobj, "nCount_RNA", "percent.mt") +
  ggtitle("Counts vs mitochondrial %") +
  theme(plot.title = element_text(size = 10))
p1 | p2

# -----------------------------------------------------------------------------
# Step 2.4 | Outlier detection
# -----------------------------------------------------------------------------

# Cells that are high in nFeature relative to nCount might be doublets.
# Low nCount with low nFeature = empty droplet.
# High percent.mt alone = stressed/dying cell.

# Cells that are potential outliers: nFeature > 2 SD above mean
mean_feat <- mean(sobj$nFeature_RNA)
sd_feat   <- sd(sobj$nFeature_RNA)
high_feat <- sum(sobj$nFeature_RNA > mean_feat + 2 * sd_feat)
cat("Cells with nFeature > mean + 2 SD (potential doublets):",
    high_feat, "\n")

# Cells with high mt: > 95th percentile
mt_95 <- quantile(sobj$percent.mt, 0.95)
high_mt <- sum(sobj$percent.mt > mt_95)
cat("Cells with percent.mt > 95th percentile:", high_mt, "\n")

# The two counts above are easy to compute and easy to misread: a count by
# itself does not show whether the flagged cells form a clear, separable
# group, or whether the threshold cut through the middle of a continuous
# distribution. Flag both categories on the metadata and plot them directly
# against the same axes used in Step 2.3, so the outliers are visible as
# points, not just as a number.

sobj$outlier_flag <- "normal"
sobj$outlier_flag[sobj$nFeature_RNA > mean_feat + 2 * sd_feat] <- "high nFeature (possible doublet)"
sobj$outlier_flag[sobj$percent.mt > mt_95]                     <- "high percent.mt (stressed/dying)"
sobj$outlier_flag <- factor(sobj$outlier_flag,
                            levels = c("normal", "high nFeature (possible doublet)",
                                       "high percent.mt (stressed/dying)"))

p_out1 <- FeatureScatter(sobj, "nCount_RNA", "nFeature_RNA", group.by = "outlier_flag") +
  ggtitle("Outlier flags on counts vs genes detected") +
  theme(legend.position = "bottom", legend.text = element_text(size = 7))

p_out2 <- FeatureScatter(sobj, "nCount_RNA", "percent.mt", group.by = "outlier_flag") +
  ggtitle("Outlier flags on counts vs mitochondrial %") +
  theme(legend.position = "bottom", legend.text = element_text(size = 7))

p_out1 | p_out2

# QUESTION 2.4: Looking at the two plots, do the high-nFeature cells and the
# high-percent.mt cells occupy distinct regions, or do some cells qualify as
# both? What would a cell flagged on both axes most likely be?

# Distribution per condition: is mt% elevated in COVID-19?
cat("\nMedian percent.mt by condition:\n")
sobj@meta.data %>%
  group_by(condition) %>%
  summarise(median_mt = round(median(percent.mt), 2),
            mean_mt   = round(mean(percent.mt),   2),
            .groups   = "drop") %>%
  print()

# -----------------------------------------------------------------------------
# Step 2.5 | Wrong filter: tutorial thresholds applied blindly
# -----------------------------------------------------------------------------

# Standard tutorial thresholds (nFeature > 200 & < 6000, percent.mt < 5%) are
# inherited from full 10x experiments with ~33,000 genes. This dataset is a
# 500-gene subset for teaching purposes. Applying the tutorial cutoffs deletes
# every cell.

# >>> DELIBERATE ERROR - read the message, then continue. <<<
try({
  sobj_filt <- subset(
    sobj,
    subset = nFeature_RNA > 200 &
             nFeature_RNA < 5000 &
             percent.mt   < 20
  )
})

# "No cells found" is the canonical result of copying thresholds from
# a tutorial without checking your own data distribution. The threshold
# `nFeature_RNA > 200` was calibrated for a transcriptome of ~33,000 genes
# where cells typically detect 2,000-3,000 genes. In a 500-gene panel, most
# cells detect 50-150 genes. The filter removes every single cell.

# QUESTION 2.5: Which of the three filter parameters above is the most wrong
# for this 500-gene dataset, and what value would you try first? Run
# quantile(sobj$nFeature_RNA, c(0.05, 0.95)) to see the actual range before
# proposing a number.

# A reasonable first guess for this panel: nFeature_RNA > 50. Try it and see
# how many cells survive, before moving to the fully data-driven thresholds
# in Step 2.6 and 2.7.
n_above_50 <- sum(sobj$nFeature_RNA > 50)
cat("Cells with nFeature_RNA > 50:", n_above_50,
    sprintf("(%.1f%% of total)\n", 100 * n_above_50 / ncol(sobj)))

# -----------------------------------------------------------------------------
# Step 2.6 | Compare tutorial vs data-driven thresholds
# -----------------------------------------------------------------------------

cat("--- Published thresholds (full 10x, 33k genes) ---\n")
cat("  nFeature_RNA > 200   removes empty droplets\n")
cat("  nFeature_RNA < 5000  removes likely doublets\n")
cat("  percent.mt   < 20%   removes dead/stressed cells\n\n")

cat("--- This dataset (500 genes) ---\n")
print(round(quantile(sobj$nFeature_RNA,
      probs = c(0.01, 0.05, 0.25, 0.5, 0.75, 0.95, 0.99))))

cat("\n--- Data-driven thresholds ---\n")
min_features <- max(10, round(quantile(sobj$nFeature_RNA, 0.02)))
max_features <-          round(quantile(sobj$nFeature_RNA, 0.98))
max_mt       <-          round(quantile(sobj$percent.mt,   0.95), 1)

cat("  nFeature_RNA > ", min_features, "  (same intent: empty droplets)\n")
cat("  nFeature_RNA < ", max_features, " (same intent: doublets)\n")
cat("  percent.mt   < ", max_mt, "%  (same intent: dead cells)\n")

# -----------------------------------------------------------------------------
# Step 2.7 | Apply data-driven thresholds
# -----------------------------------------------------------------------------

cat("Cells before filtering:", ncol(sobj), "\n")

sobj_filt <- tryCatch(
  subset(
    sobj,
    subset = nFeature_RNA > min_features &
             nFeature_RNA < max_features &
             percent.mt   < max_mt
  ),
  error = function(e) {
    cat("\nsubset() failed:", conditionMessage(e), "\n")
    cat("This means the three thresholds together match zero cells.\n")
    cat("Check each threshold individually before combining them:\n")
    cat("  > min_features:", sum(sobj$nFeature_RNA > min_features), "cells\n")
    cat("  < max_features:", sum(sobj$nFeature_RNA < max_features), "cells\n")
    cat("  < max_mt      :", sum(sobj$percent.mt   < max_mt),       "cells\n")
    stop(e)
  }
)

cat("Cells after filtering :", ncol(sobj_filt), "\n")
cat("Cells removed         :", ncol(sobj) - ncol(sobj_filt), "\n")
cat("Retention rate        :",
    round(ncol(sobj_filt) / ncol(sobj) * 100, 1), "%\n")

if (ncol(sobj_filt) < 500) {
  cat("\nWARNING: fewer than 500 cells remaining.\n")
  cat("Options: relax max_mt or lower min_features,\n")
  cat("or request pre-filtered matrices from GEO.\n")
} else {
  cat("\nCell count adequate for downstream analysis.\n")
}

# QUESTION 2.7: How would your thresholds change if the dataset had ~33,000
# genes instead of 500?

# -----------------------------------------------------------------------------
# Step 2.8 | Silent failure: percent.mt as fraction vs as percentage
# -----------------------------------------------------------------------------

# A common silent failure: someone copied a threshold from a tutorial that
# used percent.mt expressed as a FRACTION (0 to 1), but Seurat returns
# percent.mt as a PERCENTAGE (0 to 100). The filter looks right and runs
# without error, but removes nearly every cell.

# >>> DELIBERATE ERROR - read the message, then continue. <<<
try({
  # This filter expects 5 percent (i.e. percent.mt < 5). Written as 0.05 it
  # means "less than 0.05 percent", which removes almost everything.
  sobj_fraction <- subset(sobj, subset = percent.mt < 0.05)
  cat("Cells passing 'percent.mt < 0.05' filter :", ncol(sobj_fraction), "\n")
})

cat("Compare to the correct threshold (percent.mt < 5):\n")
sobj_pct <- subset(sobj, subset = percent.mt < 5)
cat("Cells passing 'percent.mt < 5' filter    :", ncol(sobj_pct), "\n")

# QUESTION 2.8: Is your dataset's percent.mt distribution closer to a fraction
# or a percentage? Run summary(sobj$percent.mt) to confirm and remember this
# trap when reading code from other groups.

# -----------------------------------------------------------------------------
# Step 2.9 | Spot the bug
# -----------------------------------------------------------------------------

# Read the code below CAREFULLY before running it. What is wrong with it?
# Write your answer as a comment on the next line.
#
#   covid_cells <- subset(sobj_filt, subset = condition == "COVID")
#
# Your answer:
#
# REVEAL: the condition value in this dataset is "COVID19", not "COVID".
# subset() returns zero cells without any error. Always inspect the unique
# values of a categorical column before subsetting on it.

cat("Unique values of condition in this dataset:\n")
print(unique(sobj_filt$condition))

# Habit: print unique() of a factor or character column before referencing
# any specific value in subset() or filter().

# =============================================================================
# BLOCK 3  |  Doublet detection
# =============================================================================

# Goal: identify and remove technical doublets that survive QC thresholds.
# scDblFinder simulates artificial doublets and scores each real cell against
# them. The result is a doublet class label and a numeric score per cell.

# -----------------------------------------------------------------------------
# Step 3.1 | Run scDblFinder
# -----------------------------------------------------------------------------
library(scDblFinder)

# Both packages are already loaded from Block 0; no need to library() again.
# scDblFinder calls xgboost internally; recent xgboost versions emit
# deprecation warnings unrelated to our analysis. Wrap the call to keep the
# console focused on the actual result.

set.seed(42)
sce <- SingleCellExperiment(
  assays = list(counts = LayerData(sobj_filt, assay = "RNA", layer = "counts"))
)
sce <- suppressWarnings(scDblFinder(sce))

sobj_filt$scDblFinder.class <- sce$scDblFinder.class
sobj_filt$scDblFinder.score <- sce$scDblFinder.score

cat("Doublet classification:\n")
print(table(sobj_filt$scDblFinder.class))
cat("\nDoublet rate:",
    round(mean(sobj_filt$scDblFinder.class == "doublet") * 100, 1), "%\n")

# -----------------------------------------------------------------------------
# Step 3.2 | Where do flagged doublets sit on the QC scatter?
# -----------------------------------------------------------------------------

df <- sobj_filt@meta.data
p1 <- ggplot(df, aes(nCount_RNA, nFeature_RNA, color = scDblFinder.class)) +
  geom_point(alpha = 0.5, size = 0.7) +
  scale_color_manual(values = c("singlet" = "grey70", "doublet" = "#991b1b")) +
  labs(title = "Doublets sit on the high diagonal", color = NULL) +
  theme_classic(base_size = 11)

p2 <- ggplot(df, aes(scDblFinder.class, nFeature_RNA, fill = scDblFinder.class)) +
  geom_violin(alpha = 0.7) +
  scale_fill_manual(values = c("singlet" = "grey70", "doublet" = "#991b1b")) +
  labs(title = "Genes detected per class", x = NULL) +
  theme_classic(base_size = 11) + theme(legend.position = "none")

p1 | p2

# QUESTION 3.2: Why is it expected that doublets do NOT all sit at the very
# top of nCount_RNA? What does that imply about using nCount thresholds alone
# to remove doublets?

# -----------------------------------------------------------------------------
# Step 3.3 | Remove doublets
# -----------------------------------------------------------------------------

cat("Cells before doublet removal:", ncol(sobj_filt), "\n")
sobj_filt <- subset(sobj_filt, subset = scDblFinder.class == "singlet")
cat("Cells after doublet removal :", ncol(sobj_filt), "\n")

# -----------------------------------------------------------------------------
# Step 3.4 | Re-inspect the object after QC and doublet removal
# -----------------------------------------------------------------------------

# After every step that mutates the object, confirm what you now have.
# Silent bugs surface only when the object is re-inspected, not when it is
# re-used.

cat("Object after QC + doublet removal:\n")
print(sobj_filt)
cat("\nCells lost   :", ncol(sobj) - ncol(sobj_filt), "\n")
cat("Cells kept   :", ncol(sobj_filt), "\n")
cat("Median genes :", median(sobj_filt$nFeature_RNA), "\n")
cat("Median UMIs  :", median(sobj_filt$nCount_RNA), "\n")

# Two views of the same removal: the overall distribution shift, and the
# per-donor breakdown. A filter that looks reasonable in aggregate can still
# remove one donor almost entirely; the per-donor bar chart is what catches
# that before it becomes a downstream surprise.

before_after <- bind_rows(
  data.frame(nFeature_RNA = sobj$nFeature_RNA, stage = "Before filtering"),
  data.frame(nFeature_RNA = sobj_filt$nFeature_RNA, stage = "After filtering")
)
before_after$stage <- factor(before_after$stage,
                             levels = c("Before filtering", "After filtering"))

p_before_after <- ggplot(before_after, aes(x = nFeature_RNA, fill = stage)) +
  geom_histogram(bins = 40, alpha = 0.7, position = "identity") +
  labs(title = "nFeature_RNA distribution before vs after filtering",
       x = "nFeature_RNA", y = "Cell count", fill = NULL) +
  theme_classic(base_size = 11)

cell_counts <- data.frame(
  donor_id  = c(sobj$donor_id, sobj_filt$donor_id),
  condition = c(sobj$condition, sobj_filt$condition),
  stage     = rep(c("Before", "After"), c(ncol(sobj), ncol(sobj_filt)))
) %>%
  count(donor_id, condition, stage) %>%
  mutate(stage = factor(stage, levels = c("Before", "After")))

p_donor_counts <- ggplot(cell_counts, aes(x = donor_id, y = n, fill = stage)) +
  geom_bar(stat = "identity", position = "dodge") +
  facet_wrap(~condition, scales = "free_x") +
  labs(title = "Cell count per donor, before vs after QC and doublet removal",
       x = NULL, y = "Cells", fill = NULL) +
  theme_classic(base_size = 11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

p_before_after
p_donor_counts

# QUESTION 3.4: Look at the per-donor bar chart. Did any single donor lose a
# much larger fraction of cells than the others? If so, is that donor-level
# QC variation, or a sign the filter thresholds were tuned around the
# majority of donors at the expense of one outlier?

# =============================================================================
# BLOCK 4  |  Normalization, dimensionality reduction, clustering (RNA)
# =============================================================================

# Goal: take the RNA assay from raw counts to a clustered UMAP. ADT
# normalization is intentionally NOT done here; it belongs to Block 6 where
# the CITE-seq workflow starts. Keep the modalities separate until WNN.

# -----------------------------------------------------------------------------
# Step 4.1 | Confirm the counts layer holds raw integer counts
# -----------------------------------------------------------------------------

# A common silent failure: an object arrives with the data layer copied into
# the counts layer (already log-normalized). NormalizeData then runs on
# already-normalized values. The fix has to happen here, before any
# normalization call.

raw <- LayerData(sobj_filt, assay = "RNA", layer = "counts")
vals <- raw@x  # non-zero values
cat("Min non-zero count :", round(min(vals), 4), "\n")
cat("Max count          :", round(max(vals), 2), "\n")
cat("All integers?      :", all(vals == round(vals)), "\n")
if (!all(vals == round(vals))) {
  cat("\nWARNING: counts layer contains non-integer values.\n")
  cat("This is not raw counts. Do NOT run NormalizeData on it.\n")
  cat("Obtain the original count matrix before continuing.\n")
} else {
  cat("\nCounts layer looks like raw counts. Safe to normalize.\n")
}

# >>> DELIBERATE ERROR - read the message, then continue. <<<
# What does this check look like on a CORRUPTED counts layer?
# Simulate: a well-meaning collaborator copied the data layer back into counts
# "for consistency". Run the integrity check on that simulated layer and
# compare with the real one above.
try({
  # Build a fake assay where counts holds log-normalized values
  fake_data   <- LayerData(sobj_filt, assay = "RNA", layer = "counts")
  fake_data@x <- log1p(fake_data@x / 1e4)  # roughly what LogNormalize produces
  fake_assay  <- CreateAssay5Object(counts = fake_data)
  fake_vals   <- LayerData(fake_assay, layer = "counts")@x

  cat("\n--- Integrity check on a CORRUPTED counts layer ---\n")
  cat("Min non-zero :", round(min(fake_vals), 4), "\n")
  cat("Max          :", round(max(fake_vals), 4), "\n")
  cat("All integers?:", all(fake_vals == round(fake_vals)), "\n")
  cat("This is what a contaminated counts layer looks like.\n")
  cat("If you see this on a real object, STOP and ask for the raw matrix.\n")
})

# QUESTION 4.1: If integrity check fails on a real inherited object, what
# do you ask the collaborator for? What is the absolute minimum you need
# to restart the analysis from a clean state?

# -----------------------------------------------------------------------------
# Step 4.2 | RNA normalization: LogNormalize
# -----------------------------------------------------------------------------

sobj_filt <- NormalizeData(
  sobj_filt,
  normalization.method = "LogNormalize",
  scale.factor         = 10000
)
cat("RNA normalized. Layer 'data' now populated.\n")
cat("Layers present:", paste(SafeLayers(sobj_filt[["RNA"]]), collapse = ", "), "\n")

# Verify: log-normalized values should be non-negative
data_layer <- LayerData(sobj_filt, assay = "RNA", layer = "data")
cat("Any negative values in RNA data layer:", any(data_layer < 0), "\n")
cat("Max value in RNA data layer          :",
    round(max(data_layer@x), 2), "\n")

# QUESTION 4.2: Why is LogNormalize applied to RNA but CLR (margin = 2) used
# for ADT? What property of each modality drives the difference?

# -----------------------------------------------------------------------------
# Step 4.3 | Highly variable genes
# -----------------------------------------------------------------------------

sobj_filt <- FindVariableFeatures(
  sobj_filt,
  selection.method = "vst",
  nfeatures        = 2000
)

top10 <- head(VariableFeatures(sobj_filt), 10)
cat("Top 10 most variable genes:\n")
print(top10)
cat("\nTotal variable features selected:", length(VariableFeatures(sobj_filt)), "\n")

# Challenge: what fraction of all genes are selected as variable?
all_genes <- nrow(sobj_filt[["RNA"]])
n_var     <- length(VariableFeatures(sobj_filt))
cat("Variable fraction:", round(n_var / all_genes * 100, 1), "% of all genes\n")

# -----------------------------------------------------------------------------
# Step 4.4 | Scale and run PCA
# -----------------------------------------------------------------------------

# vars.to.regress removes the linear effect of percent.mt from each gene
# before scaling. This reduces the influence of cell stress/quality on
# the principal components.
sobj_filt <- ScaleData(
  sobj_filt,
  vars.to.regress = "percent.mt",
  verbose         = FALSE
)

sobj_filt <- RunPCA(sobj_filt, npcs = 30, verbose = FALSE)

# Where do the PC coordinates live, now that PCA actually exists? Step 1.6
# confirmed reductions were empty before this point; here are the three
# access patterns in practice.
cat("Reductions now available:", paste(SafeReductions(sobj_filt), collapse = ", "), "\n\n")

cat("Cell embeddings (cells x dims matrix), first 6 cells:\n")
print(head(sobj_filt@reductions$pca@cell.embeddings))

cat("\nSame thing via the recommended accessor:\n")
print(head(Embeddings(sobj_filt, reduction = "pca")))

cat("\nFeature loadings (genes x dims matrix), first 6 genes:\n")
print(head(sobj_filt@reductions$pca@feature.loadings))

# Inspect the top loadings of PC1 and PC2
cat("\nTop genes loading on PC1:\n")
print(head(sobj_filt@reductions$pca@feature.loadings[
  order(abs(sobj_filt@reductions$pca@feature.loadings[,1]),
        decreasing = TRUE), 1], 10))

# QUESTION 4.4c: You inherit an object where Reductions(sobj) lists "pca"
# and "umap" but Layers(sobj[["RNA"]]) shows only "counts". The data layer
# is missing. Can you trust the UMAP? What is your next move?

# The elbow is where adding more PCs explains little additional variance.
# Use this to set dims in FindNeighbors and RunUMAP.
ElbowPlot(sobj_filt, ndims = 30) +
  geom_vline(xintercept = 20, linetype = "dashed", color = "#991b1b") +
  annotate("text", x = 21, y = 2.5, label = "~20 PCs", hjust = 0,
           color = "#991b1b") +
  ggtitle("Elbow Plot: variance explained per PC")

# QUESTION 4.4: How would you choose the number of PCs in a real dataset
# where the elbow plot does not have a sharp knee?

# -----------------------------------------------------------------------------
# Step 4.4a | Sanity check: did HVG and PCA do what you asked?
# -----------------------------------------------------------------------------

# Silent failure A. FindVariableFeatures(nfeatures = 2000) on a 500-gene panel
# returns 500 without any warning. The HVG analysis was a no-op.
n_features  <- nrow(sobj_filt[["RNA"]])
n_hvg_asked <- 2000
n_hvg_got   <- length(VariableFeatures(sobj_filt))
cat("Features in assay  :", n_features, "\n")
cat("HVG requested      :", n_hvg_asked, "\n")
cat("HVG returned       :", n_hvg_got, "\n")
if (n_hvg_got < n_hvg_asked) {
  cat(">> nfeatures > total features. HVG is the full panel; the call",
      "selected nothing.\n")
}

# Silent failure B. RunPCA returns the number of PCs you ask for, even when
# only a fraction carry signal. Inspect tail variance to spot dead PCs.
pca_sdev <- sobj_filt@reductions$pca@stdev
pca_var  <- pca_sdev ^ 2
cat("\nVariance explained by last 5 PCs (out of", length(pca_var), "):\n")
print(round(tail(pca_var / sum(pca_var) * 100, 5), 3))
cat("If the tail is below ~0.5 percent each, those PCs are mostly noise.\n")

# QUESTION 4.4a: how many PCs carry more than 1 percent of total variance?
# The line below computes it; use the result as a lower bound for dims= later.
n_pcs_above_1pct <- sum((pca_var / sum(pca_var)) > 0.01)
cat("\nNumber of PCs with > 1% variance explained:", n_pcs_above_1pct, "\n")
cat("Recommended lower bound for dims=: 1:", n_pcs_above_1pct, sep = "", "\n")
cat("(The elbow plot above gave ~20; this floor confirms or contradicts it.)\n")

# -----------------------------------------------------------------------------
# Step 4.4b | Decide whether to integrate (Harmony)
# -----------------------------------------------------------------------------

# Before clustering, ask: do donors separate on the PCA? If yes, the UMAP
# will be donor-dominated, not biology-dominated, and clustering will
# encode batch.

p_pca_donor <- DimPlot(sobj_filt, reduction = "pca", group.by = "donor_id") +
  ggtitle("PCA by donor")
p_pca_cond  <- DimPlot(sobj_filt, reduction = "pca", group.by = "condition") +
  ggtitle("PCA by condition")
p_pca_donor | p_pca_cond

# Quick R^2 diagnostic: how much of PC1 and PC2 is explained by donor?
pc_coords <- Embeddings(sobj_filt, reduction = "pca")[, 1:2]
for (pc in 1:2) {
  fit <- summary(lm(pc_coords[, pc] ~ sobj_filt$donor_id))
  cat(sprintf("PC%d ~ donor_id R^2: %.3f\n", pc, fit$r.squared))
}

# Decision rule of thumb:
#   R^2 < 0.10 : donor effect minimal, no integration needed
#   R^2 0.10 to 0.30: borderline, consider integration if cell types are mixed across donors
#   R^2 > 0.30 : donor dominates, integration recommended
#
# In this dataset the donor effect is borderline-to-low, so clustering and
# annotation through Block 5 proceed on the plain PCA/UMAP without Harmony.
# Step 5.4e runs Harmony anyway, once cell types are annotated, to build a
# side-by-side comparison panel: seeing that Harmony barely changes the
# layout on data you already trust is what makes you confident reading the
# same comparison on a new dataset where you do not yet know the answer.
# Reference syntax (current harmony package, Seurat object method):
#
#   sobj_harm <- RunHarmony(sobj_filt, group.by.vars = "donor_id",
#                           reduction      = "pca",
#                           reduction.save = "harmony",
#                           verbose        = FALSE)
#   DimPlot(sobj_harm, reduction = "harmony", group.by = "donor_id") +
#     ggtitle("After Harmony (donor)")
#
# In downstream FindNeighbors / RunUMAP, switch reduction = "pca" to
# reduction = "harmony" (dims stays the same; Harmony returns the same
# dimensionality as the input reduction).

# QUESTION 4.4b: at what donor R^2 would you switch to Harmony in your own
# data? The block above already printed the R^2 for PC1 and PC2; apply this
# rule directly:
r2_pc1 <- summary(lm(pc_coords[, 1] ~ sobj_filt$donor_id))$r.squared
verdict <- if (r2_pc1 < 0.10) {
  "NO integration needed"
} else if (r2_pc1 < 0.30) {
  "BORDERLINE: integrate only if cell types are also separated by donor"
} else {
  "INTEGRATE (Harmony or similar)"
}
cat(sprintf("\nDecision for this dataset: R^2(PC1)= %.3f -> %s\n", r2_pc1, verdict))
cat("\nTrade-off of integration:\n")
cat("  Pro: removes technical donor variance; cell types pool across donors.\n")
cat("  Con: may remove TRUE biological inter-donor variance (e.g., one donor\n")
cat("       genuinely lacks a cell type). Always cross-check post-integration\n")
cat("       that cell type proportions per donor remain plausible.\n")

# -----------------------------------------------------------------------------
# Step 4.4c | Spot the bug
# -----------------------------------------------------------------------------

# Read the code below carefully. Two things are wrong. Find both before
# running anything.
#
#   sobj_filt <- FindNeighbors(sobj_filt, dims = 0:20, verbose = FALSE)
#   sobj_filt <- RunUMAP(sobj_filt, dims = c(1, 2, 3, 5, 7, 11, 13))
#
# Your answer:
#
# REVEAL:
#   1. dims = 0:20 includes PC 0, which does not exist. PCA indexing starts
#      at 1. FindNeighbors will silently drop the 0 or error depending on the
#      Seurat version. Always use 1:N.
#   2. dims passed as a non-contiguous vector skips intermediate PCs. UMAP
#      will run but the result represents only the 7 selected dimensions, not
#      the structure captured by the elbow. Always use a contiguous range
#      starting from 1.

# -----------------------------------------------------------------------------
# Step 4.5 | FindNeighbors: a common dimension mismatch
# -----------------------------------------------------------------------------

# RunPCA was called with npcs = 30. Passing dims = 1:50 to FindNeighbors asks
# for 50 PCs that do not exist.

# >>> DELIBERATE ERROR - read the message, then continue. <<<
try({
  # npcs=30 was used in RunPCA. What happens if we request 50 dims?
  sobj_filt <- FindNeighbors(sobj_filt, dims = 1:50, verbose = FALSE)
})

# The error occurs because the PCA object contains only 30 components.
# `dims = 1:50` requests components that do not exist.
# Common cause: `npcs` in RunPCA is changed but downstream calls are not updated.

sobj_filt <- FindNeighbors(sobj_filt, dims = 1:20, verbose = FALSE)

# -----------------------------------------------------------------------------
# Step 4.6 | Resolution sensitivity and final clustering
# -----------------------------------------------------------------------------

# How much does the clustering change between resolution 0.2 and 1.2?

res_values <- c(0.2, 0.5, 1.2)
n_clusters <- sapply(res_values, function(r) {
  tmp <- FindClusters(sobj_filt, resolution = r, verbose = FALSE)
  length(unique(tmp$seurat_clusters))
})

cat("Resolution vs number of clusters:\n")
for (i in seq_along(res_values)) {
  cat("  resolution =", res_values[i], "->", n_clusters[i], "clusters\n")
}
cat("\nUsing resolution = 0.5 for the rest of the analysis.\n")

sobj_filt <- FindClusters(sobj_filt, resolution = 0.5, verbose = FALSE)
cat("Clusters found:", length(unique(sobj_filt$seurat_clusters)), "\n")
print(table(sobj_filt$seurat_clusters))

# QUESTION 4.6: Lower resolution gives fewer, larger clusters; higher
# resolution gives more, smaller ones. Neither is intrinsically right.
# What evidence do you use to defend a chosen resolution?

# -----------------------------------------------------------------------------
# Step 4.7 | UMAP visualization
# -----------------------------------------------------------------------------

# Three questions to answer immediately after generating the UMAP:
# 1. Do cells cluster by biology or by donor? (batch effect check)
# 2. Do canonical marker genes map to expected clusters?
# 3. Does condition (Healthy vs COVID-19) show any spatial structure?
set.seed(42)
# umap.method='uwot' is the current default but Seurat prints a one-time
# notice when not stated explicitly. Setting it silences the notice.
sobj_filt <- RunUMAP(
  sobj_filt,
  dims        = 1:20,
  umap.method = "uwot",
  metric      = "cosine",
  verbose     = FALSE
)

p1 <- DimPlot(sobj_filt, group.by = "seurat_clusters",
              label = TRUE, label.size = 4) +
  NoLegend() + ggtitle("Clusters (resolution = 0.5)")

p2 <- DimPlot(sobj_filt, group.by = "orig.ident") +
  ggtitle("By donor: batch effect?") +
  theme(legend.text = element_text(size = 7))

p1 | p2

p_cond <- DimPlot(sobj_filt, group.by = "condition",
                  cols = c("Healthy" = "#0d7377", "COVID19" = "#991b1b"),
                  pt.size = 0.5) +
  ggtitle("Healthy vs COVID-19")

p_sev <- DimPlot(sobj_filt, group.by = "severity",
                 pt.size = 0.5) +
  ggtitle("COVID-19 severity") +
  theme(legend.text = element_text(size = 8))

p_cond | p_sev

# QUESTION 4.7: If donors visibly separate on the UMAP, is that batch effect
# or biology? What additional information would help you decide?

# -----------------------------------------------------------------------------
# Step 4.8 | Canonical PBMC markers (RNA)
# -----------------------------------------------------------------------------

# Match marker expression to cluster locations before formal annotation
FeaturePlot(sobj_filt,
            features   = c("CD3E", "CD19", "CD14", "NCAM1", "IL7R", "FCGR3A"),
            ncol       = 3,
            min.cutoff = "q05")

DotPlot(sobj_filt,
        features = c("CD3E", "CD4", "CD8A", "CD19", "MS4A1",
                     "CD14", "FCGR3A", "NCAM1", "PPBP"),
        group.by = "seurat_clusters") +
  RotatedAxis() +
  ggtitle("Marker expression by cluster")

# -----------------------------------------------------------------------------
# Step 4.9 | Cluster proportions across conditions
# -----------------------------------------------------------------------------

# This is a preliminary result. It must be validated after annotation.
props <- sobj_filt@meta.data %>%
  group_by(condition, seurat_clusters) %>%
  summarise(n = n(), .groups = "drop") %>%
  group_by(condition) %>%
  mutate(prop = n / sum(n))

ggplot(props, aes(x = condition, y = prop, fill = seurat_clusters)) +
  geom_bar(stat = "identity", width = 0.6) +
  scale_y_continuous(labels = percent_format()) +
  labs(title    = "Cluster proportions: Healthy vs COVID-19",
       subtitle = "Check per-donor before interpreting any group difference",
       x = "Condition", y = "Proportion", fill = "Cluster") +
  theme_classic(base_size = 12)

# =============================================================================
# BLOCK 5  |  Cell type annotation (RNA-based)
# =============================================================================

# Goal: assign cell type labels from a curated reference (SingleR with the
# Human Primary Cell Atlas), then verify the labelled object before the
# CITE-seq workflow begins. RNA-only annotation has known weaknesses for T
# cell subsets; Block 6 will revisit those with protein.

# -----------------------------------------------------------------------------
# Step 5.1 | Run SingleR against Human Primary Cell Atlas
# -----------------------------------------------------------------------------

cat("Loading reference (Human Primary Cell Atlas)...\n")
ref     <- celldex::HumanPrimaryCellAtlasData()
rna_mat <- LayerData(sobj_filt, assay = "RNA", layer = "data")

cat("Running SingleR...\n")
singler_res <- SingleR(
  test    = rna_mat,
  ref     = ref,
  labels  = ref$label.main,
  BPPARAM = BiocParallel::SerialParam()
)

cat("\nCell type distribution:\n")
print(sort(table(singler_res$labels), decreasing = TRUE))

cat("\nLow-confidence cells (NA in pruned labels):",
    sum(is.na(singler_res$pruned.labels)), "\n")

# -----------------------------------------------------------------------------
# Step 5.2 | Plotting a label before it is in the object
# -----------------------------------------------------------------------------

# Forgetting to transfer SingleR's labels into the Seurat object before
# calling DimPlot(group.by = "singler_label") produces an opaque error.
# The label only exists in the SingleR result object until you copy it over.

# >>> DELIBERATE ERROR - read the message, then continue. <<<
try({
  # singler_res is a separate object. Labels must be transferred to sobj_filt first.
  DimPlot(sobj_filt, group.by = "singler_label")
})

# `singler_label` does not exist in `sobj_filt@meta.data` yet. `singler_res`
# is a `DataFrame` (Bioconductor class). The labels must be explicitly
# added to the Seurat metadata.

sobj_filt$singler_label  <- singler_res$labels
sobj_filt$singler_pruned <- singler_res$pruned.labels

# Verify
cat("singler_label in metadata:", "singler_label" %in% colnames(sobj_filt@meta.data), "\n")
cat("Distribution:\n")
print(sort(table(sobj_filt$singler_label), decreasing = TRUE))

# Cells with similar scores across multiple types are ambiguous. Wide spread
# = high confidence. Narrow spread = low confidence. plotScoreHeatmap() draws
# one row per possible reference label: the FULL HumanPrimaryCellAtlasData
# catalog, ~37 rows, regardless of how many cells were actually assigned to
# each. Look at this before any cleanup happens. Most of those 37 rows will
# show almost no signal for any cell in this dataset; that visual clutter is
# the evidence that motivates the consolidation in the next step.
plotScoreHeatmap(singler_res,
                 main = "SingleR annotation scores: full reference (37 possible labels)")

# QUESTION 5.2: How many of the rows in this heatmap show any real signal
# (a cluster of cells with a clearly bright cell)? What does the rest of the
# rows tell you about how many of the labels printed above are likely noise?

# -----------------------------------------------------------------------------
# Step 5.2b | Consolidate to top-N labels and check distribution plausibility
# -----------------------------------------------------------------------------

# HumanPrimaryCellAtlasData covers dozens of cell types across many tissues.
# On a 500-gene PBMC panel it typically returns 20+ distinct labels, most
# supported by only a handful of cells (low-confidence noise, not real
# populations). Plotting all of them produces an unreadable legend and
# defeats the purpose of every downstream comparison.
# 
# `singler_label` (full detail) is kept untouched in the metadata for cases
# where the exact label matters. `singler_label_top` collapses every label
# outside the top N most frequent into "Other (n small labels)" and is what
# every plot from here on uses by default. The same pass that builds the
# consolidation also checks whether the underlying distribution looks like a
# real PBMC annotation, since both questions come from the same table.
# 
# What this step decides, and what it does not: this is a count-based
# decision about which CATEGORIES are worth their own color in a plot. It
# never looks at a single gene or a single cell's expression. A cell labeled
# "T_cell" stays "T_cell" here regardless of whether it actually expresses
# any T cell marker; the only thing that changes is whether that label gets
# its own slot in the legend or gets folded into "Other" because too few
# cells share it. Step 5.4a, later, asks a different question on top of this
# one: given a label that survived this filter, does the individual cell
# carrying it actually show the expression evidence that label implies? That
# is a per-cell, marker-based check, not a per-label, count-based one. Step
# 5.4c then builds `singler_label_clean` directly from `singler_label_top`,
# adding only the cells that failed the Step 5.4a marker check as a new
# "Ambiguous" category. The two steps are not redundant: this one decides
# what to show, Step 5.4a/5.4c decides who to trust within what is shown.

TOP_N_LABELS <- 8

label_tab <- sort(table(sobj_filt$singler_label), decreasing = TRUE)
top_labels <- names(label_tab)[seq_len(min(TOP_N_LABELS, length(label_tab)))]
n_collapsed <- length(label_tab) - length(top_labels)

sobj_filt$singler_label_top <- ifelse(
  sobj_filt$singler_label %in% top_labels,
  sobj_filt$singler_label,
  sprintf("Other (%d small labels)", n_collapsed)
)
sobj_filt$singler_label_top <- factor(
  sobj_filt$singler_label_top,
  levels = c(top_labels, sprintf("Other (%d small labels)", n_collapsed))
)

cat(sprintf("Kept top %d labels, collapsed %d smaller labels into 'Other':\n",
            length(top_labels), n_collapsed))
print(table(sobj_filt$singler_label_top))

# Sanity rules of thumb for PBMC, checked against the full (uncollapsed)
# label table:
# - Expect 3 to 7 dominant labels (T cells, B cells, monocytes, NK cells, DC)
# - One label > 80% of all cells: suspicious (annotation collapse)
# - More than 15 distinct labels in 3,000 cells: reference too granular
# - Any single non-immune label > 5% (e.g. hepatocytes, fibroblasts): wrong reference

n_labels <- length(label_tab)
top_prop <- max(label_tab) / sum(label_tab)
cat(sprintf("\nDistinct labels (full table): %d  |  Dominant label proportion: %.1f%%\n",
            n_labels, top_prop * 100))
if (n_labels > 15) cat(">> Many distinct labels. Reference may be too granular for PBMC.\n")
if (top_prop > 0.80) cat(">> One label dominates. Check whether reference matches the tissue.\n")

# QUESTION 5.2b: Look at the labels collapsed into "Other" (the rows of
# label_tab beyond rank 8). Are any of them biologically plausible for PBMC
# (e.g. "Platelets", "DC") or all implausible (e.g. "Hepatocytes",
# "Neurons")? What would you do differently if a plausible label got
# collapsed away?

# -----------------------------------------------------------------------------
# Step 5.3 | Annotated UMAP and the cleaned-up heatmap
# -----------------------------------------------------------------------------

p_ann <- DimPlot(sobj_filt, group.by = "singler_label_top",
                 label = TRUE, label.size = 3, repel = TRUE) +
  ggtitle("SingleR annotation (top labels)") + NoLegend()

p_cond <- DimPlot(sobj_filt, group.by = "condition",
                  cols = c("Healthy" = "#0d7377", "COVID19" = "#991b1b"),
                  pt.size = 0.4) +
  ggtitle("Condition")

p_ann | p_cond

# Same heatmap as Step 5.2, restricted to the labels that survived the
# top-N consolidation. Compare directly against the full 37-row version
# shown earlier: this is what "readable" looks like once the labels that
# carried no real signal have been set aside.

cat("Labels passed to labels.use:\n")
print(top_labels)

heatmap_result <- tryCatch({
  plotScoreHeatmap(singler_res,
                   labels.use = top_labels,
                   main = "SingleR annotation scores (top labels only; compare to Step 5.2)")
  "filtered"
}, error = function(e) {
  message("labels.use raised an error in this SingleR version: ", conditionMessage(e))
  message("Falling back to the full heatmap.")
  plotScoreHeatmap(singler_res,
                   main = "SingleR annotation scores (wider spread = more confident)")
  "full (fallback)"
})

cat("Heatmap actually drawn:", heatmap_result, "\n")
cat("If this says 'full (fallback)', the plot above is identical to Step 5.2\n")
cat("by design: that is the fallback path, not the filtered version.\n")

# -----------------------------------------------------------------------------
# Step 5.4 | Verify the annotated object
# -----------------------------------------------------------------------------

# Compare the object now with its state in Block 1 before moving to the
# CITE-seq workflow.

cat("Object after RNA workflow + annotation:\n")
print(sobj_filt)
cat("\nReductions :", paste(SafeReductions(sobj_filt), collapse = ", "), "\n")
cat("Assays     :", paste(SafeAssays(sobj_filt), collapse = ", "), "\n")
cat("New metadata columns vs pre-QC:\n")
print(setdiff(colnames(sobj_filt@meta.data), colnames(sobj@meta.data)))

# QUESTION 5.4: Which slots are still empty / unchanged in the ADT assay?
# What does that tell you about what Block 6 needs to do first?

# -----------------------------------------------------------------------------
# Step 5.4a | Canonical-marker validation per cell type
# -----------------------------------------------------------------------------

# Before trusting an annotation, verify the canonical RNA marker of each
# major lineage is detected in a reasonable fraction of cells assigned to
# that lineage. The label-distribution sanity check already ran in Step
# 5.2b, right after the labels were consolidated; this step is a different
# kind of check, on the per-marker evidence rather than the label counts.
# 
# Step 5.2b asked "how many cells share this label, and is that count
# plausible for PBMC?" That is a question about labels as categories: it
# never inspected a single gene. This step asks a different question: "for
# a cell that carries this label, does its RNA actually show the marker
# that label implies?" That is a per-cell, expression-based check, run
# independently of how common or rare the label was. A label can pass the
# Step 5.2b frequency check (common enough to keep its own category) and
# still fail this one (most cells carrying it do not express the expected
# marker), which is exactly what the detection-rate table below is built to
# catch. The output of this step (`detection_rates`) feeds Step 5.4c, which
# builds `singler_label_clean` from `singler_label_top` and adds "Ambiguous"
# only for the cells that failed this marker check, on top of the
# categories Step 5.2b already decided were worth keeping.

# Map SingleR label patterns to canonical markers
check_markers <- list(
  "T_cell|T cell" = c("CD3E", "CD3D"),
  "B_cell|B cell" = c("CD79A", "MS4A1"),
  "Monocyte"      = c("CD14", "LYZ"),
  "NK"            = c("NKG7", "GNLY"),
  "DC|Dendritic"  = c("FCER1A")
)

cat(sprintf("\n%-25s %-10s %-12s %s\n", "Label", "Marker", "Cells (n)", "Detection rate"))
cat(sprintf("%-25s %-10s %-12s %s\n",   "-----", "------", "---------", "--------------"))

for (lbl in unique(sobj_filt$singler_label)) {
  for (lbl_pat in names(check_markers)) {
    if (grepl(lbl_pat, lbl, ignore.case = TRUE)) {
      cell_mask <- sobj_filt$singler_label == lbl
      n_cells   <- sum(cell_mask)
      for (mk in check_markers[[lbl_pat]]) {
        if (mk %in% rownames(sobj_filt[["RNA"]])) {
          rna_vec <- FetchData(sobj_filt, vars = mk)[cell_mask, 1]
          rate    <- mean(rna_vec > 0) * 100
          flag    <- if (rate < 25) "LOW (dropout or wrong label)" else "ok"
          cat(sprintf("%-25s %-10s %-12d %.1f%% %s\n",
                      substr(lbl, 1, 25), mk, n_cells, rate, flag))
        }
      }
    }
  }
}

# QUESTION 5.4a: which annotated cell type has the lowest detection rate of
# its canonical marker? The code below finds it explicitly.
detection_rates <- data.frame(label = character(0), marker = character(0),
                              rate = numeric(0), stringsAsFactors = FALSE)
for (lbl in unique(sobj_filt$singler_label)) {
  for (lbl_pat in names(check_markers)) {
    if (grepl(lbl_pat, lbl, ignore.case = TRUE)) {
      cell_mask <- sobj_filt$singler_label == lbl
      for (mk in check_markers[[lbl_pat]]) {
        if (mk %in% rownames(sobj_filt[["RNA"]])) {
          rna_vec <- FetchData(sobj_filt, vars = mk)[cell_mask, 1]
          detection_rates <- rbind(detection_rates,
            data.frame(label = lbl, marker = mk,
                       rate = mean(rna_vec > 0) * 100,
                       stringsAsFactors = FALSE))
        }
      }
    }
  }
}
if (nrow(detection_rates) > 0) {
  worst <- detection_rates[which.min(detection_rates$rate), ]
  cat(sprintf("\nLowest detection: %s expressing %s at %.1f%%\n",
              worst$label, worst$marker, worst$rate))
  cat("\nDecision rule:\n")
  cat("  rate >= 50%  -> annotation consistent with RNA (no action)\n")
  cat("  rate 25-50%  -> dropout likely (ADT in Block 6 should rescue)\n")
  cat("  rate < 25%   -> suspect misannotation; cross-check with ADT now\n")
}

# -----------------------------------------------------------------------------
# Step 5.4c | Mark inconsistent labels as Ambiguous
# -----------------------------------------------------------------------------

# Cells whose canonical marker detection rate fell below 25% in Step 5.4a are
# flagged, not deleted. `singler_label_clean` carries the same values as
# `singler_label_top` except those flagged cells, which become "Ambiguous".
# Every prior column (`singler_label`, `singler_label_top`) stays untouched.

low_conf_labels <- character(0)
if (nrow(detection_rates) > 0) {
  per_label_rate  <- aggregate(rate ~ label, data = detection_rates, FUN = min)
  low_conf_labels <- per_label_rate$label[per_label_rate$rate < 25]
}

sobj_filt$singler_label_clean <- as.character(sobj_filt$singler_label_top)
ambiguous_mask <- sobj_filt$singler_label %in% low_conf_labels
sobj_filt$singler_label_clean[ambiguous_mask] <- "Ambiguous"
sobj_filt$singler_label_clean <- factor(sobj_filt$singler_label_clean)

cat(sprintf("\nLabels flagged Ambiguous (canonical marker detection < 25%%): %d\n",
            length(low_conf_labels)))
if (length(low_conf_labels) > 0) cat(" ", paste(low_conf_labels, collapse = ", "), "\n")
cat(sprintf("Cells marked Ambiguous: %d (%.1f%% of total)\n",
            sum(ambiguous_mask), 100 * mean(ambiguous_mask)))
cat("\nFinal label distribution (singler_label_clean):\n")
print(table(sobj_filt$singler_label_clean))

# QUESTION 5.4c: Cells marked Ambiguous are still in sobj_filt and still
# count toward ncol(sobj_filt). Why keep them instead of deleting them
# outright? What would deleting them silently change about cell counts
# reported in every plot from here on?

# -----------------------------------------------------------------------------
# Step 5.4d | Re-plot the UMAP with only confident labels
# -----------------------------------------------------------------------------

# Same UMAP as Step 5.3, restricted to cells that were NOT flagged Ambiguous.
# Cells are not removed from the object; they are simply excluded from this
# specific plot via `cells.highlight` style filtering on a copy of the
# metadata used for plotting.

confident_cells <- colnames(sobj_filt)[sobj_filt$singler_label_clean != "Ambiguous"]
cat(sprintf("Plotting %d / %d cells (%.1f%%) with confident annotation.\n",
            length(confident_cells), ncol(sobj_filt),
            100 * length(confident_cells) / ncol(sobj_filt)))

DimPlot(sobj_filt, cells = confident_cells,
        group.by = "singler_label_clean",
        label = TRUE, label.size = 3, repel = TRUE) +
  ggtitle("Confident annotation only (Ambiguous cells excluded from view)") +
  NoLegend()

# -----------------------------------------------------------------------------
# Step 5.4e | Integrate with Harmony
# -----------------------------------------------------------------------------

# Step 4.4b found the donor effect borderline-to-low in this dataset (R^2 on
# PC1/PC2), so integration was not required to proceed. We run it anyway here
# to build the comparison panel in Step 5.4f: with vs without Harmony is a
# habit worth seeing on data you already understand, before relying on it on
# data you do not.

sobj_filt <- RunHarmony(
  sobj_filt,
  group.by.vars  = "donor_id",
  reduction      = "pca",
  dims.use       = 1:20,
  reduction.save = "harmony",
  verbose        = FALSE
)

sobj_filt <- RunUMAP(
  sobj_filt,
  reduction      = "harmony",
  dims           = 1:20,
  reduction.name = "umap.harmony",
  umap.method    = "uwot",
  metric         = "cosine",
  verbose        = FALSE
)

cat("Reductions now available:", paste(SafeReductions(sobj_filt), collapse = ", "), "\n")

# Step 4.4b computed donor R^2 on the plain PCA before any decision was made.
# Now that Harmony has run, compute the same R^2 on the harmonized embedding
# and compare directly: this is the actual gain or loss from integrating,
# in the same units used to make the original decision, not just a visual
# impression from a UMAP.

pc_coords_pca     <- Embeddings(sobj_filt, reduction = "pca")[, 1:2]
pc_coords_harmony <- Embeddings(sobj_filt, reduction = "harmony")[, 1:2]

r2_comparison <- data.frame(
  dimension = c("PC1", "PC2"),
  r2_before_harmony = sapply(1:2, function(pc)
    summary(lm(pc_coords_pca[, pc] ~ sobj_filt$donor_id))$r.squared),
  r2_after_harmony = sapply(1:2, function(pc)
    summary(lm(pc_coords_harmony[, pc] ~ sobj_filt$donor_id))$r.squared)
)
r2_comparison$change <- r2_comparison$r2_after_harmony - r2_comparison$r2_before_harmony

cat("\nDonor R^2 before vs after Harmony:\n")
print(r2_comparison, row.names = FALSE)

cat("\nInterpretation: a large negative change means Harmony successfully\n")
cat("removed donor-driven variance from that dimension. A change near zero\n")
cat("confirms the Step 4.4b read: there was little donor effect to remove\n")
cat("in the first place, so integration cost real biological variance for\n")
cat("essentially no batch-correction gain.\n")

# QUESTION 5.4e: Is the change in donor R^2 large or close to zero in this
# dataset? Does that match what the Step 4.4b decision predicted? If you ran
# this on a dataset with R^2 above 0.30, what change would you expect to see
# in this same table?

# -----------------------------------------------------------------------------
# Step 5.4f | Comparison panel: UMAP before/after annotation, with/without Harmony
# -----------------------------------------------------------------------------

# Four panels answer four different questions about the same object:
#   1. Pre-annotation: do the unsupervised clusters look reasonable at all?
#   2. Post-annotation (no Harmony): does the annotation make sense on the
#      embedding you actually used through Block 5?
#   3. Post-annotation, Harmony: did integration change which cells sit near
#      which others?
#   4. Donor color on the Harmony UMAP: did Harmony actually mix donors
#      together, or did it not need to (consistent with the Step 4.4b call)?

p1_preannot <- DimPlot(sobj_filt, reduction = "umap", group.by = "seurat_clusters",
                        label = TRUE, label.size = 3) +
  ggtitle("1. Pre-annotation (unsupervised clusters)") + NoLegend()

p2_postannot <- DimPlot(sobj_filt, reduction = "umap", group.by = "singler_label_clean",
                         label = TRUE, label.size = 2.5, repel = TRUE) +
  ggtitle("2. Post-annotation, no Harmony") + NoLegend()

p3_harmony_annot <- DimPlot(sobj_filt, reduction = "umap.harmony", group.by = "singler_label_clean",
                             label = TRUE, label.size = 2.5, repel = TRUE) +
  ggtitle("3. Post-annotation, with Harmony") + NoLegend()

p4_harmony_donor <- DimPlot(sobj_filt, reduction = "umap.harmony", group.by = "donor_id") +
  ggtitle("4. Harmony UMAP by donor")

(p1_preannot | p2_postannot) / (p3_harmony_annot | p4_harmony_donor)

# QUESTION 5.4f: Compare panels 2 and 3. If the cell-type layout looks
# nearly identical before and after Harmony, what does that confirm about
# the Step 4.4b decision not to integrate? If it looks different, which
# panel would you trust for the rest of the analysis, and why?

# -----------------------------------------------------------------------------
# Step 5.4g | Differential expression markers per annotated cell type
# -----------------------------------------------------------------------------

# Explicit about what this test actually uses, since the object now carries
# both a plain PCA/UMAP and a Harmony-corrected PCA/UMAP from Step 5.4e:
# 
#   Assay         : RNA, "data" layer (log-normalized counts from Block 4).
#                   Harmony only touches the PCA/UMAP embeddings (used for
#                   visualization and clustering); it never modifies the
#                   RNA expression values that FindAllMarkers reads. Running
#                   this on the harmonized object or the pre-Harmony object
#                   gives identical results, because DE testing here compares
#                   expression directly between groups of cells, not their
#                   position on any embedding.
#   Grouping      : singler_label_clean (Step 5.4c), Ambiguous cells excluded.
#                   They are not a coherent biological group, so testing them
#                   as their own "cluster" would not mean anything.
#   Filters       : only.pos = TRUE (markers, not anti-markers),
#                   min.pct = 0.25 (expressed in at least 25% of one group),
#                   logfc.threshold = 0.5 (at least 1.4-fold change).

DefaultAssay(sobj_filt) <- "RNA"
Idents(sobj_filt) <- "singler_label_clean"

de_markers <- FindAllMarkers(
  subset(sobj_filt, idents = "Ambiguous", invert = TRUE),
  only.pos        = TRUE,
  min.pct         = 0.25,
  logfc.threshold = 0.5,
  verbose         = FALSE
)

TOP_N_MARKERS <- 5
top_markers <- de_markers %>%
  group_by(cluster) %>%
  slice_max(order_by = avg_log2FC, n = TOP_N_MARKERS) %>%
  ungroup()

cat(sprintf("Top %d markers per confident cell type:\n", TOP_N_MARKERS))
print(top_markers[, c("cluster", "gene", "avg_log2FC", "pct.1", "pct.2", "p_val_adj")],
      n = nrow(top_markers))

DotPlot(sobj_filt,
        features = unique(top_markers$gene),
        idents   = setdiff(levels(Idents(sobj_filt)), "Ambiguous"),
        group.by = "singler_label_clean") +
  RotatedAxis() +
  ggtitle(sprintf("Top %d markers per cell type (confident labels only)", TOP_N_MARKERS))

# QUESTION 5.4g: Pick one cell type from the DotPlot. Does its top marker
# match a canonical marker you already know for that lineage (Step 1.8)? If
# not, is that a red flag about the annotation, or a finding outside the
# canonical list that is worth investigating further?

# -----------------------------------------------------------------------------
# Step 5.5 | Save the annotated checkpoint
# -----------------------------------------------------------------------------

saveRDS(sobj_filt, "outputs/sobj_preprocessed.rds")
cat("Checkpoint saved: outputs/sobj_preprocessed.rds\n")
cat("To reload: sobj_filt <- readRDS('outputs/sobj_preprocessed.rds')\n")

# BREAK: 15 minutes  |  1:55 to 2:10

# Look at the UMAP colored by condition. Does any cluster appear exclusively
# or predominantly in COVID-19 donors? Look at the DotPlot: which clusters
# could be monocytes based on CD14 and FCGR3A expression?
# After the break, we add the protein layer to test these interpretations.

# =============================================================================
# BLOCK 6  |  CITE-seq integration (ADT + RNA)
# =============================================================================

# Goal: bring the protein layer into the analysis. The RNA workflow up to
# Block 5 ignored ADT entirely. The CITE-seq value-add is the ability to
# resolve dropout, validate annotation, and weight modalities per cell.
#
# Order of operations: inspect the ADT layer and contrast it with RNA,
# normalize, QC the panel, contrast RNA vs ADT for matched markers, gate,
# cross-check for swapped channels, build the ADT PCA, then integrate
# with WNN.

# -----------------------------------------------------------------------------
# Step 6.0a | Inspecting the ADT assay (intermediate, contrast)
# -----------------------------------------------------------------------------

# ADT is also stored as a v5 assay, but the data behave differently from RNA:
# few features, no dropout, bimodal counts per protein, very wide dynamic
# range, no need for highly variable feature selection. Make these properties
# concrete before doing anything else with the protein layer.

DefaultAssay(sobj_filt) <- "ADT"
adt_counts <- LayerData(sobj_filt, assay = "ADT", layer = "counts")

cat("ADT count matrix:\n")
cat("  Proteins (rows):", nrow(adt_counts), "\n")
cat("  Cells   (cols) :", ncol(adt_counts), "\n")
cat("  Class          :", class(adt_counts), "\n")
cat("  Layers in ADT  :", paste(SafeLayers(sobj_filt[["ADT"]]), collapse = ", "), "\n\n")

# Per-protein summary: scale and distribution
adt_summary <- data.frame(
  protein  = rownames(adt_counts),
  min      = apply(adt_counts, 1, min),
  median   = apply(adt_counts, 1, median),
  mean     = round(Matrix::rowMeans(adt_counts), 2),
  max      = apply(adt_counts, 1, max),
  pct_zero = round(Matrix::rowMeans(adt_counts == 0) * 100, 1)
)
cat("Per-protein distribution (first 8 proteins):\n")
print(head(adt_summary, 8), row.names = FALSE)

# Per-cell total ADT count
total_adt_per_cell <- Matrix::colSums(adt_counts)
cat("\nPer-cell total ADT counts:\n")
print(round(quantile(total_adt_per_cell, c(0.05, 0.25, 0.5, 0.75, 0.95)), 0))

DefaultAssay(sobj_filt) <- "RNA"

# QUESTION 6.0a: An ADT protein with median ~0 but max in the high hundreds
# is typical bimodality (background cells vs stained cells). A protein with
# mean below 1 in every cell is something else. Which is which in the table
# above?

# -----------------------------------------------------------------------------
# Step 6.0b | RNA sparsity vs ADT sparsity
# -----------------------------------------------------------------------------

# Block 1 measured RNA sparsity on its own. Now that the ADT layer has been
# inspected too, the comparison is the point: the same cells, two assays,
# very different zero rates.

rna_counts_b6 <- LayerData(sobj_filt, assay = "RNA", layer = "counts")
rna_sparsity  <- 1 - Matrix::nnzero(rna_counts_b6) / prod(dim(rna_counts_b6))
adt_sparsity  <- 1 - Matrix::nnzero(adt_counts)     / prod(dim(adt_counts))

cat("RNA sparsity:", round(rna_sparsity * 100, 1), "%\n")
cat("ADT sparsity:", round(adt_sparsity * 100, 1), "%\n")

# QUESTION 6.0b: Why is ADT sparsity so much lower than RNA sparsity? What
# does each zero mean biologically in the two modalities?

# -----------------------------------------------------------------------------
# Step 6.1 | Re-inspect the ADT layer
# -----------------------------------------------------------------------------

# ADT has been sitting untouched since Block 1. Confirm its state explicitly
# before normalizing.

DefaultAssay(sobj_filt) <- "ADT"
cat("ADT assay current state:\n")
cat("  Active assay : ADT\n")
cat("  Proteins     :", nrow(sobj_filt[["ADT"]]), "\n")
cat("  Cells (post-QC):", ncol(sobj_filt), "\n")
cat("  Layers       :", paste(SafeLayers(sobj_filt[["ADT"]]), collapse = ", "), "\n")

# At this point we expect: counts only. No data, no scale.data. Normalization
# is the next step.

# PUZZLE 6.1/A (ADT): without normalizing yet, which protein has the highest raw
# variance across cells? Is it a lineage marker (CD3, CD4, CD8a, CD14, CD19,
# CD56) or an activation marker (HLADR, CD69, CD25, PD1)?
adt_counts <- LayerData(sobj_filt, assay = "ADT", layer = "counts")
adt_var <- apply(adt_counts, 1, var)
cat("\nTop 5 ADT proteins by raw-count variance:\n")
print(round(sort(adt_var, decreasing = TRUE)[1:5], 1))

# PUZZLE 6.1/B (ADT): how many cells are positive for BOTH CD4 and CD8a in the
# raw counts (> 5 counts each)? In healthy PBMC this should be near zero;
# anything substantial is a doublet or a contamination signal.
cd4_pos <- adt_counts["CD4", ] > 5
cd8_pos <- adt_counts["CD8a", ] > 5
cat("\nADT CD4+ cells              :", sum(cd4_pos), "\n")
cat("ADT CD8a+ cells             :", sum(cd8_pos), "\n")
cat("Double-positive (suspicious):", sum(cd4_pos & cd8_pos), "  (~0 expected)\n")

# QUESTION 6.1: Does the double-positive count match what you expect
# biologically, or does it indicate doublets that survived scDblFinder?
# What would you do about it before annotating T cell subsets?

# -----------------------------------------------------------------------------
# Step 6.2 | ADT normalization (CLR, margin = 2)
# -----------------------------------------------------------------------------

# CLR (Centered Log-Ratio) normalization. The margin argument sets the
# direction:
#   margin = 1: normalizes each protein across all cells (row means ~0)
#   margin = 2: normalizes each cell across all proteins (column means ~0)
# margin = 2 is correct for CITE-seq. It removes per-cell variation in total
# antibody capture, analogous to library size normalization in RNA. margin = 1
# runs without error but destroys biological signal. You will diagnose a real
# object normalized the wrong way in Block 8, Scenario 3.

DefaultAssay(sobj_filt) <- "ADT"

sobj_filt <- NormalizeData(
  sobj_filt,
  normalization.method = "CLR",
  margin               = 2  # CORRECT: normalizes each cell across proteins
)

adt_m2 <- LayerData(sobj_filt, layer = "data")
cat("Column means after margin=2 (per cell), expected ~0:\n")
print(round(colMeans(adt_m2)[1:8], 4))
cat("\nRow means (per protein), should NOT be ~0 (biological variation preserved):\n")
print(round(rowMeans(adt_m2), 4))

DefaultAssay(sobj_filt) <- "RNA"
cat("\nADT normalized correctly.\n")

# QUESTION 6.2: Why is the row mean a useful diagnostic? What would the row
# means look like if margin had been set to 1?

# -----------------------------------------------------------------------------
# Step 6.3 | ADT panel QC: detect dead / failed antibodies
# -----------------------------------------------------------------------------

# A failed conjugation or degraded antibody produces a "dead channel": the
# protein reads near zero in every cell, with almost no variance. It does not
# error. If you gate or annotate on a dead channel, you silently lose a whole
# population.

DefaultAssay(sobj_filt) <- "ADT"
adt_counts <- LayerData(sobj_filt, layer = "counts")

panel_qc <- data.frame(
  protein   = rownames(adt_counts),
  median    = round(apply(adt_counts, 1, median), 2),
  mean      = round(Matrix::rowMeans(adt_counts), 2),
  pct_zero  = round(Matrix::rowMeans(adt_counts == 0) * 100, 1),
  max       = apply(adt_counts, 1, max)
)
panel_qc <- panel_qc[order(panel_qc$mean), ]
cat("ADT panel QC (sorted by mean; suspicious = bottom rows):\n")
print(head(panel_qc, 6), row.names = FALSE)

DefaultAssay(sobj_filt) <- "RNA"

# QUESTION 6.3: One protein has near-zero counts in essentially every cell
# while its RNA counterpart is clearly expressed in a defined cluster. Which
# protein, and which cell type does it mark?

# Compare the suspect protein (ADT) against its RNA gene side by side.
# Edit `suspect_adt` / `suspect_rna` to the protein flagged above.
suspect_adt <- "CD56"     # protein flagged as near-zero in panel QC
suspect_rna <- "NCAM1"    # its RNA counterpart (NK marker)

# Decide the title from the actual panel_qc numbers instead of asserting a
# fixed claim. On the clean object this protein is healthy; on the injected
# object it is dead. The title should say whichever is true for the object
# that is actually loaded.
suspect_row <- panel_qc[panel_qc$protein == suspect_adt, ]
is_dead <- nrow(suspect_row) == 1 && suspect_row$pct_zero > 90 && suspect_row$mean < 1

adt_title <- if (is_dead) {
  paste0(suspect_adt, " ADT\n(flat: likely failed antibody)")
} else {
  paste0(suspect_adt, " ADT\n(signal present: not a dead channel here)")
}

DefaultAssay(sobj_filt) <- "ADT"
p_dead <- FeaturePlot(sobj_filt, suspect_adt, min.cutoff = "q05") +
  ggtitle(adt_title)

DefaultAssay(sobj_filt) <- "RNA"
p_alive <- FeaturePlot(sobj_filt, suspect_rna, min.cutoff = "q05") +
  ggtitle(paste0(suspect_rna, " RNA\n(clear NK signal: protein should exist)"))

p_dead | p_alive
DefaultAssay(sobj_filt) <- "RNA"

# -----------------------------------------------------------------------------
# Step 6.4 | RNA vs ADT for the same marker (dropout)
# -----------------------------------------------------------------------------

# Direct comparison. CD4 mRNA reads as zero in many CD4+ T cells (dropout),
# while CD4 protein from ADT is bimodal across the same cells.

DefaultAssay(sobj_filt) <- "RNA"
p_rna <- FeaturePlot(sobj_filt, "CD4", min.cutoff = "q05") +
  ggtitle("CD4 via RNA\n(dropout: many CD4+ cells read as zero)") +
  scale_color_gradient(low = "lightgrey", high = "#991b1b")

DefaultAssay(sobj_filt) <- "ADT"
p_adt <- FeaturePlot(sobj_filt, "CD4", min.cutoff = "q05") +
  ggtitle("CD4 via ADT protein\n(bimodal, reliable)") +
  scale_color_gradient(low = "lightgrey", high = "#0d7377")

p_rna | p_adt
DefaultAssay(sobj_filt) <- "RNA"

# -----------------------------------------------------------------------------
# Step 6.5 | RNA-protein correlation across all matched markers
# -----------------------------------------------------------------------------

# For each ADT protein with an RNA counterpart, compute the Spearman
# correlation across all cells. Low correlation = high dropout in RNA.

adt_rna_pairs <- list(
  CD3  = "CD3E",
  CD4  = "CD4",
  CD8a = "CD8A",
  CD14 = "CD14",
  CD19 = "CD19",
  CD56 = "NCAM1"
)

DefaultAssay(sobj_filt) <- "ADT"
adt_vals <- t(LayerData(sobj_filt, layer = "data"))
DefaultAssay(sobj_filt) <- "RNA"
rna_vals <- t(LayerData(sobj_filt, layer = "data"))

cat("Spearman correlation (RNA vs ADT) per marker:\n")
cat(sprintf("  %-8s %s\n", "Marker", "Spearman rho"))
cat(sprintf("  %-8s %s\n", "------", "------------"))

for (adt_name in names(adt_rna_pairs)) {
  rna_gene <- adt_rna_pairs[[adt_name]]
  if (rna_gene %in% colnames(rna_vals) &&
      adt_name %in% colnames(adt_vals)) {
    rho <- cor(rna_vals[, rna_gene],
               adt_vals[, adt_name],
               method = "spearman")
    cat(sprintf("  %-8s %.3f\n", adt_name, rho))
  }
}
DefaultAssay(sobj_filt) <- "RNA"

# -----------------------------------------------------------------------------
# Step 6.6 | Quantify dropout: ADT-positive but RNA-zero cells
# -----------------------------------------------------------------------------

# For each marker, find cells that are clearly protein-positive (ADT > threshold)
# but have zero RNA counts. These are the cells that would be misannotated
# by RNA-only analysis.

DefaultAssay(sobj_filt) <- "ADT"
adt_data <- LayerData(sobj_filt, layer = "data")
DefaultAssay(sobj_filt) <- "RNA"
rna_counts <- LayerData(sobj_filt, layer = "counts")

cat("Dropout analysis: cells positive by ADT but zero by RNA\n")
cat(sprintf("  %-8s %-12s %-12s %s\n",
            "Marker", "ADT+ cells", "RNA==0 among ADT+", "Dropout rate"))
cat(sprintf("  %-8s %-12s %-12s %s\n",
            "------", "----------", "-----------------", "------------"))

marker_pairs <- list(CD4 = "CD4", CD14 = "CD14", CD19 = "CD19")
for (adt_name in names(marker_pairs)) {
  rna_gene <- marker_pairs[[adt_name]]
  if (rna_gene %in% rownames(rna_counts) && adt_name %in% rownames(adt_data)) {
    adt_pos  <- which(adt_data[adt_name, ] > 1.0)
    rna_zero <- sum(rna_counts[rna_gene, adt_pos] == 0)
    pct      <- round(rna_zero / length(adt_pos) * 100, 1)
    cat(sprintf("  %-8s %-12d %-12d %s%%\n",
                adt_name, length(adt_pos), rna_zero, pct))
  }
}

# QUESTION 6.6: for a marker with 80% dropout, what fraction of cells would
# be misannotated by an RNA-only workflow? Quick arithmetic:
cat("\nWorked example: 80% dropout on CD4 RNA\n")
cat("  Single-marker decision (CD4 RNA > 0): misses 80% of true CD4+ cells.\n")
cat("  Marker panel of N independent markers (each with 80% dropout):\n")
cat("    P(all N drop)= 0.8^N\n")
for (n in c(1, 2, 3, 5)) {
  cat(sprintf("    N = %d markers -> %.1f%% of cells still misannotated\n",
              n, 0.8^n * 100))
}
cat("Rule of thumb: with 80% per-marker dropout, you need >= 3 independent\n")
cat("markers in the panel to reduce misannotation below 50%.\n")

# -----------------------------------------------------------------------------
# Step 6.7 | Digital gating
# -----------------------------------------------------------------------------

# Digital gating replicates the biaxial scatter plots from flow cytometry
# using ADT data. It allows computational cell classification with the same
# logic immunologists use at the bench.

DefaultAssay(sobj_filt) <- "ADT"

color_by <- if ("singler_label_top" %in% colnames(sobj_filt@meta.data)) {
  "singler_label_top"
} else {
  "cell_type"
}

gate_data <- FetchData(sobj_filt, vars = c("CD4", "CD8a", color_by))
names(gate_data)[3] <- "label"

ggplot(gate_data, aes(CD4, CD8a, color = label)) +
  geom_point(alpha = 0.4, size = 0.8) +
  geom_density_2d(color = "grey50", linewidth = 0.3) +
  geom_vline(xintercept = 1.5, linetype = "dashed", color = "#991b1b") +
  geom_hline(yintercept = 1.5, linetype = "dashed", color = "#991b1b") +
  annotate("text", x = 3.5, y = 0.4, label = "CD4+ T cells", size = 3.5) +
  annotate("text", x = 0.4, y = 3.5, label = "CD8+ T cells", size = 3.5) +
  labs(title    = "Digital gating: CD4 vs CD8a (ADT protein)",
       subtitle = "Only possible with ADT; RNA dropout makes this scatter uninformative",
       x = "CD4 (CLR normalized)", y = "CD8a (CLR normalized)",
       color = NULL) +
  theme_classic(base_size = 13) +
  theme(legend.text = element_text(size = 7))

DefaultAssay(sobj_filt) <- "RNA"

# -----------------------------------------------------------------------------
# Step 6.7b | Silent failure: DefaultAssay forgotten between calls
# -----------------------------------------------------------------------------

# A function call that "works" on the wrong assay produces a silent error.
# FeaturePlot("CD4") with DefaultAssay = "RNA" plots the CD4 RNA gene.
# FeaturePlot("CD4") with DefaultAssay = "ADT" plots the CD4 protein.
# The plot RENDERS in both cases, and the two plots can look deceptively
# similar: min.cutoff = "q05" rescales each panel's color gradient to its
# own value range, so a sparse RNA signal and a dense ADT signal both end up
# stretched across a similar-looking color scale. The failure is silent
# precisely because nothing in the rendered plot warns you which assay
# produced it.

# Quantify the difference that the plot alone hides: what fraction of cells
# read exactly zero in each modality for this marker.
DefaultAssay(sobj_filt) <- "RNA"
cd4_rna_zero_pct <- mean(LayerData(sobj_filt, layer = "counts")["CD4", ] == 0) * 100
DefaultAssay(sobj_filt) <- "ADT"
cd4_adt_zero_pct <- mean(LayerData(sobj_filt, layer = "counts")["CD4", ] == 0) * 100
DefaultAssay(sobj_filt) <- "RNA"

cat(sprintf("CD4 zero rate: %.1f%% of cells in RNA, %.1f%% of cells in ADT\n",
            cd4_rna_zero_pct, cd4_adt_zero_pct))
cat("The plots below can look similar at a glance; the zero rates above are\n")
cat("the actual difference the two assays are reporting for the same gene.\n")

# Demonstrate by drawing the same call under both assays. Titles are kept
# short and font size is constrained, since the two plots render side by
# side at half width each.
DefaultAssay(sobj_filt) <- "RNA"
p_as_rna <- FeaturePlot(sobj_filt, "CD4", min.cutoff = "q05") +
  ggtitle("'CD4' | DefaultAssay = RNA") +
  theme(plot.title = element_text(size = 11))

DefaultAssay(sobj_filt) <- "ADT"
p_as_adt <- FeaturePlot(sobj_filt, "CD4", min.cutoff = "q05") +
  ggtitle("'CD4' | DefaultAssay = ADT") +
  theme(plot.title = element_text(size = 11))

p_as_rna | p_as_adt
DefaultAssay(sobj_filt) <- "RNA"

# QUESTION 6.7b: Both plots rendered, and at a glance they can look almost
# the same. The zero-rate numbers printed above tell a different story. If
# you saved one of these plots as a figure for a paper without checking
# DefaultAssay first, which one would you have, and would a reader be able
# to tell from the figure alone that 'CD4' meant something different in
# each panel?

# -----------------------------------------------------------------------------
# Step 6.7c | Spot the bug
# -----------------------------------------------------------------------------

# Read the code below. It looks correct. What is wrong?
#
#   DefaultAssay(sobj_filt) <- "RNA"
#   adt_markers <- FindMarkers(sobj_filt, ident.1 = "CD4Tcell",
#                              group.by = "cell_type",
#                              min.pct  = 0.25)
#
# Your answer:
#
# REVEAL: the call asks for markers of CD4 T cells but DefaultAssay is RNA.
# It returns RNA markers, not ADT markers. The output is correct for RNA but
# does not answer the question "which proteins distinguish CD4 T cells".
# Either set DefaultAssay = "ADT" first, or pass assay = "ADT" inside the
# FindMarkers call. The min.pct = 0.25 is also wrong for ADT (designed for
# sparse RNA); for ADT use a value like 0.5 or 0.0 with logfc.threshold.

# -----------------------------------------------------------------------------
# Step 6.8 | When gating makes no biological sense: a swapped channel
# -----------------------------------------------------------------------------

# A swapped or mislabeled channel runs perfectly. CLR normalizes it,
# FeaturePlot draws it, gating gates it. Nothing errors. The only signal is
# that the biology is impossible. The defense is to cross-check each protein
# against an independent label (its RNA marker).

# Each protein should correlate with its own RNA gene across cells.
# A canonical marker with rho near 0 is a mislabeled channel.
DefaultAssay(sobj_filt) <- "ADT"
adt_d <- t(LayerData(sobj_filt, layer = "data"))
DefaultAssay(sobj_filt) <- "RNA"
rna_d <- t(LayerData(sobj_filt, layer = "data"))

check_pairs <- list(CD4 = "CD4", CD8a = "CD8A", CD19 = "CD19",
                    CD14 = "CD14", CD3 = "CD3E")

cat(sprintf("  %-6s %-12s %-10s\n", "ADT", "rho(self)", "verdict"))
cat(sprintf("  %-6s %-12s %-10s\n", "---", "---------", "-------"))
for (a in names(check_pairs)) {
  g <- check_pairs[[a]]
  if (a %in% colnames(adt_d) && g %in% colnames(rna_d)) {
    rho <- round(cor(adt_d[, a], rna_d[, g], method = "spearman"), 3)
    verdict <- if (rho < 0.05) "SUSPECT" else "ok"
    cat(sprintf("  %-6s %-12s %-10s\n", a, rho, verdict))
  }
}

# QUESTION 6.8: Two ADT channels show rho near 0 against their own RNA gene,
# while the cross pair is high. Confirm the swap with the visual below.

DefaultAssay(sobj_filt) <- "ADT"
g <- FetchData(sobj_filt, vars = c("CD14", "CD19"))
DefaultAssay(sobj_filt) <- "RNA"
g$CD19_rna <- FetchData(sobj_filt, vars = "CD19")[, 1]  # B cell RNA marker

ggplot(g, aes(CD14, CD19, color = CD19_rna)) +
  geom_point(alpha = 0.5, size = 0.8) +
  scale_color_gradient(low = "lightgrey", high = "#991b1b") +
  labs(title    = "CD14 vs CD19 (ADT), colored by CD19 RNA",
       subtitle = "If CD19 RNA piles up on the CD14 axis, the labels are swapped",
       x = "CD14 (ADT)", y = "CD19 (ADT)", color = "CD19 RNA") +
  theme_classic(base_size = 12)
DefaultAssay(sobj_filt) <- "RNA"

# v5-safe: rebuild the ADT assay from its count matrix with corrected names.
# Conditional: only acts if the swap is actually detected (safe on clean data).
DefaultAssay(sobj_filt) <- "ADT"
adt_d <- t(LayerData(sobj_filt, layer = "data"))
rna_d <- t(LayerData(sobj_filt, assay = "RNA", layer = "data"))

swapped <- FALSE
if (all(c("CD14", "CD19") %in% colnames(adt_d))) {
  rho14 <- cor(adt_d[, "CD14"], rna_d[, "CD14"], method = "spearman")
  swapped <- is.na(rho14) || rho14 < 0.05
}

if (swapped) {
  adt_counts <- LayerData(sobj_filt, assay = "ADT", layer = "counts")
  rn  <- rownames(adt_counts)
  i14 <- which(rn == "CD14"); i19 <- which(rn == "CD19")
  rn[c(i14, i19)] <- rn[c(i19, i14)]
  rownames(adt_counts) <- rn
  # CreateAssay5Object() builds a fresh assay with only the counts layer, so
  # the [[<- replacement method warns that it differs in structure (no
  # data/scale.data layers yet) from the ADT assay it replaces. Expected and
  # harmless here; suppressWarnings() wraps the assignment itself, since the
  # notice comes from the replacement method, not from CreateAssay5Object().
  new_adt_assay <- CreateAssay5Object(counts = adt_counts)
  suppressWarnings(sobj_filt[["ADT"]] <- new_adt_assay)
  sobj_filt <- NormalizeData(sobj_filt, normalization.method = "CLR",
                             margin = 2, verbose = FALSE)
  cat("ADT labels corrected (CD14 <-> CD19) and re-normalized.\n")
} else {
  cat("No swap detected; ADT labels left unchanged.\n")
}

# Re-check
adt_d <- t(LayerData(sobj_filt, layer = "data"))
rna_d <- t(LayerData(sobj_filt, assay = "RNA", layer = "data"))
for (a in c("CD14", "CD19")) {
  rho <- round(cor(adt_d[, a], rna_d[, a], method = "spearman"), 3)
  cat(sprintf("  %-6s rho(self) = %s\n", a, rho))
}
DefaultAssay(sobj_filt) <- "RNA"

# -----------------------------------------------------------------------------
# Step 6.9 | WNN: compute ADT PCA, then integrate
# -----------------------------------------------------------------------------

# Weighted Nearest Neighbor integration learns the relative contribution of
# each modality per cell. Cells where RNA is informative receive more RNA
# weight; cells where protein is more discriminating receive more ADT weight.
# WNN requires a PCA per modality. RNA PCA exists from Block 4; we now build
# the ADT PCA.

DefaultAssay(sobj_filt) <- "ADT"

adt_features <- rownames(sobj_filt[["ADT"]])  # all 24 proteins

sobj_filt <- ScaleData(
  sobj_filt,
  features = adt_features,
  verbose  = FALSE
)

# With 24 proteins, requesting 20 PCs triggers a Seurat warning about
# computing too many singular values via truncated SVD. Two fixes both work:
# (a) reduce npcs to 15 (still captures the structure), or
# (b) pass approx = FALSE to use exact SVD.
# We use (a) because 15 PCs is enough signal for 24 proteins.
sobj_filt <- RunPCA(
  sobj_filt,
  features       = adt_features,
  npcs           = 15,
  reduction.name = "pca.adt",
  reduction.key  = "pcaADT_",
  verbose        = FALSE
)

cat("Reductions now available:", paste(SafeReductions(sobj_filt), collapse = ", "), "\n")

# Seurat expects one weight name per modality. Passing only "RNA.weight"
# triggers a warning that ADT.weight has been auto-assigned. Pass both
# explicitly to silence the notice and document the intended column names.
sobj_filt <- FindMultiModalNeighbors(
  sobj_filt,
  reduction.list       = list("pca", "pca.adt"),
  dims.list            = list(1:20, 1:15),
  modality.weight.name = c("RNA.weight", "ADT.weight"),
  verbose              = FALSE
)

sobj_filt <- RunUMAP(
  sobj_filt,
  nn.name        = "weighted.nn",
  reduction.name = "wnn.umap",
  reduction.key  = "wnnUMAP_",
  verbose        = FALSE
)

DefaultAssay(sobj_filt) <- "RNA"
cat("WNN complete. New reduction: wnn.umap\n")

# -----------------------------------------------------------------------------
# Step 6.10 | RNA-only UMAP vs WNN UMAP
# -----------------------------------------------------------------------------

# WNN does not necessarily move every cell type to a visually different
# region; UMAP layouts can rotate or mirror between runs even when the
# underlying neighborhoods barely change. The two panels below can look
# similar at first glance. What actually matters is whether the set of
# cells grouped together changed, not whether the picture looks different.
# Step 6.11c (later) checks this directly per cell-type via a cross-table;
# here, a quick clustering comparison gives a first read before that.

sobj_filt <- FindClusters(sobj_filt, resolution = 0.5,
                          cluster.name = "rna_only_clusters_preview",
                          verbose = FALSE)
rna_only_clusters <- sobj_filt$rna_only_clusters_preview

sobj_filt <- FindClusters(sobj_filt, graph.name = "wsnn", resolution = 0.5,
                          cluster.name = "wnn_clusters_preview",
                          verbose = FALSE)
wnn_clusters_preview <- sobj_filt$wnn_clusters_preview

agreement_tab <- table(RNA_only = rna_only_clusters, WNN = wnn_clusters_preview)
cat("Cluster membership: RNA-only vs WNN (rows: RNA-only clusters, cols: WNN clusters)\n")
print(agreement_tab)

# A simple agreement score: for each RNA-only cluster, what fraction of its
# cells land in the single WNN cluster that captures the most of them.
best_match_frac <- apply(agreement_tab, 1, function(row) max(row) / sum(row))
cat(sprintf("\nMedian per-cluster agreement: %.1f%% of cells stay grouped together\n",
            100 * median(best_match_frac)))

p_rna <- DimPlot(sobj_filt, reduction = "umap",
                 group.by = "singler_label_top",
                 label = TRUE, label.size = 2.5, repel = TRUE) +
  ggtitle("RNA-only UMAP") + NoLegend()

p_wnn <- DimPlot(sobj_filt, reduction = "wnn.umap",
                 group.by = "singler_label_top",
                 label = TRUE, label.size = 2.5, repel = TRUE) +
  ggtitle("WNN UMAP (RNA + ADT)") + NoLegend()

p_rna | p_wnn

# QUESTION 6.10: If the median agreement above is high (cells mostly stay
# grouped the same way) but the two UMAP layouts still look visually
# different (different rotation, different relative positions), what does
# that tell you about reading UMAP plots side by side versus comparing
# cluster membership directly?

# -----------------------------------------------------------------------------
# Step 6.11 | Per-cell modality weights
# -----------------------------------------------------------------------------

# RNA.weight close to 1 = cell is better characterized by RNA
# RNA.weight close to 0 = cell is better characterized by ADT
# RNA.weight and ADT.weight sum to 1 for each cell (FindMultiModalNeighbors
# normalizes them that way), so 0.5 is the natural reference point: below it,
# ADT is contributing more than RNA to that cell's placement in the WNN
# graph, not just "some amount" of protein information.

pct_below_half <- round(mean(sobj_filt$RNA.weight < 0.5) * 100, 1)
cat(sprintf("Cells where ADT contributes more than RNA (RNA.weight < 0.5): %.1f%%\n",
            pct_below_half))

ggplot(sobj_filt@meta.data, aes(x = RNA.weight, fill = singler_label_top)) +
  geom_histogram(bins = 40, alpha = 0.8) +
  geom_vline(xintercept = 0.5, linetype = "dashed", color = "#2c3142") +
  facet_wrap(~singler_label_top, scales = "free_y") +
  labs(title    = "Per-cell RNA modality weight from WNN",
       subtitle = "Dashed line at 0.5: left of it, ADT outweighs RNA for that cell",
       x = "RNA weight (1 = fully RNA, 0 = fully ADT)") +
  theme_classic(base_size = 10) +
  theme(legend.position = "none",
        strip.text      = element_text(size = 7))

# QUESTION 6.11: Which cell types in this dataset rely most on ADT (low RNA
# weight)? Why does that match what you know about RNA dropout for their
# defining markers?

# -----------------------------------------------------------------------------
# Step 6.11b | RNA.weight extremes per cluster: are any clusters protein-driven?
# -----------------------------------------------------------------------------

# A cluster where most cells have RNA.weight near 0 is identified almost
# entirely by protein. That can be biology (T cell subsets, where RNA dropout
# is severe) or an artifact (a protein-specific batch effect concentrated in
# one cluster).

rna_w_by_cluster <- sobj_filt@meta.data %>%
  group_by(seurat_clusters) %>%
  summarise(median_rna_w = median(RNA.weight),
            mean_rna_w   = mean(RNA.weight),
            n_cells      = n(),
            .groups = "drop") %>%
  arrange(median_rna_w)

cat("RNA.weight per cluster (sorted; low = protein-driven):\n")
print(rna_w_by_cluster)

# Flag clusters where median RNA.weight < 0.3 (protein dominates)
protein_driven <- rna_w_by_cluster$seurat_clusters[rna_w_by_cluster$median_rna_w < 0.3]
if (length(protein_driven) > 0) {
  cat("\nClusters where protein dominates (median RNA.weight < 0.3):\n")
  cat("  ", paste(protein_driven, collapse = ", "), "\n")
  cat("Inspect these clusters: are they T-cell subsets (expected) or",
      "something else?\n")
}

# QUESTION 6.11b: for the most protein-driven cluster, what fraction of its
# cells were assigned to a T-cell label by SingleR? The block below computes
# the answer and applies the decision rule.

# T-cell-like SingleR labels (any case)
t_cell_pattern <- "T[._ -]?cell|CD4|CD8|Tcell|T cell"

# Most protein-driven cluster = smallest median RNA.weight
md <- sobj_filt@meta.data
cluster_summary <- md %>%
  group_by(seurat_clusters) %>%
  summarise(median_rna_w = median(RNA.weight, na.rm = TRUE),
            n_cells      = n(),
            t_cell_frac  = mean(grepl(t_cell_pattern, singler_label,
                                      ignore.case = TRUE), na.rm = TRUE),
            .groups = "drop") %>%
  arrange(median_rna_w)

cat("\nClusters sorted by median RNA.weight (lowest = most protein-driven):\n")
print(cluster_summary)

target_cluster <- cluster_summary$seurat_clusters[1]
tfrac          <- cluster_summary$t_cell_frac[1]
mrw            <- cluster_summary$median_rna_w[1]

cat(sprintf("\nMost protein-driven cluster: %s (median RNA.weight = %.2f)\n",
            target_cluster, mrw))
cat(sprintf("Fraction of its cells with T-cell label: %.1f%%\n", tfrac * 100))

cat("\nDecision rule (concrete thresholds):\n")
cat("  t_cell_frac >= 70%  -> protein dominance reflects RNA dropout (expected,\n")
cat("                         CD4/CD8 RNA drops out heavily). No action.\n")

cat("  t_cell_frac 30-70%  -> mixed. Inspect ADT panel for this cluster: is one\n")
cat("                         specific protein driving the dominance? Run:\n")
cat("                         FeaturePlot(sobj_filt, '<protein>',\n")
cat("                                     cells = WhichCells(sobj_filt, idents = '<cluster>'))\n")
cat("  t_cell_frac < 30%   -> technical explanation. Check:\n")
cat("                         1. ADT batch (Block 6.3, panel QC)\n")
cat("                         2. CLR margin (Block 6.2; verify row means != 0)\n")
cat("                         3. Isotype background (Block 8 Scenario 4)\n")

verdict <- if (tfrac >= 0.70) {
  "RNA dropout (expected)"
} else if (tfrac >= 0.30) {
  "mixed; inspect ADT panel"
} else {
  "technical artifact; check batch/CLR/isotype"
}
cat(sprintf("\nVerdict for cluster %s: %s\n", target_cluster, verdict))

# -----------------------------------------------------------------------------
# Step 6.11c | Cell-level reannotation: WNN clustering vs RNA-only label
# -----------------------------------------------------------------------------

# Run a graph-based clustering on the WNN graph and compare it to the
# RNA-only SingleR annotation, restricted to cells where ADT dominated.

sobj_filt <- FindClusters(sobj_filt,
                          graph.name = "wsnn",
                          resolution = 0.5,
                          verbose    = FALSE)
sobj_filt$wnn_clusters <- Idents(sobj_filt)

# Cells where ADT dominated WNN (RNA.weight < 0.3)
low_rna_mask <- sobj_filt$RNA.weight < 0.3
n_low <- sum(low_rna_mask)
cat("Cells where ADT dominated WNN (RNA.weight < 0.3):", n_low,
    sprintf("(%.1f%% of total)\n", 100 * n_low / ncol(sobj_filt)))

if (n_low >= 20) {
  cat("\nCross-tab: RNA-based SingleR label vs WNN cluster (ADT-dominated cells)\n")
  print(table(
    SingleR_label = sobj_filt$singler_label[low_rna_mask],
    WNN_cluster   = sobj_filt$wnn_clusters[low_rna_mask]
  ))
}

# QUESTION 6.11c: for the row of the cross-table with the largest
# disagreement, the SingleR-RNA label and the WNN cluster diverge. Which one
# do you trust? The code below identifies that row automatically and runs
# the deciding check.

if (n_low >= 20) {
  ctab <- table(
    SingleR_label = sobj_filt$singler_label[low_rna_mask],
    WNN_cluster   = sobj_filt$wnn_clusters[low_rna_mask]
  )
  # Largest off-diagonal cell = biggest disagreement
  if (length(ctab) > 1) {
    max_cell <- arrayInd(which.max(ctab), dim(ctab))
    src_lbl <- rownames(ctab)[max_cell[1]]
    src_clu <- colnames(ctab)[max_cell[2]]
    n_conf  <- ctab[max_cell[1], max_cell[2]]
    cat(sprintf("\nLargest disagreement: %d cells labeled '%s' by SingleR-RNA\n",
                n_conf, src_lbl))
    cat(sprintf("but assigned to WNN cluster %s.\n", src_clu))

    # Deciding check: marker expression in those cells.
    # T-cell markers (RNA + ADT), B-cell markers, Mono markers
    decider_markers <- list(
      T_cell    = list(rna = c("CD3E", "CD3D"), adt = c("CD3")),
      B_cell    = list(rna = c("MS4A1", "CD79A"), adt = c("CD19", "CD20")),
      Monocyte  = list(rna = c("CD14", "LYZ"),   adt = c("CD14")),
      NK_cell   = list(rna = c("NKG7", "GNLY"),  adt = c("CD56"))
    )

    conf_cells <- which(low_rna_mask &
                        sobj_filt$singler_label == src_lbl &
                        sobj_filt$wnn_clusters  == src_clu)
    cat(sprintf("Marker detection in %d disputed cells:\n", length(conf_cells)))
    for (ct in names(decider_markers)) {
      for (mk in decider_markers[[ct]]$rna) {
        if (mk %in% rownames(sobj_filt[["RNA"]])) {
          v <- FetchData(sobj_filt, vars = mk)[conf_cells, 1]
          cat(sprintf("  %s (RNA %s): %.1f%% > 0\n", ct, mk, mean(v > 0) * 100))
        }
      }
      for (mk in decider_markers[[ct]]$adt) {
        if (mk %in% rownames(sobj_filt[["ADT"]])) {
          DefaultAssay(sobj_filt) <- "ADT"
          v <- FetchData(sobj_filt, vars = mk)[conf_cells, 1]
          DefaultAssay(sobj_filt) <- "RNA"
          cat(sprintf("  %s (ADT %s): %.1f%% > 1.0 (CLR units)\n",
                      ct, mk, mean(v > 1.0) * 100))
        }
      }
    }

    cat("\nDecision rule:\n")
    cat("  The cell type whose markers fire in >= 50% of cells (RNA + ADT\n")
    cat("  combined) wins. If two cell types tie, mark these cells as\n")
    cat("  ambiguous (likely doublets that scDblFinder missed) and remove\n")
    cat("  before downstream group comparison.\n")
  }
}

# -----------------------------------------------------------------------------
# Step 6.12 | Condition comparison: Healthy vs COVID-19
# -----------------------------------------------------------------------------

# This plot looks informative. But with 3 Healthy and 4 COVID-19 donors,
# it can be completely driven by one outlier donor.
group_props <- sobj_filt@meta.data %>%
  filter(!is.na(singler_label_top), !is.na(condition)) %>%
  group_by(condition, singler_label_top) %>%
  summarise(n = n(), .groups = "drop") %>%
  group_by(condition) %>%
  mutate(prop = n / sum(n))

ggplot(group_props, aes(x = condition, y = prop, fill = singler_label_top)) +
  geom_bar(stat = "identity", width = 0.6) +
  scale_y_continuous(labels = percent_format()) +
  labs(title    = "Cell type proportions by condition",
       subtitle = "Looks clear at the group level; check whether one donor drives it",
       x = "Condition", y = "Proportion", fill = "Cell type") +
  theme_classic(base_size = 12) +
  theme(legend.text = element_text(size = 8))

donor_props <- sobj_filt@meta.data %>%
  filter(!is.na(singler_label_top)) %>%
  group_by(donor_id, condition, singler_label_top) %>%
  summarise(n = n(), .groups = "drop") %>%
  group_by(donor_id) %>%
  mutate(prop = n / sum(n))

ggplot(donor_props, aes(x = donor_id, y = prop, fill = singler_label_top)) +
  geom_bar(stat = "identity", width = 0.7) +
  scale_y_continuous(labels = percent_format()) +
  facet_wrap(~condition, scales = "free_x") +
  labs(title    = "Cell type proportions per donor",
       subtitle = "Consistent pattern across donors within each group; not driven by one outlier",
       x = NULL, y = "Proportion (%)", fill = "Cell type") +
  theme_classic(base_size = 11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        legend.text = element_text(size = 7),
        strip.text  = element_text(face = "bold"))

# -----------------------------------------------------------------------------
# Step 6.12b | Statistical reality check: donor-level test with power note
# -----------------------------------------------------------------------------

# Per-donor proportions for ONE example cell type, tested between conditions.
# Run this for whichever label your annotation produced as the largest in
# COVID-19; the script tries to pick automatically.

# Per-donor proportions for ONE example cell type, tested between conditions.
# Run this for whichever label your annotation produced as the largest in
# COVID-19; the script tries to pick automatically. Restricted to top-N
# labels: a label held by 1-2 cells could show a spurious 100% delta between
# conditions by chance alone, which would make a meaningless "finding" look
# like the strongest signal in the dataset.

per_donor <- sobj_filt@meta.data %>%
  filter(!is.na(condition), !is.na(singler_label_top), condition %in% c("Healthy", "COVID19")) %>%
  group_by(donor_id, condition, singler_label_top) %>%
  summarise(n = n(), .groups = "drop") %>%
  group_by(donor_id, condition) %>%
  mutate(prop = n / sum(n)) %>%
  ungroup()

# Pick the cell type with the largest delta between groups for demonstration
delta_by_lbl <- per_donor %>%
  group_by(singler_label_top, condition) %>%
  summarise(mean_prop = mean(prop), .groups = "drop") %>%
  tidyr::pivot_wider(names_from = condition, values_from = mean_prop) %>%
  mutate(delta = abs(COVID19 - Healthy)) %>%
  arrange(desc(delta))

target_lbl <- delta_by_lbl$singler_label_top[1]
cat("Largest mean-proportion delta is for label:", as.character(target_lbl), "\n")
cat(sprintf("  Healthy mean: %.1f%%   COVID-19 mean: %.1f%%   delta: %.1f%%\n",
            100 * delta_by_lbl$Healthy[1],
            100 * delta_by_lbl$COVID19[1],
            100 * delta_by_lbl$delta[1]))

subset_df <- per_donor %>% filter(singler_label_top == target_lbl)
n_h <- sum(subset_df$condition == "Healthy")
n_c <- sum(subset_df$condition == "COVID19")

if (n_h >= 2 && n_c >= 2) {
  wt <- wilcox.test(prop ~ condition, data = subset_df, exact = FALSE)
  cat(sprintf("\nWilcoxon rank-sum (n=%d Healthy vs n=%d COVID-19):\n", n_h, n_c))
  cat(sprintf("  W = %g, p = %.3f\n", wt$statistic, wt$p.value))
}

# Power floor: with n=3 vs n=4 and Wilcoxon at alpha=0.05, the smallest
# detectable standardized effect size (Cohen's d) is roughly 1.5 for 80% power.
# In plain terms: only proportion differences larger than ~1.5 standard
# deviations of the donor-level distribution are detectable. Any p-value
# here is exploratory, not confirmatory.

cat("\n--- Power note ---\n")
cat("n=3 vs n=4 donors. Minimum detectable effect size (Cohen's d) ~1.5 for\n")
cat("80% power at alpha=0.05. Treat any p-value here as exploratory only.\n")

# QUESTION 6.12b: assuming the printed p-value is in the 0.05 - 0.10 range,
# what conclusion can you DRAW from this dataset? The block below applies the
# explicit decision rule for small-sample group comparison.

cat("\nDecision matrix for the observed p-value:\n")
if (exists("wt")) {
  pv <- wt$p.value
  cat(sprintf("  Observed p-value: %.3f\n", pv))
  cat("\n  p < 0.01 with n=7 donors total: STRONG signal, replicate in a\n")
  cat("                                     larger cohort before claiming.\n")
  cat("  0.01 <= p < 0.05               : Suggestive. Report effect size +\n")
  cat("                                     per-donor plot. Not confirmatory.\n")
  cat("  0.05 <= p < 0.10               : Exploratory. Cannot claim difference.\n")
  cat("                                     State the n, the direction, and the\n")
  cat("                                     effect size; flag as hypothesis-\n")
  cat("                                     generating only.\n")
  cat("  p >= 0.10                      : No evidence of difference at this n.\n")
  cat("                                     Power analysis says n>=10 per group\n")
  cat("                                     needed for the observed effect size.\n")

  # Auto-apply
  verdict <- if (pv < 0.01) {
    "STRONG (replicate in larger cohort)"
  } else if (pv < 0.05) {
    "suggestive (report with caveats)"
  } else if (pv < 0.10) {
    "exploratory (hypothesis-generating only)"
  } else {
    "no evidence of difference at this n"
  }
  cat(sprintf("\nAutomatic verdict at p = %.3f: %s\n", pv, verdict))

  # Minimum n needed for the observed effect (Cohen's d -> n via power calc)
  pooled_sd <- sd(subset_df$prop)
  obs_d     <- delta_by_lbl$delta[1] / pooled_sd
  cat(sprintf("\nObserved Cohen's d (donor-level): %.2f\n", obs_d))
  cat("Approximate n per group needed for 80%% power at alpha=0.05:\n")
  # Rough rule: n ~= 16 / d^2 for two-sample t-test, similar for Wilcoxon
  if (!is.na(obs_d) && obs_d > 0) {
    n_needed <- ceiling(16 / obs_d^2)
    cat(sprintf("  ~%d donors per group (using rule n ~ 16/d^2)\n", n_needed))
  }
}

saveRDS(sobj_filt, "outputs/sobj_annotated.rds")
cat("Annotated object saved: outputs/sobj_annotated.rds\n")

# QUESTION 6.12: How would you formally test the group-level difference given
# only 3 healthy vs 4 COVID-19 donors? What is the minimum reporting standard
# you would accept in a paper?

# =============================================================================
# BLOCK 7  |  Closing
# =============================================================================

# Final view of the annotated proportions and the R session record. The
# pitfalls reference table lives in the instructor's guide PDF.

# -----------------------------------------------------------------------------
# Step 7.1 | Four-panel summary
# -----------------------------------------------------------------------------

# Four results that together summarize the course, reusing objects already
# built in Blocks 5 and 6 rather than recomputing anything:
#   1. Final WNN UMAP with confident annotation: the end state of the RNA +
#      ADT integration.
#   2. Top canonical markers per cell type: the evidence behind the labels
#      in panel 1.
#   3. Cell type proportions by condition: the biological comparison the
#      whole pipeline was built to support.
#   4. CD4 in RNA vs ADT: the single clearest illustration from the course
#      of why the protein layer earns its place in the analysis.

p_final_umap <- DimPlot(sobj_filt, reduction = "wnn.umap",
                        group.by = "singler_label_clean",
                        label = TRUE, label.size = 2.5, repel = TRUE) +
  ggtitle("1. Final WNN UMAP (confident annotation)") + NoLegend()

p_final_markers <- DotPlot(sobj_filt,
                           features = unique(top_markers$gene),
                           idents   = setdiff(levels(Idents(sobj_filt)), "Ambiguous"),
                           group.by = "singler_label_clean") +
  RotatedAxis() +
  theme(axis.text.x = element_text(size = 7), legend.position = "none") +
  ggtitle("2. Canonical markers behind the labels")

if ("singler_label_top" %in% colnames(sobj_filt@meta.data)) {
  final_props <- sobj_filt@meta.data %>%
    filter(!is.na(condition), !is.na(singler_label_top)) %>%
    group_by(condition, singler_label_top) %>%
    summarise(n = n(), .groups = "drop") %>%
    group_by(condition) %>%
    mutate(prop = n / sum(n))

  p_final_props <- ggplot(final_props, aes(condition, prop, fill = singler_label_top)) +
    geom_bar(stat = "identity", width = 0.65) +
    scale_y_continuous(labels = percent_format()) +
    labs(x = "Condition", y = "Proportion", fill = NULL) +
    theme_classic(base_size = 10) +
    theme(legend.text = element_text(size = 6),
          legend.position = "right",
          axis.text.x = element_text(angle = 45, hjust = 1)) +
    ggtitle("3. Cell type proportions by condition")
}

DefaultAssay(sobj_filt) <- "RNA"
p_cd4_rna <- FeaturePlot(sobj_filt, "CD4", min.cutoff = "q05") +
  ggtitle("4a. CD4 (RNA)") +
  theme(plot.title = element_text(size = 10), legend.position = "none")
DefaultAssay(sobj_filt) <- "ADT"
p_cd4_adt <- FeaturePlot(sobj_filt, "CD4", min.cutoff = "q05") +
  ggtitle("4b. CD4 (ADT)") +
  theme(plot.title = element_text(size = 10), legend.position = "none")
DefaultAssay(sobj_filt) <- "RNA"
p_final_cd4 <- p_cd4_rna | p_cd4_adt

(p_final_umap | p_final_markers) / (p_final_props | p_final_cd4)

# -----------------------------------------------------------------------------
# Step 7.2 | Session info
# -----------------------------------------------------------------------------

sessionInfo()

# =============================================================================
# BLOCK 8  |  Capstone (optional, post-class): an unknown broken object
# =============================================================================

# Goal: apply the diagnostic habits from the previous blocks to a single
# object that contains four independent problems. For each scenario, run the
# diagnostic code, write your hypothesis as a comment in the block below, then
# run the fix to confirm.
#
# This is the capstone: the rest of the course taught you to spot specific
# failures one at a time. Here they all arrive in the same object, in no
# particular order, with no labels.
#
# This block comes after Closing on purpose. The live session ends at Block
# 7; this is take-home work for whoever wants more practice before the next
# session, not something to rush through in the room. Run it on your own
# time, ideally a day or two after the course, once the diagnostic habits
# from Blocks 1-6 have had a chance to settle.
#
# The instructor will release sobj_broken.rds separately. If the file is not
# present, this block is skipped (have_broken = FALSE) and the rest of the
# script still runs.

# Tries the injected object first (needed for Scenario 4), then the base.
# If neither exists, Block 8 is skipped gracefully (have_broken = FALSE)
# so the rest of the report still renders.
broken_candidates <- c("data/sobj_broken_errors.rds", "data/sobj_broken.rds")
broken_path <- broken_candidates[file.exists(broken_candidates)][1]

have_broken <- !is.na(broken_path)

if (have_broken) {
  sobj_broken <- readRDS(broken_path)
  cat("Loaded broken object from:", broken_path, "\n")
  print(sobj_broken)
  head(sobj_broken@meta.data, 3)
} else {
  cat("Broken object not found in data/. Block 8 will be skipped.\n")
  cat("To enable Block 8, place one of these files (paths relative to this .R script):\n")
  cat("  ", paste(broken_candidates, collapse = "  or  "), "\n")
  cat("Scenario 4 (ADT batch / isotype) requires the *_errors.rds from\n")
  cat("inject_course_errors.R.\n")
}

## Scenario 1  |  Wrong default assay

# Context: You received this object from a collaborator. You run the standard
# RNA preprocessing workflow. Everything executes without errors but the results
# are completely wrong: FindVariableFeatures returns fewer features than expected,
# PCA explains almost all variance in PC1, and the UMAP is a single blob.

if (have_broken) {
  cat("Default assay        :", DefaultAssay(sobj_broken), "\n")
  cat("Features active assay:", nrow(sobj_broken), "\n")
  cat("All assays           :", paste(SafeAssays(sobj_broken), collapse = ", "), "\n")
}

if (have_broken) {
  # What does FindVariableFeatures return on this object?
  test_hvg <- FindVariableFeatures(sobj_broken, nfeatures = 2000, verbose = FALSE)
  cat("Variable features found:", length(VariableFeatures(test_hvg)), "\n")
  cat("Feature names:\n")
  print(head(VariableFeatures(test_hvg), 15))
}

if (have_broken) {
  # Compare RNA and ADT feature counts
  cat("Features in RNA assay:", nrow(sobj_broken[["RNA"]]), "\n")
  cat("Features in ADT assay:", nrow(sobj_broken[["ADT"]]), "\n")
}

# > 📝 Write your hypothesis as a comment below, then run the fix to confirm.
# > What is the DefaultAssay? Why does FindVariableFeatures return so few features?
# > What would happen if you ran RunPCA and RunUMAP on this object without fixing it?
# > How would you detect this problem in a published Seurat object you downloaded?

if (have_broken) {
  cat("Before fix:", DefaultAssay(sobj_broken), "\n")

  # The DefaultAssay is set to "ADT" (24 proteins).
  # All RNA functions are running silently on 24 protein features instead
  # of 500 RNA genes. FindVariableFeatures returns 24 features because that
  # is all that exists in the active assay.

  DefaultAssay(sobj_broken) <- "RNA"
  cat("After fix :", DefaultAssay(sobj_broken), "\n")
  cat("Features  :", nrow(sobj_broken), "\n")

  test_fixed <- FindVariableFeatures(sobj_broken, nfeatures = 2000, verbose = FALSE)
  cat("Variable features now:", length(VariableFeatures(test_fixed)), "\n")
}

# Lessons learned:

# 1. `DefaultAssay()` is the first line to run on any received object.
# 2. This error is completely silent. No warning. No error. Just wrong results.
# 3. `FindVariableFeatures`, `ScaleData`, `RunPCA`, `FindMarkers` all operate
#    on the active assay. A PCA run on 24 ADT features is not a transcriptomic PCA.
# 4. Always check `DefaultAssay()` after any assay switch to confirm it reset.

## Scenario 2  |  Metadata inconsistencies

# Context: This object was assembled from samples processed at multiple sites.
# Grouping by `condition` and `donor_id` produces unexpected results. Some
# samples are missing from plots and certain donors appear duplicated.

if (have_broken) {
  cat("Metadata columns:\n")
  print(colnames(sobj_broken@meta.data))

  cat("\nNAs per column:\n")
  print(colSums(is.na(sobj_broken@meta.data)))
}

if (have_broken) {
  # Inspect the problematic columns
  cat("Unique donor_id values:\n")
  print(sort(unique(sobj_broken$donor_id)))

  cat("\nCondition table (including NAs):\n")
  print(table(sobj_broken$condition, useNA = "always"))

  cat("\nCell type NAs:", sum(is.na(sobj_broken$cell_type)), "\n")
}

if (have_broken) {
  # What does a DimPlot by condition look like?
  DimPlot(sobj_broken, group.by = "condition") +
    ggtitle("Condition plot: how many groups appear?")
}

# > 📝 Write your hypothesis as a comment below, then run the fix to confirm.
# > How many distinct problems did you find? What would the biological consequence
# > be if each went unfixed? For example: if condition labels are inconsistent,
# > what happens to a Healthy vs COVID-19 comparison?

if (have_broken) {
  sobj_meta <- sobj_broken

  # PROBLEM 1: donor_id has three different formats for the same donors
  # e.g. "Donor01", "donor1", "DONOR01" all mean the same donor
  cat("=== FIX 1: donor_id ===\n")
  sobj_meta$donor_id <- toupper(gsub("[^A-Z0-9a-z]", "", sobj_meta$donor_id))
  print(table(sobj_meta$donor_id))

  # PROBLEM 2: condition has 4 variants of 2 values
  # "COVID19", "covid19", "Covid-19", "HC", NA
  cat("\n=== FIX 2: condition ===\n")
  sobj_meta$condition_clean <- dplyr::case_when(
    grepl("covid", sobj_meta$condition, ignore.case = TRUE) ~ "COVID-19",
    grepl("healthy|HC|control", sobj_meta$condition,
          ignore.case = TRUE)                               ~ "Healthy",
    TRUE                                                    ~ NA_character_
  )
  print(table(sobj_meta$condition_clean, useNA = "always"))

  # PROBLEM 3: 200 cells have NA in cell_type
  cat("\n=== FIX 3: cell_type NAs ===\n")
  cat("NAs before:", sum(is.na(sobj_meta$cell_type)), "\n")
  sobj_meta$cell_type[is.na(sobj_meta$cell_type)] <- "Unknown"
  cat("NAs after :", sum(is.na(sobj_meta$cell_type)), "\n")
}

# Lessons learned:

# 1. `table(col, useNA = "always")` and `str(meta.data)` before every analysis.
# 2. Multi-site data almost always has formatting inconsistencies.
# 3. NA in condition: that cell is excluded from any Healthy vs COVID-19 comparison.
#    With 30 NAs, you are silently dropping 1% of cells from all group comparisons.
# 4. Case-sensitivity matters: `"COVID19" == "covid19"` is `FALSE` in R.

## Scenario 3  |  Normalization failure and batch effect

# Context: The UMAP shows clear separation by donor rather than by cell type.
# The ADT data also appears distorted. Identify both problems and fix them.

if (have_broken) {
  DimPlot(sobj_broken, group.by = "orig.ident") +
    ggtitle("Donors separate in UMAP: batch effect or biology?")
}

if (have_broken) {
  DefaultAssay(sobj_broken) <- "ADT"
  adt_data <- LayerData(sobj_broken, layer = "data")

  cat("Row means (per protein); near 0 means margin=1 was used (wrong):\n")
  print(round(rowMeans(adt_data), 4))

  cat("\nColumn means (per cell, first 10); near 0 means margin=2 (correct):\n")
  print(round(colMeans(adt_data)[1:10], 4))

  DefaultAssay(sobj_broken) <- "RNA"
}

if (have_broken) {
  rna_data <- LayerData(sobj_broken, assay = "RNA", layer = "data")
  cat("Any negative values in RNA data layer?",
      any(rna_data < 0), "\n")
  cat("(TRUE would indicate SCTransform residuals stored as 'data')\n")
  cat("\nRange of non-zero values in RNA data:\n")
  print(summary(rna_data@x))
}

# > 📝 Write your hypothesis as a comment below, then run the fix to confirm.
# > How did you determine which margin was used? What is the consequence of the
# > batch effect for any condition-level comparison? If you published the original
# > UMAP as a figure, what scientific claim would be invalidated?

if (have_broken) {
  sobj_renorm <- sobj_broken

  # STEP 1: Re-normalize RNA from counts (counts layer is untouched)
  DefaultAssay(sobj_renorm) <- "RNA"
  sobj_renorm <- NormalizeData(sobj_renorm,
    normalization.method = "LogNormalize",
    scale.factor         = 10000,
    verbose              = FALSE)
  cat("RNA re-normalized from counts.\n")

  # STEP 2: Re-normalize ADT with correct margin
  DefaultAssay(sobj_renorm) <- "ADT"
  sobj_renorm <- NormalizeData(sobj_renorm,
    normalization.method = "CLR",
    margin               = 2,
    verbose              = FALSE)
  cat("ADT re-normalized (CLR, margin=2).\n")

  # STEP 3: Rerun preprocessing
  DefaultAssay(sobj_renorm) <- "RNA"
  sobj_renorm <- FindVariableFeatures(sobj_renorm, verbose = FALSE)
  sobj_renorm <- ScaleData(sobj_renorm, verbose = FALSE)
  sobj_renorm <- RunPCA(sobj_renorm, npcs = 30, verbose = FALSE)

  # STEP 4: Harmony batch correction
  sobj_renorm <- RunHarmony(
    sobj_renorm,
    group.by.vars  = "orig.ident",
    reduction      = "pca",
    reduction.save = "harmony",
    verbose        = FALSE
  )

  sobj_renorm <- RunUMAP(sobj_renorm,
    reduction      = "harmony",
    dims           = 1:20,
    reduction.name = "umap.harmony",
    verbose        = FALSE)

  cat("Harmony applied.\n")
}

if (have_broken) {
  p_before <- DimPlot(sobj_renorm, reduction = "umap",
                      group.by = "orig.ident") +
    ggtitle("Before Harmony") + theme(legend.position = "none")

  p_after  <- DimPlot(sobj_renorm, reduction = "umap.harmony",
                      group.by = "orig.ident") +
    ggtitle("After Harmony") + theme(legend.position = "none")

  p_before | p_after
}

# Lessons learned:

# 1. Row means ~0 in ADT data is the diagnostic signature of `margin=1`. Wrong.
# 2. Column means ~0 in ADT data is the signature of `margin=2`. Correct.
# 3. The counts layer is the ground truth. Re-normalize from it; never overwrite it.
# 4. Donor separation in UMAP = batch effect. Run `DimPlot(group.by="orig.ident")`
#    before interpreting any UMAP biologically.
# 5. Harmony corrects for donor-level batch effects while preserving biological
#    variation. It requires at least 3 donors per group to be reliable.

## Scenario 4  |  ADT staining batch and isotype background (CITE-seq, 25 min)

# Context: The protein data looks technically fine: it normalizes, it plots,
# gating runs. But the ADT PCA separates cells by processing batch, not by cell
# type, and one donor shows inflated signal across every protein. Two distinct
# CITE-seq problems are present: a staining batch effect and high non-specific
# background. Neither is an RNA problem and neither throws an error.

if (have_broken) {
  if (!"adt_batch" %in% colnames(sobj_broken@meta.data)) {
    cat("This broken object has no 'adt_batch' column.\n")
    cat("Scenario 4 needs the injected object (data/sobj_broken_errors.rds\n")
    cat("from inject_course_errors.R). Skipping Scenario 4 diagnostics.\n")
  } else {
    DefaultAssay(sobj_broken) <- "ADT"
    adt_feats <- rownames(sobj_broken[["ADT"]])
    sobj_broken <- ScaleData(sobj_broken, features = adt_feats, verbose = FALSE)
    sobj_broken <- RunPCA(sobj_broken, features = adt_feats,
                          npcs = 15, reduction.name = "pca.adt.broken",
                          reduction.key = "pcaADTb_", verbose = FALSE)
    print(
      DimPlot(sobj_broken, reduction = "pca.adt.broken", group.by = "adt_batch") +
        ggtitle("ADT PCA colored by staining batch: should NOT separate")
    )
    DefaultAssay(sobj_broken) <- "RNA"
  }
}

if (have_broken) {
  # Isotype antibodies bind nothing specific. High isotype = high background
  # (sticky/dying cells, over-staining). Per-cell total ADT correlated with
  # isotype signal is the fingerprint.
  DefaultAssay(sobj_broken) <- "ADT"
  adt_counts <- LayerData(sobj_broken, layer = "counts")

  isotypes <- grep("[Ii]sotype|IgG", rownames(adt_counts), value = TRUE)
  cat("Isotype control channels found:", paste(isotypes, collapse = ", "), "\n")

  if (length(isotypes) > 0) {
    iso_total  <- Matrix::colSums(adt_counts[isotypes, , drop = FALSE])
    adt_total  <- Matrix::colSums(adt_counts)
    cat("Spearman(total ADT, isotype signal):",
        round(cor(adt_total, iso_total, method = "spearman"), 3), "\n")
    # donor_id is inconsistent in this object; use a clean donor number
    dn <- sobj_broken$donor_num
    if (is.null(dn))
      dn <- suppressWarnings(as.integer(gsub("\\D", "",
                             as.character(sobj_broken$donor_id))))
    cat("Median isotype signal by donor number:\n")
    print(round(tapply(iso_total, dn, median), 2))
  }
  DefaultAssay(sobj_broken) <- "RNA"
}

# > 📝 Write your hypothesis as a comment below, then run the fix to confirm.
# > Which donor has the highest background? Would CLR alone remove a staining
# > batch effect? If you gated CD4+ cells with one fixed threshold across both
# > batches, what would happen to the per-batch counts?

if (have_broken) {
  if (!"adt_batch" %in% colnames(sobj_broken@meta.data)) {
    cat("No 'adt_batch' column; Scenario 4 solution requires the injected object.\n")
  } else {
  # STEP 1: Flag and optionally remove high-background cells using isotypes.
  DefaultAssay(sobj_broken) <- "ADT"
  adt_counts <- LayerData(sobj_broken, layer = "counts")
  isotypes   <- grep("[Ii]sotype|IgG", rownames(adt_counts), value = TRUE)

  sobj_clean <- sobj_broken
  if (length(isotypes) > 0) {
    iso_total <- Matrix::colSums(adt_counts[isotypes, , drop = FALSE])
    cut_hi    <- quantile(iso_total, 0.95)
    keep      <- iso_total <= cut_hi
    cat("High-background cells removed (top 5% isotype):", sum(!keep), "\n")
    sobj_clean <- subset(sobj_clean, cells = colnames(sobj_clean)[keep])
  }

  # STEP 2: Re-normalize ADT (CLR margin=2) from counts.
  sobj_clean <- NormalizeData(sobj_clean, normalization.method = "CLR",
                              margin = 2, verbose = FALSE)

  # STEP 3: Correct the ADT staining batch with Harmony in protein space.
  adt_feats  <- rownames(sobj_clean[["ADT"]])
  sobj_clean <- ScaleData(sobj_clean, features = adt_feats, verbose = FALSE)
  sobj_clean <- RunPCA(sobj_clean, features = adt_feats, npcs = 15,
                       reduction.name = "pca.adt", reduction.key = "pcaADT_",
                       verbose = FALSE)
  sobj_clean <- RunHarmony(sobj_clean, group.by.vars = "adt_batch",
                           reduction = "pca.adt",
                           reduction.save = "harmony.adt", verbose = FALSE)
  cat("ADT batch corrected in protein space (harmony.adt).\n")
  DefaultAssay(sobj_clean) <- "RNA"
  }
}

# Lessons learned:

# 1. A clean-looking ADT layer can still be dominated by technical structure.
#    Always run an ADT PCA and color it by batch before trusting protein space.
# 2. Isotype controls are the ground truth for background. If total ADT tracks
#    isotype signal, the high cells are background, not biology.
# 3. CLR per cell does not remove a between-batch staining effect. Batch
#    correction (Harmony on the ADT PCA) is needed, separate from the RNA batch.
# 4. A single gating threshold across batches misclassifies cells. Gate per batch
#    or correct the batch first.

# =============================================================================
# BLOCK 9  |  Extra (optional, post-class) - cascade challenges
# =============================================================================

# Optional self-study. Each challenge below describes a chain of two or three
# linked bugs, where fixing one surfaces the next. The goal is to practise
# climbing the chain: when a downstream output is wrong, what upstream check
# would have caught it?
#
# Treat each challenge as a thought exercise. Try to write the diagnostic and
# fix as comments BEFORE running any code. The reveal at the end of each
# challenge explains the chain.

# -----------------------------------------------------------------------------
# Challenge 9.1 | The disappearing T-cell subset
# -----------------------------------------------------------------------------

# Symptom (downstream): SingleR returns "CD4 T cell" for less than 5 percent
# of cells in a PBMC dataset where flow cytometry says CD4 T cells are 25
# percent. ADT panel shows CD4 protein expressed normally.
#
# Diagnostic chain (each step surfaces the next):
#   1. Compare CD4 ADT-positive cells vs CD4 RNA-positive cells.
#   2. If ADT-positive cells are abundant but RNA-positive cells are rare,
#      the cause is RNA dropout (Block 6 territory). Stop here.
#   3. If RNA-positive cells are also abundant, check the SingleR reference:
#      does it have a distinct "CD4 T cell" label, or only "T cell"?
#   4. If the reference is correct, check DefaultAssay and the layer SingleR
#      ran on (data vs counts).
#
# Try the diagnostic on this object. Write your prediction first.

# -----------------------------------------------------------------------------
# Challenge 9.2 | The cluster that disappears after re-clustering
# -----------------------------------------------------------------------------

# Symptom: a cluster from Block 4 (RNA-only) disappears when you switch to
# WNN clustering in Block 6. The cells previously in that cluster are now
# spread across several other clusters.
#
# Diagnostic chain:
#   1. Look at RNA.weight for the cells previously in that cluster. Is
#      ADT dominating?
#   2. If ADT dominates, the cluster was held together by RNA-specific
#      variance that WNN downweights. Was that variance biological
#      (gene programme) or technical (a small batch effect on one gene)?
#   3. Cross-tab the previous cluster against canonical lineage markers.
#      If it splits cleanly along a lineage marker, WNN found a finer
#      structure. If it does not, ADT was overweighted.

# -----------------------------------------------------------------------------
# Challenge 9.3 | The healthy donor that behaves like COVID-19
# -----------------------------------------------------------------------------

# Symptom: one Healthy donor in Step 6.12 shows a per-donor cell-type
# profile much closer to the COVID-19 donors than to the other Healthy
# donors.
#
# Diagnostic chain:
#   1. QC: is this donor's nCount or percent.mt distribution different?
#   2. Annotation: did one specific cell type get over-assigned in this
#      donor (annotation drift, not biology)?
#   3. Batch: was this donor processed in a different staining run? Check
#      adt_batch if Block 8 Scenario 4 ran.
#   4. Sample swap: are the donor metadata fields consistent
#      (donor_id, condition, severity all aligned)? A sample swap during
#      labelling produces this exact symptom.

# -----------------------------------------------------------------------------
# End of optional extras.
# -----------------------------------------------------------------------------

# =============================================================================
# End of script.
# Figures are in the RStudio Plots pane. There is no HTML/PDF render step in
# this version. The instructor's guide PDF holds the talking points, expected
# answers, and pitfalls reference table.
# =============================================================================
