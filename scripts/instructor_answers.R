# Instructor answers for scSurvival_Course.R
# DO NOT SHARE WITH STUDENTS.
# Load before class: source("instructor_answers.R")
# Use:               reveal("1.2b")

.answers <- list(

  # QUESTION 1.1 (Block 1, Step 1.1)
  "1.1" = list(
    kind   = "QUESTION",
    block  = 1,
    step   = "1.1",
    prompt = "How many cells, how many features, how many assays? Which is the active (default) assay?",
    answer = "3,000 cells across 2 assays. RNA assay has 500 features, a teaching-purpose subset (not the full transcriptome). ADT assay has 24 proteins. Default assay is RNA. The 500-gene subset matters: every QC threshold copied from a 33,000-gene tutorial will be wrong. This is the first opportunity to anchor the discussion of 'tutorial defaults do not transfer'.",
    demo   = "ncol(sobj)                    # cells\nnrow(sobj[[\"RNA\"]])           # RNA features (500)\nnrow(sobj[[\"ADT\"]])           # ADT features (24)\nAssays(sobj)                  # c(\"RNA\", \"ADT\")\nDefaultAssay(sobj)            # \"RNA\"\n",
    plot   = "Console output only (no plot)"
  ),

  # QUESTION 1.2 (Block 1, Step 1.2)
  "1.2" = list(
    kind   = "QUESTION",
    block  = 1,
    step   = "1.2",
    prompt = "What is the class of the RNA assay? And the ADT assay? Why might they be the same class even though the data behave very differently?",
    answer = "Both are class `Assay5`. `Assay5` is a storage container, not a normalization specification. The container holds a layer system (counts, data, scale.data) the same way for any modality. The differences between RNA and ADT (sparse vs dense, dropout vs bimodality, `LogNormalize` vs CLR, log scale vs CLR scale) are properties of the values stored in the layers and the chosen normalization, not of the assay class. A function operating on `sobj[['ANY']]` works mechanically on both. It also means running an RNA-specific normalization on ADT does not throw a type error.",
    demo   = "class(sobj[[\"RNA\"]])    # \"Assay5\"\nclass(sobj[[\"ADT\"]])    # \"Assay5\"\n# Same class, different content. Confirm by inspecting layers:\nLayers(sobj[[\"RNA\"]])   # counts (data and scale.data appear after preprocessing)\nLayers(sobj[[\"ADT\"]])   # counts\n",
    plot   = "Console output only"
  ),

  # QUESTION 1.2b (Block 1, Step 1.2b)
  "1.2b" = list(
    kind   = "QUESTION",
    block  = 1,
    step   = "1.2b",
    prompt = "For each of the 4 sanity-proof tests in section A.9, which one is GUARANTEED to be identical regardless of analysis state, and which one DEPENDS on DefaultAssay? Why does this distinction matter when sharing code?",
    answer = "Tests 1 and 3 are guaranteed identical via `identical()`: assay access (`sobj[['RNA']]` vs `sobj@assays$RNA`) always returns the same Assay5 object, and cell names always live in `colnames(sobj)`. Test 2 (metadata column access) is more subtle than it looks: `sobj$nFeature_RNA`, `sobj@meta.data$nFeature_RNA`, and `sobj[[]]$nFeature_RNA` return the same named vector, but `FetchData(sobj, vars='nFeature_RNA')[, 1]` drops the cell-name attribute when the data.frame column is extracted with `[, 1]`. The VALUES are identical; `identical()` is not, because it also compares the names attribute. This is a good example of `identical()` being too strict for the question actually being asked: when verifying value equality across accessors, strip names (e.g. `unname()`) or compare numerically (`all(x == y)`) instead of using `identical()` directly. Test 4 is the trap with real consequences: `rownames(sobj)` returns features of the ACTIVE assay only. If a collaborator writes `marker %in% rownames(sobj)` assuming RNA, but the active assay has been set to ADT, the check fails silently for any gene that is not also a protein name. General rule when sharing or receiving code: pass `assay=` explicitly whenever a function call could resolve differently depending on the active assay, and do not assume `identical()` failing means the values differ; it can also mean only an attribute differs.",
    demo   = "# Run the 4 tests live:\nidentical(sobj@assays$RNA, sobj[[\"RNA\"]])                  # TRUE always\n# Test 2: identical() can be FALSE here even though values match,\n# because FetchData()[, 1] drops cell names that $ and [[]] keep:\nidentical(sobj$nFeature_RNA, sobj@meta.data$nFeature_RNA)  # TRUE\nv4 <- FetchData(sobj, vars = \"nFeature_RNA\")[, 1]\nidentical(sobj$nFeature_RNA, v4)                           # often FALSE (names)\nall(unname(sobj$nFeature_RNA) == unname(v4))               # TRUE (values match)\nidentical(Cells(sobj), colnames(sobj))                     # TRUE always\n# Now the trap:\nDefaultAssay(sobj) <- \"RNA\"; head(rownames(sobj))          # gene symbols\nDefaultAssay(sobj) <- \"ADT\"; head(rownames(sobj))          # protein names (different)\nDefaultAssay(sobj) <- \"RNA\"                                # restore\n",
    plot   = "Console output. rownames() result changes when DefaultAssay switches; the Test 2 identical() vs all(unname()==unname()) contrast is worth running live."
  ),

  # PUZZLE 1.2b/1 (Block 1, Step 1.2b)
  "1.2b/1" = list(
    kind   = "PUZZLE",
    block  = 1,
    step   = "1.2b",
    prompt = "Where is the original Seurat version that created this object?",
    answer = "`sobj@version`. Top-level slot that records the Seurat version that originally constructed the object, not the version currently loaded. Useful when debugging v4-to-v5 migration issues.",
    demo   = "sobj@version\npackageVersion(\"Seurat\")   # version currently loaded\n",
    plot   = "Console output"
  ),

  # PUZZLE 1.2b/2 (Block 1, Step 1.2b)
  # QUESTION 1.3a (Block 1, Step 1.3)
  "1.3a" = list(
    kind   = "QUESTION",
    block  = 1,
    step   = "1.3",
    prompt = "A typical full-transcriptome PBMC dataset shows RNA sparsity above 90%. This 500+9-gene panel is lower. What does the sparsity value you just printed tell you about gene panel size versus dropout rate?",
    answer = "Sparsity in this panel is lower than a full transcriptome mainly because the 500 genes were curated to be lineage and activation markers, which tend to be more highly and consistently expressed than the average gene in a full transcriptome (most genes in a full panel are low-expressed or cell-type-restricted, which is what drives sparsity above 90%). A smaller, curated panel is not immune to dropout: the same capture and reverse-transcription inefficiencies apply per molecule regardless of panel size. What changes is the average expression level of the genes included, not the underlying biology of dropout. This distinction matters when reading a sparsity number from any dataset: a low sparsity value can mean a curated panel of well-expressed genes, not necessarily a technically superior experiment.",
    demo   = "rna <- LayerData(sobj, assay=\"RNA\", layer=\"counts\")\nmean(rna == 0) * 100        # RNA sparsity % for this panel\n# Compare to a full-transcriptome expectation (commonly 90%+ for 10x PBMC)\n",
    plot   = "Console output"
  ),

  # QUESTION 1.3b (Block 1, Step 1.3)
  "1.3b" = list(
    kind   = "QUESTION",
    block  = 1,
    step   = "1.3",
    prompt = "The counts layer is sparse, the scale.data layer is dense. Project this to a 50,000-cell, 33,000-gene experiment: what is the memory implication, and what does it tell you about how to use ScaleData?",
    answer = "Dense double matrix: 33,000 features x 50,000 cells x 8 bytes = 13.2 GB. A sparse representation at 90% sparsity stores about 33,000 x 50,000 x 0.10 nonzeros x 16 bytes per nonzero = 2.6 GB. ScaleData centers and scales each feature, producing a dense matrix even when input was sparse. Running ScaleData on all features at this scale will exhaust RAM on any laptop. Standard practice: scale only the highly variable genes used in PCA, typically 2,000-3,000 features. The dense scaled matrix becomes 3,000 x 50,000 x 8 = 1.2 GB, manageable. Pass `features = VariableFeatures(sobj)` to ScaleData.",
    demo   = "object.size(LayerData(sobj, assay=\"RNA\", layer=\"counts\"))   # sparse\nobject.size(as.matrix(LayerData(sobj, assay=\"RNA\", layer=\"counts\")))  # dense\n# Best practice (already used in Step 4.4):\n# ScaleData(sobj, features = VariableFeatures(sobj))\n",
    plot   = "Console output"
  ),

  # QUESTION 6.0a (Block 6, Step 6.0a)
  "6.0a" = list(
    kind   = "QUESTION",
    block  = 6,
    step   = "6.0a",
    prompt = "An ADT protein with median ~0 but max in the high hundreds is typical bimodality (background cells vs stained cells). A protein with mean below 1 in every cell is something else. Which is which in the table above?",
    answer = "Healthy bimodal: median near 0, mean a few units higher, max in the hundreds. The protein is unstained in most cells and strongly positive in its target subset. Dead antibody pattern: mean below 1, max also low (under 10), pct_zero very high. Nothing rises above background because the antibody is non-functional. In the injected dataset, CD56 shows the dead pattern; CD3, CD4, CD8a, CD14, CD19 show the bimodal pattern. Examine the table sorted by mean to spot the anomaly.",
    demo   = "DefaultAssay(sobj_filt) <- \"ADT\"\nadt <- LayerData(sobj_filt, assay=\"ADT\", layer=\"counts\")\nqc <- data.frame(\n  protein  = rownames(adt),\n  median   = apply(adt, 1, median),\n  mean     = round(Matrix::rowMeans(adt), 2),\n  max      = apply(adt, 1, max),\n  pct_zero = round(Matrix::rowMeans(adt == 0)*100, 1)\n)\nqc[order(qc$mean), ]\nDefaultAssay(sobj_filt) <- \"RNA\"\n",
    plot   = "Could also use RidgePlot(sobj_filt, features=rownames(sobj_filt[['ADT']])[1:6], assay='ADT')"
  ),

  # QUESTION 6.0b (Block 6, Step 6.0b)
  "6.0b" = list(
    kind   = "QUESTION",
    block  = 6,
    step   = "6.0b",
    prompt = "Why is ADT sparsity so much lower than RNA sparsity? What does each zero mean biologically in the two modalities?",
    answer = "RNA sparsity in this 500+9-gene subset is still substantial; ADT sparsity is typically below 5%. A single mRNA molecule must be captured by an oligo-dT primer, reverse-transcribed, amplified, and sequenced. The capture and RT steps fail at a substantial rate per molecule, producing a zero where the gene was expressed. This is dropout. An ADT zero comes from antibody staining: cells are incubated with hundreds-to-thousands of antibody molecules per protein, sequencing depth for protein tags is also higher per cell. The only way to read zero is for the protein to be absent or below detection background. RNA zeros mix true absence with capture failure; ADT zeros are mostly true absence.",
    demo   = "rna <- LayerData(sobj_filt, assay=\"RNA\", layer=\"counts\")\nadt <- LayerData(sobj_filt, assay=\"ADT\", layer=\"counts\")\nmean(rna == 0) * 100        # RNA sparsity %\nmean(adt == 0) * 100        # ADT sparsity %\n# CD4 specifically:\nsum(rna[\"CD4\", ] == 0) / ncol(rna) * 100\nsum(adt[\"CD4\", ] == 0) / ncol(adt) * 100\n",
    plot   = "Console; histograms of per-cell zero rate also work for visual impact"
  ),

  # QUESTION 1.5 (Block 1, Step 1.5)
  # QUESTION 4.4c (Block 4, Step 4.4)
  "4.4c" = list(
    kind   = "QUESTION",
    block  = 4,
    step   = "4.4",
    prompt = "You inherit an object where Reductions(sobj) lists 'pca' and 'umap' but Layers(sobj[['RNA']]) shows only 'counts'. The data layer is missing. Can you trust the UMAP? What is your next move?",
    answer = "No, you cannot trust it. PCA was computed from the data layer (log-normalized), and UMAP from PCA. If the data layer has been deleted, the upstream input to PCA is gone, so you cannot verify the PCA used the right values, normalization, or features. Reductions without their source layer are unverifiable. Two next moves: (1) ask the collaborator for the object before the data layer was pruned, OR (2) re-run NormalizeData, FindVariableFeatures, ScaleData, RunPCA from the counts layer and compare your new PCA to the inherited one. Substantial disagreement means the inherited UMAP is suspect.",
    demo   = "Reductions(sobj_filt)\nLayers(sobj_filt[[\"RNA\"]])\n# Recompute and compare:\nsobj_check <- NormalizeData(sobj_filt, verbose = FALSE)\nsobj_check <- FindVariableFeatures(sobj_check, verbose = FALSE)\nsobj_check <- ScaleData(sobj_check, verbose = FALSE)\nsobj_check <- RunPCA(sobj_check, npcs = 30, verbose = FALSE)\n",
    plot   = "Side-by-side UMAPs colored by cluster if recomputed PCA is available"
  ),

  # QUESTION 1.8 (Block 1, Step 1.8)
  "1.8" = list(
    kind   = "QUESTION",
    block  = 1,
    step   = "1.8",
    prompt = "What other RNA aliases would you check for routinely in a PBMC dataset?",
    answer = "Common alias pairs: MS4A1/CD20 (B cells), NCAM1/CD56 (NK), FCGR3A/CD16 (NK and ncMonocyte), ITGAX/CD11c (DC, mono), ITGAM/CD11b (myeloid), PTPRC/CD45 (pan-immune), IL3RA/CD123 (pDC, basophil), CD3E/CD3, CD8A/CD8a (case matters: RNA upper, ADT lower), FOXP3 (Treg), FCER1A (DC). Defensive habit: keep a list of canonical PBMC markers and run `%in% rownames(sobj[['RNA']])` at the start of every annotation step.",
    demo   = "canonical <- c(\"CD3E\",\"CD3D\",\"CD8A\",\"CD4\",\"MS4A1\",\"CD79A\",\"NCAM1\",\n               \"FCGR3A\",\"CD14\",\"LYZ\",\"FOXP3\",\"FCER1A\",\"KLRD1\")\ndata.frame(marker = canonical,\n           present = canonical %in% rownames(sobj[[\"RNA\"]]))\n# Check aliases for missing ones:\naliases <- c(MS4A1=\"CD20\", NCAM1=\"CD56\", FCGR3A=\"CD16\")\n",
    plot   = "Console output"
  ),

  # QUESTION 1.2c (Block 1, Step 1.2)
  "1.2c" = list(
    kind   = "QUESTION",
    block  = 1,
    step   = "1.2",
    prompt = "FetchData(), LayerData()[gene, ], and GetAssayData()[gene, ] are all equivalent here. Why might they NOT be equivalent for normalized data instead of raw counts?",
    answer = "On the counts layer all three read raw integer values from the same underlying sparse matrix, so the result is identical. For normalized data they differ in argument defaults: `FetchData()` defaults to `layer='data'` (normalized); `LayerData()` takes `layer=` explicitly; `GetAssayData()` in newer Seurat also expects `layer=` (`slot=` is deprecated, see E2). Mismatches appear when one call defaults to data and another to counts. Always pass `layer=` explicitly.",
    demo   = "# After Block 4:\n# fd <- FetchData(sobj_filt, vars = \"CD3E\")[, 1]                          # data layer\n# lc <- LayerData(sobj_filt, assay=\"RNA\", layer=\"counts\")[\"CD3E\", ]       # counts\n# ld <- LayerData(sobj_filt, assay=\"RNA\", layer=\"data\")[\"CD3E\", ]         # data\n# all(fd == ld)   # TRUE\n# all(fd == lc)   # FALSE (different layers)\n",
    plot   = "Console output"
  ),

  # QUESTION 2.2 (Block 2, Step 2.2)
  "2.2" = list(
    kind   = "QUESTION",
    block  = 2,
    step   = "2.2",
    prompt = "If max(percent.mt) is 0 across every cell, what are the two possible explanations, and how do you tell them apart?",
    answer = "Explanation 1 (almost always): the MT- pattern matched no genes because mitochondrial symbols use a different prefix (mt-, Mt-, MTX, or a non-human reference). Diagnostic: `grep('^MT-', rownames(sobj))` returns `character(0)`. Inspect `head(rownames(sobj))` and look for the actual prefix. Explanation 2 (implausible): cells filtered upstream so aggressively that no MT transcripts remain. The pattern mismatch is the realistic case. The injected dataset renames MT- genes to MTX- to trip this exact failure.",
    demo   = "grep(\"^MT-\", rownames(sobj), value = TRUE)\ngrep(\"^mt-\", rownames(sobj), value = TRUE)\ngrep(\"^MTX\", rownames(sobj), value = TRUE)\nhead(rownames(sobj), 20)\nsummary(sobj$percent.mt)\n",
    plot   = "If percent.mt is 0 everywhere, VlnPlot(sobj, 'percent.mt', group.by='donor_id') is a flat line at 0"
  ),

  # QUESTION 2.4 (Block 2, Step 2.4)
  "2.4" = list(
    kind   = "QUESTION",
    block  = 2,
    step   = "2.4",
    prompt = "Looking at the two plots, do the high-nFeature cells and the high-percent.mt cells occupy distinct regions, or do some cells qualify as both? What would a cell flagged on both axes most likely be?",
    answer = "In most runs the two flagged groups are largely distinct: high-nFeature outliers cluster toward the right side of the nCount-vs-nFeature plot (more genes detected than the bulk of cells at a similar UMI count), while high-percent.mt outliers cluster in the upper region of the nCount-vs-percent.mt plot regardless of nFeature. Some overlap is expected and is the informative case: a cell flagged on both axes (high nFeature AND high percent.mt) is the hardest to call from a single metric. It could be a doublet that happens to also be stressed, or it could be two unrelated technical issues compounding in the same cell. The practical move is not to try to assign a single cause; flag the cell as low-confidence and let downstream steps (doublet scoring in Block 3, annotation confidence in Block 5) make the final call with more evidence.",
    demo   = "table(sobj$outlier_flag)\n# Cells flagged on both definitions (recompute the masks to check overlap):\nboth <- (sobj$nFeature_RNA > mean_feat + 2*sd_feat) & (sobj$percent.mt > mt_95)\nsum(both)\n",
    plot   = "The two FeatureScatter panels side by side, colored by outlier_flag"
  ),

  # QUESTION 2.5 (Block 2, Step 2.5)
  "2.5" = list(
    kind   = "QUESTION",
    block  = 2,
    step   = "2.5",
    prompt = "Which of the three filter parameters above is the most wrong for this 500-gene dataset, and what value would you try first?",
    answer = "`nFeature_RNA > 200` is the most wrong. The tutorial value 200 was calibrated for ~33,000 features where cells detect 2,000-3,000 genes; here the 500-gene panel produces 50-150 detected per cell, so a 200 floor removes essentially all cells. Reasonable starting threshold here is the 5th percentile of `nFeature_RNA`, typically near 30-50. `nFeature_RNA < 6000` is technically fine because no cell has near 6000 features in a 500-gene panel; it just does nothing. `percent.mt < 5` is borderline; effect depends on whether the MT pattern matched.",
    demo   = "quantile(sobj$nFeature_RNA, c(0.05, 0.50, 0.95))\nsummary(sobj$nFeature_RNA)\nlo <- quantile(sobj$nFeature_RNA, 0.05)\nhi <- quantile(sobj$nFeature_RNA, 0.95)\nsubset(sobj, subset = nFeature_RNA >= lo & nFeature_RNA <= hi)\n",
    plot   = "VlnPlot(sobj, 'nFeature_RNA', group.by='donor_id') shows where 200 sits relative to the actual distribution"
  ),

  # QUESTION 2.7 (Block 2, Step 2.7)
  "2.7" = list(
    kind   = "QUESTION",
    block  = 2,
    step   = "2.7",
    prompt = "How would your thresholds change if the dataset had ~33,000 genes instead of 500?",
    answer = "Thresholds on detected-feature counts scale roughly linearly with feature space, but thresholds on quality metrics (percent.mt, percent.ribo) do not. For 33,000 genes: nFeature_RNA lower 200-500, upper 5,000-8,000; nCount_RNA upper into tens of thousands. percent.mt is independent of feature count (a fraction of UMIs), so 10-20% upper bound is tissue-driven, not size-driven. Always inspect the distribution before fixing any number.",
    demo   = "p1 <- VlnPlot(sobj, \"nFeature_RNA\", group.by=\"donor_id\") + ggtitle(\"500-gene panel\")\nprint(p1)\n",
    plot   = "VlnPlot of nFeature by donor shows why a single hard number rarely transfers"
  ),

  # QUESTION 2.8 (Block 2, Step 2.8)
  "2.8" = list(
    kind   = "QUESTION",
    block  = 2,
    step   = "2.8",
    prompt = "Is your dataset's percent.mt distribution closer to a fraction or a percentage?",
    answer = "It is a percentage. `PercentageFeatureSet` returns values on a 0-100 scale. A real PBMC dataset typically sits between 0 and 15 percent mitochondrial. If you see values between 0 and 1, you are looking at a fraction encoding (someone divided by 100), and any threshold expressed as a percentage will be wrong. Diagnostic: `summary(sobj$percent.mt)` - if max is under 1, it is a fraction; otherwise it is a percentage.",
    demo   = "summary(sobj$percent.mt)\n",
    plot   = "VlnPlot of percent.mt; y-axis tells you which encoding you have"
  ),

  # QUESTION 3.2 (Block 3, Step 3.2)
  "3.2" = list(
    kind   = "QUESTION",
    block  = 3,
    step   = "3.2",
    prompt = "Why is it expected that doublets do NOT all sit at the very top of nCount_RNA? What does that imply about using nCount thresholds alone to remove doublets?",
    answer = "A doublet of two similar cells (two CD4 T cells, two monocytes) has roughly the same transcriptional content as one cell, just at higher capture; depending on capture efficiency and library prep, its nCount may sit anywhere inside the singlet distribution. Easy-to-detect doublets are heterotypic (T + monocyte, B + DC) because they have hybrid transcriptomes. Hard-to-detect doublets are homotypic. nCount thresholds catch only the very high tail. scDblFinder catches the transcriptional hybrids that thresholds miss. Implication: nCount filtering is necessary but not sufficient.",
    demo   = "sobj_filt$is_dbl <- sce$scDblFinder.class == \"doublet\"\nFeatureScatter(sobj_filt, \"nCount_RNA\", \"nFeature_RNA\", group.by = \"is_dbl\")\n",
    plot   = "FeatureScatter colored by doublet class; doublets distributed across the cloud, not just the top"
  ),

  # QUESTION 3.4 (Block 3, Step 3.4)
  "3.4" = list(
    kind   = "QUESTION",
    block  = 3,
    step   = "3.4",
    prompt = "Look at the per-donor bar chart. Did any single donor lose a much larger fraction of cells than the others? If so, is that donor-level QC variation, or a sign the filter thresholds were tuned around the majority of donors at the expense of one outlier?",
    answer = "Compare the before/after height for each donor rather than the overall retention rate. A donor that loses a noticeably larger fraction than the rest is worth a second look before proceeding: it could be genuine biological or technical donor-level variation (a donor with systematically lower RNA quality, more dying cells, or a different processing batch), or it could mean the data-driven thresholds in Step 2.7, which were computed across all donors pooled together, happen to fall in a range that disproportionately penalizes one donor's distribution. The fix is the same either way: if one donor's loss looks extreme, compute thresholds per donor and compare, rather than assuming a single global threshold serves every donor equally. Silently losing most of one donor's cells changes what every downstream comparison (by condition, by severity) is actually measuring.",
    demo   = "cell_counts %>% group_by(donor_id) %>%\n  summarise(before = sum(n[stage==\"Before\"]),\n            after  = sum(n[stage==\"After\"]),\n            pct_kept = round(100*after/before, 1))\n",
    plot   = "The per-donor bar chart from Step 3.4, faceted by condition"
  ),

  # QUESTION 4.1 (Block 4, Step 4.1)
  "4.1" = list(
    kind   = "QUESTION",
    block  = 4,
    step   = "4.1",
    prompt = "If integrity check fails on a real inherited object, what do you ask the collaborator for? What is the absolute minimum you need to restart the analysis from a clean state?",
    answer = "Ask for the raw `CreateSeuratObject()` output, OR the original 10x Genomics output (filtered_feature_bc_matrix), OR the original `.rds` saved before NormalizeData was first called. Minimum need: the raw counts matrix with cell and feature names matching the rest of the metadata. Anything downstream (normalized values, PCA, UMAP, clustering, annotation) can be regenerated. Without raw counts you cannot verify any quantitative claim. Make explicit: every publication-track project should preserve a checkpoint at CreateSeuratObject, before any normalization.",
    demo   = "is_integer_counts <- function(layer) {\n  v <- layer@x\n  is.numeric(v) && all(v >= 0) && all(v == round(v))\n}\nis_integer_counts(LayerData(sobj_filt, assay=\"RNA\", layer=\"counts\"))\n",
    plot   = "Console output"
  ),

  # QUESTION 4.2 (Block 4, Step 4.2)
  "4.2" = list(
    kind   = "QUESTION",
    block  = 4,
    step   = "4.2",
    prompt = "Why is LogNormalize applied to RNA but CLR (margin = 2) used for ADT? What property of each modality drives the difference?",
    answer = "RNA: variable per-cell library size (10s to 10,000s of UMIs), gene counts heavily right-skewed, very sparse. `LogNormalize` divides each cell's counts by its total, multiplies by 10,000, then takes log1p. ADT: per-cell antibody load is much more uniform across cells (every cell got the same staining mix), proteins are not sparse, and the meaningful signal is relative abundance of one protein versus others within the same cell. CLR (centered log-ratio) with margin=2 treats each cell's protein counts as a composition and normalizes within the cell, centering at zero. margin=1 would normalize across cells per protein, which removes the biological signal of which cells stain positive.",
    demo   = "summary(LayerData(sobj_filt, assay=\"RNA\", layer=\"counts\")@x)\nsummary(LayerData(sobj_filt, assay=\"ADT\", layer=\"counts\")@x)\n# Note: RNA counts 0-200s typical; ADT counts 0-1000s typical.\n",
    plot   = "Console output"
  ),

  # QUESTION 4.4 (Block 4, Step 4.4)
  "4.4" = list(
    kind   = "QUESTION",
    block  = 4,
    step   = "4.4",
    prompt = "How would you choose the number of PCs in a real dataset where the elbow plot does not have a sharp knee?",
    answer = "Combine four signals: (1) cumulative variance explained, target 70-90%; (2) JackStraw permutation test, select PCs significant at chosen alpha; (3) clustering stability across dims (rerun FindClusters at dims=10, 15, 20, 25 and compute ARI between partitions); (4) biological coherence: do all expected populations separate? Report the choice and the sensitivity analysis, not a magic number.",
    demo   = "# JackStraw is slow on full data; usable on subsamples for the same conclusion\nsobj_filt <- JackStraw(sobj_filt, num.replicate = 50, dims = 25, verbose = FALSE)\nsobj_filt <- ScoreJackStraw(sobj_filt, dims = 1:25)\nJackStrawPlot(sobj_filt, dims = 1:25)\n",
    plot   = "JackStrawPlot: PCs above the diagonal are significant"
  ),

  # QUESTION 4.4a (Block 4, Step 4.4a)
  "4.4a" = list(
    kind   = "QUESTION",
    block  = 4,
    step   = "4.4a",
    prompt = "How many PCs in this dataset carry more than 1 percent of total variance?",
    answer = "Computed in the script. Typically 10-15 PCs carry >1% variance in this dataset; the elbow gives roughly the same number. If they disagree by more than a factor of 2, either the elbow is being misread or the dataset has unusual variance structure.",
    demo   = "pca_var <- sobj_filt@reductions$pca@stdev^2\npct <- pca_var / sum(pca_var) * 100\nsum(pct > 1)\nplot(pct, type=\"b\", xlab=\"PC\", ylab=\"% variance\")\n",
    plot   = "Variance-per-PC scatter; flattening point is the floor for dims"
  ),

  # QUESTION 4.4b (Block 4, Step 4.4b)
  "4.4b" = list(
    kind   = "QUESTION",
    block  = 4,
    step   = "4.4b",
    prompt = "At what donor R^2 would you switch to Harmony in your own data? What is the trade-off?",
    answer = "Thresholds (in the script): R^2 < 0.10 = no integration; 0.10-0.30 = borderline, integrate only if cell types are also separated by donor; >0.30 = integrate. Trade-off: integration removes technical donor variance so cell types pool across donors. It also removes TRUE biological inter-donor variance: if one donor genuinely lacks a cell type, integration may merge their cells with cells from other donors that DO have it, hiding the difference. After integrating, always check that per-donor cell type proportions remain plausible. This dataset's R^2 falls in the low-to-borderline range, so clustering and annotation proceed without Harmony through Block 5. Step 5.4e runs Harmony anyway and Step 5.4f builds a 4-panel comparison so students see directly whether integration would have changed anything, rather than taking the R^2 threshold on faith.",
    demo   = "pc_coords <- Embeddings(sobj_filt, \"pca\")[, 1:5]\nsapply(1:5, function(i)\n  summary(lm(pc_coords[, i] ~ sobj_filt$donor_id))$r.squared)\n",
    plot   = "DimPlot(sobj_filt, reduction='pca', group.by='donor_id') side by side with group.by='condition'; see also the 4-panel comparison in Step 5.4f"
  ),

  # QUESTION 4.6 (Block 4, Step 4.6)
  "4.6" = list(
    kind   = "QUESTION",
    block  = 4,
    step   = "4.6",
    prompt = "Lower resolution gives fewer, larger clusters; higher resolution gives more, smaller ones. Neither is intrinsically right. What evidence do you use to defend a chosen resolution?",
    answer = "Three things: (1) biological coherence: each cluster has a distinguishable marker profile, defensible against the literature; (2) stability across nearby resolutions: clusters should not fragment dramatically on a small perturbation; ARI between resolutions 0.4 and 0.6 should be high; (3) downstream sanity: cluster count matches expectations for the tissue (PBMC at 3,000 cells: 8-14 clusters is reasonable; 25 is too many; 4 is too few). Show a clustree-style visualization across a resolution sweep and report which resolution and why.",
    demo   = "for (r in c(0.3, 0.5, 0.8, 1.2)) {\n  sobj_filt <- FindClusters(sobj_filt, resolution = r, verbose = FALSE)\n  cat(sprintf(\"res=%.1f -> %d clusters\\n\", r, length(unique(Idents(sobj_filt)))))\n}\n",
    plot   = "If clustree is installed: clustree(sobj_filt, prefix='RNA_snn_res.')"
  ),

  # QUESTION 4.7 (Block 4, Step 4.7)
  "4.7" = list(
    kind   = "QUESTION",
    block  = 4,
    step   = "4.7",
    prompt = "If donors visibly separate on the UMAP, is that batch effect or biology? What additional information would help you decide?",
    answer = "Cannot tell from UMAP alone. Two checks: (1) do donors cluster within shared cell-type regions or do they form their own regions? Same cell types in same UMAP region across donors = expected biology; same cell types in DIFFERENT UMAP regions per donor = batch. Color UMAP by cell type and by donor on the same plot. (2) Compute the PC1 R^2 against donor_id (see 4.4b); if high, batch dominates the embedding.",
    demo   = "DimPlot(sobj_filt, reduction=\"umap\", group.by=\"donor_id\") |\n  DimPlot(sobj_filt, reduction=\"umap\", group.by=\"singler_label\")\n",
    plot   = "Side-by-side UMAPs make the call obvious in most cases"
  ),

  # QUESTION 5.2 (Block 5, Step 5.2)
  "5.2" = list(
    kind   = "QUESTION",
    block  = 5,
    step   = "5.2",
    prompt = "How many of the rows in this heatmap show any real signal (a cluster of cells with a clearly bright cell)? What does the rest of the rows tell you about how many of the labels printed above are likely noise?",
    answer = "On this dataset, typically only 5 to 8 of the roughly 37 rows show a clear bright block: a clean separation where one column-group of cells lights up brightly for that row and stays dark for the rest. Those rows correspond to the real cell populations actually present in PBMC: T cells, B cells, monocytes, NK cells, and a few others. The remaining rows are close to uniformly dim across every cell. A dim row does not mean SingleR made an error; it means no cell in this dataset scored highly against that reference label, which is expected for labels like Hepatocytes or Neurons in a blood sample. The practical reading: if a label's row in this heatmap never lights up brightly anywhere, any cell assigned that label by the raw classifier is suspect, and that is exactly why so many distinct values appeared in the 'Cell type distribution' printed in Step 5.2. The dim rows are the visual evidence that motivates collapsing low-frequency labels together in Step 5.2b, rather than trusting all of them as equally real populations.",
    demo   = "# Count distinct labels with at least one confidently assigned cell\nlabel_tab <- sort(table(sobj_filt$singler_label), decreasing = TRUE)\nprint(label_tab)\n# Compare to how many rows visually 'light up' in the heatmap above\n",
    plot   = "The full plotScoreHeatmap from Step 5.2 (37 rows); count how many show a bright block versus uniform dimness"
  ),

  # QUESTION 5.2b (Block 5, Step 5.2b)
  "5.2b" = list(
    kind   = "QUESTION",
    block  = 5,
    step   = "5.2b",
    prompt = "Look at the labels collapsed into \"Other\" (the rows of label_tab beyond rank 8). Are any of them biologically plausible for PBMC (e.g. \"Platelets\", \"DC\") or all implausible (e.g. \"Hepatocytes\", \"Neurons\")? What would you do differently if a plausible label got collapsed away?",
    answer = "On this dataset, HumanPrimaryCellAtlasData typically returns 20+ labels for a 500-gene PBMC panel. Most of what falls outside the top 8 is biologically implausible for blood (Hepatocytes, Fibroblasts, Endothelial_cells, Neurons, Gametocytes, Astrocytes) and reflects low-confidence noise from a reference that covers many tissues, not a PBMC-specific signal. A few collapsed labels CAN be biologically plausible but rare in this cohort (Platelets, DC, Pro-B_cell subsets) - those are real minority populations, just small ones. The top-N consolidation is a visualization aid, not a correction to the annotation itself: `singler_label` (uncollapsed) is preserved in the metadata for exactly this reason. If a plausible rare population matters to your analysis (e.g. you are specifically studying platelets or DCs), raise TOP_N_LABELS, or keep using `singler_label` directly for that one analysis instead of `singler_label_top`.",
    demo   = "# Inspect what fell into \"Other\":\nlabel_tab <- sort(table(sobj_filt$singler_label), decreasing = TRUE)\nprint(label_tab[-(1:8)])\n# Raise TOP_N_LABELS if a plausible rare population is being collapsed:\n# TOP_N_LABELS <- 12\n",
    plot   = "Console output (table of collapsed labels and their counts)"
  ),

  # QUESTION 5.4 (Block 5, Step 5.4)
  "5.4" = list(
    kind   = "QUESTION",
    block  = 5,
    step   = "5.4",
    prompt = "Which slots are still empty / unchanged in the ADT assay? What does that tell you about what Block 6 needs to do first?",
    answer = "ADT still has only the counts layer. No data layer (no normalization), no scale.data, no var.features, no reductions referencing ADT. Block 6 must build the ADT side from scratch: normalize (CLR margin=2), then either use it directly for plots and gating (no scale.data needed) or run RunPCA on the ADT counts before WNN.",
    demo   = "Layers(sobj_filt[[\"ADT\"]])\nReductions(sobj_filt)\n# Next: DefaultAssay(sobj_filt) <- \"ADT\"; NormalizeData(method=\"CLR\", margin=2)\n",
    plot   = "Console output"
  ),

  # QUESTION 5.4b (Block 5, Step 5.4b)
  # QUESTION 5.4a (Block 5, Step 5.4a)
  "5.4a" = list(
    kind   = "QUESTION",
    block  = 5,
    step   = "5.4a",
    prompt = "Which annotated cell type has the lowest detection rate of its canonical marker? Is the explanation dropout or misannotation?",
    answer = "Computed in the script. The lowest rate usually appears for a T-cell label expressing CD3E or CD3D; CD3E RNA dropout in PBMC is often 30-50%, so detection rates between 25-50% indicate dropout (recoverable in Block 6 via ADT CD3). A detection rate below 25% for any marker is more likely misannotation. Decision thresholds: >=50% ok; 25-50% dropout-explained, verify with ADT; <25% suspect, revisit annotation.",
    demo   = "lbl_mask <- sobj_filt$singler_label == \"T_cells\"\nmean(FetchData(sobj_filt, \"CD3E\")[lbl_mask, 1] > 0) * 100\n",
    plot   = "Console output"
  ),

  # QUESTION 5.4e (Block 5, Step 5.4e)
  "5.4e" = list(
    kind   = "QUESTION",
    block  = 5,
    step   = "5.4e",
    prompt = "Is the change in donor R^2 large or close to zero in this dataset? Does that match what the Step 4.4b decision predicted? If you ran this on a dataset with R^2 above 0.30, what change would you expect to see in this same table?",
    answer = "On this dataset the donor R^2 was already low to borderline before Harmony (Step 4.4b), so the change after Harmony should also be small: Harmony has little donor-driven variance left to remove, which is exactly what the Step 4.4b decision to skip integration predicted. This is the confirming case: if the change had turned out large here, it would mean the original PC1/PC2-only R^2 check missed a donor effect living in later PCs, and the decision not to integrate would have been wrong. On a dataset where the pre-Harmony R^2 was above 0.30 (donor effect dominant), the expected pattern is a large drop in R^2 after Harmony (often falling toward 0.05-0.15) on the dimensions Harmony was told to correct, paired with a visibly different cell-type layout in the comparison panel: that combination is what integration succeeding actually looks like in numbers, not just in a UMAP that looks nicer.",
    demo   = "print(r2_comparison, row.names = FALSE)\n# A large negative 'change' column value means Harmony removed donor signal.\n# A change near zero means there was little donor signal to remove.\n",
    plot   = "The r2_comparison table; pair with the 4-panel UMAP comparison in Step 5.4f"
  ),

  # QUESTION 5.4c (Block 5, Step 5.4c)
  "5.4c" = list(
    kind   = "QUESTION",
    block  = 5,
    step   = "5.4c",
    prompt = "Cells marked Ambiguous are still in sobj_filt and still count toward ncol(sobj_filt). Why keep them instead of deleting them outright? What would deleting them silently change about cell counts reported in every plot from here on?",
    answer = "Keeping them preserves an honest record of what the annotation pipeline actually produced: a real fraction of cells could not be confidently typed by RNA alone, and that fraction is itself informative (it often shrinks once ADT is added in Block 6, which is the whole point of the CITE-seq workflow). Deleting them at this stage would silently shrink ncol(sobj_filt), which changes every downstream denominator: QC summaries, per-condition proportions, per-donor cell counts, and any percentage calculation would all be computed over a smaller, undocumented population. A reader of a later plot would have no way to know cells were dropped here unless the deletion were stated explicitly every time. Marking and filtering only at the plotting step (Step 5.4d) keeps the object's cell count meaningful throughout the rest of the script, and the Ambiguous label itself becomes a result worth reporting (for example, in Block 6 you can check whether ADT resolves some of these cells).",
    demo   = "table(sobj_filt$singler_label_clean == \"Ambiguous\")\nncol(sobj_filt)  # unchanged regardless of how many cells are Ambiguous\n",
    plot   = "Console output"
  ),

  # QUESTION 5.4f (Block 5, Step 5.4f)
  "5.4f" = list(
    kind   = "QUESTION",
    block  = 5,
    step   = "5.4f",
    prompt = "Compare panels 2 and 3. If the cell-type layout looks nearly identical before and after Harmony, what does that confirm about the Step 4.4b decision not to integrate? If it looks different, which panel would you trust for the rest of the analysis, and why?",
    answer = "If panels 2 and 3 look nearly identical, that confirms the Step 4.4b read of the data: the donor effect on PC1/PC2 was already low (R^2 < 0.10-0.30 range), so Harmony has little work to do and converges to essentially the same cell-type layout. That is the expected, reassuring outcome here, and panel 4 (Harmony UMAP by donor) should still show donors reasonably mixed within each cell-type region, the same as before integration. If panels 2 and 3 looked clearly different instead, that would mean the PC1/PC2 R^2 from Step 4.4b under-estimated a donor effect living in later PCs, and the right move is to trust the Harmony-integrated panel (3) for downstream analysis, since it actively corrects for batch rather than just measuring it on two dimensions. Either way, the comparison panel is the check that validates (or overturns) an integration decision made earlier from a partial diagnostic.",
    demo   = "# Quantify the visual comparison instead of eyeballing it:\ntable(sobj_filt$singler_label_clean, useNA = \"ifany\")\n# Compare cluster composition before/after Harmony using adjusted Rand index\n# if you want a number instead of a plot:\n# mclust::adjustedRandIndex(cluster_labels_no_harmony, cluster_labels_harmony)\n",
    plot   = "The 2x2 comparison panel itself (Step 5.4f) is the answer; no separate plot needed"
  ),

  # QUESTION 5.4g (Block 5, Step 5.4g)
  "5.4g" = list(
    kind   = "QUESTION",
    block  = 5,
    step   = "5.4g",
    prompt = "Pick one cell type from the DotPlot. Does its top marker match a canonical marker you already know for that lineage (Step 1.8)? If not, is that a red flag about the annotation, or a finding outside the canonical list that is worth investigating further?",
    answer = "For most major lineages in this dataset the top DE marker should match a canonical gene from the Step 1.8 list: CD3D/CD3E for T cells, MS4A1/CD79A for B cells, CD14/LYZ for monocytes, NKG7/GNLY for NK cells. A match is reassuring: independent statistical evidence (DE testing) agrees with prior biological knowledge (canonical markers), which is the strongest form of validation available without an orthogonal assay. A mismatch is more interesting than alarming by itself: first rule out technical explanations (is the canonical gene even in the 500-gene panel? Check rownames(sobj_filt[['RNA']])), then consider whether the cluster is a known but less-textbook subtype (e.g. a Treg subset whose top marker is FOXP3 rather than generic CD3 genes) before treating it as a red flag about the annotation itself.",
    demo   = "# Check whether a canonical marker even exists in this 500-gene panel\ncanonical_check <- c(\"CD3D\",\"CD3E\",\"MS4A1\",\"CD79A\",\"CD14\",\"LYZ\",\"NKG7\",\"GNLY\")\ncanonical_check[!canonical_check %in% rownames(sobj_filt[[\"RNA\"]])]\n# Then compare against the DotPlot's top marker for the cell type in question\ntop_markers[top_markers$cluster == \"T_cells\", ]\n",
    plot   = "The DotPlot from Step 5.4g; cross-reference visually against canonical markers"
  ),

  # QUESTION 6.1 (Block 6, Step 6.1)
  "6.1" = list(
    kind   = "QUESTION",
    block  = 6,
    step   = "6.1",
    prompt = "Does the double-positive count match what you expect biologically (~0% in PBMC), or does it suggest unresolved doublets even after scDblFinder?",
    answer = "Expected near zero (under 1% of cells). True double-positive CD4+/CD8+ cells are rare in PBMC (some MAIT and gamma-delta T cells). More than 1-2% and the cells are likely doublets that scDblFinder missed (homotypic T-cell doublets). Cross-check against scDblFinder doublet class; if many double-positives are not flagged as doublets, increase the scDblFinder threshold or remove the double-positives manually before annotating T-cell subsets.",
    demo   = "adt <- LayerData(sobj_filt, assay=\"ADT\", layer=\"counts\")\ncd4 <- adt[\"CD4\", ] > 5\ncd8 <- adt[\"CD8a\", ] > 5\ntable(double_pos = cd4 & cd8, scDbl = sobj_filt$is_dbl)\n",
    plot   = "Console table; small counts in (TRUE, FALSE) cell are the suspicious cases"
  ),

  # PUZZLE 6.1/A (Block 6, Step 6.1)
  "6.1/A" = list(
    kind   = "PUZZLE",
    block  = 6,
    step   = "6.1",
    prompt = "Without normalizing yet, which protein has the highest raw variance across cells? Lineage marker or activation marker?",
    answer = "Lineage markers usually win: CD4, CD8a, CD14, CD19, CD3 have the highest raw variance because they go from background-low in non-target cells to very high in target cells. Activation markers like CD69, HLADR, CD25 have lower variance because they are expressed at moderate levels in many cells. If an activation marker tops the list, the dataset may be enriched for activated cells, or one antibody is behaving unusually.",
    demo   = "adt <- LayerData(sobj_filt, assay=\"ADT\", layer=\"counts\")\nvar_per_prot <- apply(adt, 1, var)\nsort(var_per_prot, decreasing = TRUE)[1:5]\n",
    plot   = "Console output"
  ),

  # PUZZLE 6.1/B (Block 6, Step 6.1)
  "6.1/B" = list(
    kind   = "PUZZLE",
    block  = 6,
    step   = "6.1",
    prompt = "How many cells are positive for BOTH CD4 and CD8a in raw counts (>5 each)? Expected near zero.",
    answer = "Double-positive CD4+/CD8a+ in raw ADT should be near zero in PBMC. More than 1-2% of cells: suspect doublets that scDblFinder missed, or antibody spillover. Investigate via nCount_RNA and total ADT for the suspect cells.",
    demo   = "cd4 <- adt[\"CD4\", ] > 5\ncd8 <- adt[\"CD8a\", ] > 5\nsum(cd4 & cd8)\ntable(cd4 & cd8, sobj_filt$is_dbl)\n",
    plot   = "Console output"
  ),

  # QUESTION 6.10 (Block 6, Step 6.10)
  "6.10" = list(
    kind   = "QUESTION",
    block  = 6,
    step   = "6.10",
    prompt = "If the median agreement above is high (cells mostly stay grouped the same way) but the two UMAP layouts still look visually different (different rotation, different relative positions), what does that tell you about reading UMAP plots side by side versus comparing cluster membership directly?",
    answer = "It means the visual comparison and the cluster-membership comparison are answering different questions, and only one of them is actually about whether WNN changed the result. UMAP is a 2D projection chosen independently each time it is run; rotation, mirroring, and relative spacing between blobs can differ between two UMAP runs even on the exact same underlying neighborhood graph, because UMAP's layout optimization has no fixed orientation to anchor to. High agreement in the cluster cross-table means the cells that were grouped together under RNA-only are still grouped together under WNN, which is the substantive claim. A side-by-side UMAP comparison is useful for a first visual impression and for spotting gross differences (a population that splits or merges), but it is not a reliable way to judge subtle changes, and two UMAPs that look different are not, by themselves, evidence that WNN changed anything about which cells belong together.",
    demo   = "print(agreement_tab)\nmedian(best_match_frac)   # fraction of cells staying grouped together\n",
    plot   = "The agreement_tab cross-table and the median agreement number, alongside the two UMAP panels"
  ),

  # QUESTION 6.11 (Block 6, Step 6.11)
  "6.11" = list(
    kind   = "QUESTION",
    block  = 6,
    step   = "6.11",
    prompt = "Which cell types in this dataset rely most on ADT (low RNA weight)? Why does that match what you know about RNA dropout for their defining markers?",
    answer = "CD4 T cells and CD8 T cells, by a wide margin. Their defining markers (CD4, CD8A) have the worst RNA dropout. B cells (MS4A1, CD79A) and monocytes (CD14, LYZ) have stronger RNA signal and rely less on ADT. NK cells (NKG7, GNLY, NCAM1) are intermediate. The histogram facet of RNA.weight by cell type makes this concrete, and the dashed line at RNA.weight = 0.5 marks the point where ADT outweighs RNA for that cell, not just contributes some amount of information.",
    demo   = "mean(sobj_filt$RNA.weight < 0.5) * 100   # cells where ADT outweighs RNA\nggplot(sobj_filt@meta.data, aes(x = RNA.weight, fill = singler_label_top)) +\n  geom_histogram(bins = 40) + geom_vline(xintercept = 0.5, linetype = \"dashed\") +\n  facet_wrap(~singler_label_top)\n",
    plot   = "Histogram of RNA.weight faceted by cell type, with a dashed line at 0.5. T cells peak left of the line, monocytes peak right of it"
  ),

  # QUESTION 6.11b (Block 6, Step 6.11b)
  "6.11b" = list(
    kind   = "QUESTION",
    block  = 6,
    step   = "6.11b",
    prompt = "For the most protein-driven cluster, what fraction of its cells were assigned to a T-cell label by SingleR?",
    answer = "Computed in the script. Decision thresholds: >=70% T-cell -> expected RNA-dropout behavior, no action; 30-70% -> mixed, inspect ADT proteins driving the dominance; <30% -> technical artifact, check ADT batch, CLR margin, isotype background. The script applies the rule automatically and prints the verdict.",
    demo   = "md <- sobj_filt@meta.data\ncs <- aggregate(RNA.weight ~ seurat_clusters, data = md, FUN = median)\ncs[order(cs$RNA.weight), ]\n",
    plot   = "Console table"
  ),

  # QUESTION 6.11c (Block 6, Step 6.11c)
  "6.11c" = list(
    kind   = "QUESTION",
    block  = 6,
    step   = "6.11c",
    prompt = "For the row of the cross-table with the largest disagreement, which annotation do you trust?",
    answer = "Decision rule from the script: cross-check marker expression in the disputed cells. The cell type whose markers (RNA + ADT) fire in >=50% of cells wins. If two cell types tie, mark the cells as ambiguous (likely undetected doublets) and exclude them from downstream group comparisons. Do NOT pick the WNN label by default; do NOT pick the SingleR label by default. Let the markers adjudicate.",
    demo   = "low_rna_mask <- sobj_filt$RNA.weight < 0.3\ntab <- table(sobj_filt$singler_label[low_rna_mask],\n             sobj_filt$wnn_clusters[low_rna_mask])\ntab\n",
    plot   = "Console cross-table"
  ),

  # QUESTION 6.12 (Block 6, Step 6.12)
  "6.12" = list(
    kind   = "QUESTION",
    block  = 6,
    step   = "6.12",
    prompt = "How would you formally test the group-level difference given only 3 healthy vs 4 COVID-19 donors? What is the minimum reporting standard you would accept in a paper?",
    answer = "Donor as the unit of analysis. Compute per-donor cell-type proportions (one number per donor per cell type), Wilcoxon rank-sum across donors. With n=3 vs n=4 power is minimal: only effect sizes near Cohen's d=1.5 are detectable at alpha=0.05. Minimum reporting standard: plot per-donor proportions (Step 6.12 does this), state the n, and explicitly mark the analysis as exploratory unless effect sizes are very large. Group-level barplots without per-donor backing should not appear in a paper.",
    demo   = "subset_df <- per_donor %>% filter(singler_label == target_lbl)\nwilcox.test(prop ~ condition, data = subset_df, exact = FALSE)\nprint(subset_df[, c(\"donor_id\", \"condition\", \"prop\")])\n",
    plot   = "Per-donor proportion boxplot with individual donors as points, colored by condition"
  ),

  # QUESTION 6.12b (Block 6, Step 6.12b)
  "6.12b" = list(
    kind   = "QUESTION",
    block  = 6,
    step   = "6.12b",
    prompt = "Assuming the printed p-value is in the 0.05 - 0.10 range, what conclusion can you draw?",
    answer = "Exploratory only. With n=7 donors total, a p-value in this range is hypothesis-generating and cannot support a published claim of difference. Report: n per group, direction of the difference, effect size, statement that confirmatory analysis requires a larger cohort. The script estimates the n needed for 80% power at the observed effect size (rule of thumb n ~ 16 / d^2).",
    demo   = "# See Step 6.12b in the script: it auto-applies the decision matrix.\n",
    plot   = "Console output with automatic verdict"
  ),

  # QUESTION 6.2 (Block 6, Step 6.2)
  "6.2" = list(
    kind   = "QUESTION",
    block  = 6,
    step   = "6.2",
    prompt = "Why is the row mean a useful diagnostic? What would the row means look like if margin had been set to 1?",
    answer = "After CLR with margin=2 (per cell across proteins), column means are ~0 by construction (each cell's protein values were centered). Row means (per protein across cells) carry the biological signal of which proteins are abundant and should NOT be near zero. They reflect dataset-wide protein abundance differences. If margin=1 was used instead (per protein across cells), row means would be near zero. That is the wrong-margin fingerprint. Cenario 3 of Block 7 contains exactly this failure.",
    demo   = "sobj_filt <- NormalizeData(sobj_filt, assay=\"ADT\",\n                           normalization.method=\"CLR\", margin=2)\nd <- LayerData(sobj_filt, assay=\"ADT\", layer=\"data\")\nround(rowMeans(d), 3)\nround(colMeans(d), 3)[1:5]\n",
    plot   = "Console output; row means != 0, col means ~ 0"
  ),

  # QUESTION 6.3 (Block 6, Step 6.3)
  "6.3" = list(
    kind   = "QUESTION",
    block  = 6,
    step   = "6.3",
    prompt = "One protein has near-zero counts in essentially every cell while its RNA counterpart is clearly expressed in a defined cluster. Which protein, and which cell type does it mark?",
    answer = "In the injected dataset: CD56 (encoded by NCAM1). CD56 marks NK cells. With CD56 ADT dead, any NK-cell annotation based on ADT alone fails. The diagnostic chunk compares CD56 ADT (near-zero) with NCAM1 RNA (clear signal in the NK cluster) and surfaces the inconsistency. Habit: always cross-check the lowest-mean ADT proteins against their RNA counterparts.",
    demo   = "FeaturePlot(sobj_filt, c(\"CD56\", \"NCAM1\"), reduction = \"umap\")\n",
    plot   = "FeaturePlot panel: CD56 ADT (flat) next to NCAM1 RNA (positive in a cluster)"
  ),

  # QUESTION 6.6 (Block 6, Step 6.6)
  "6.6" = list(
    kind   = "QUESTION",
    block  = 6,
    step   = "6.6",
    prompt = "For a marker with 80% dropout, what fraction of cells would be misannotated by an RNA-only workflow?",
    answer = "Single-marker decisions: up to 80% misannotated for cells whose RNA dropped out. The script prints the arithmetic for 1, 2, 3, 5 independent markers (each with 80% dropout): rule P(all drop) = 0.8^N. So 64%, 51%, 33% with 2, 3, 5 markers respectively. Annotation should never depend on a single marker for a high-dropout gene. ADT rescues because protein dropout is near zero.",
    demo   = "for (n in 1:5) cat(sprintf(\"N=%d -> %.1f%% still miss\\n\", n, 0.8^n*100))\n",
    plot   = "Console output"
  ),

  # QUESTION 6.7b (Block 6, Step 6.7b)
  "6.7b" = list(
    kind   = "QUESTION",
    block  = 6,
    step   = "6.7b",
    prompt = "Both FeaturePlots rendered, and at a glance they can look almost the same. The zero-rate numbers printed above tell a different story. If you saved one of these plots as a figure for a paper without checking DefaultAssay first, which one would you have, and would a reader be able to tell from the figure alone that 'CD4' meant something different in each panel?",
    answer = "You would have whichever assay was active at the moment of the plot call, and a reader could not tell which one from the figure alone: the plot title says only 'CD4', the axes are identical UMAP coordinates, and min.cutoff='q05' rescales each panel's own color gradient independently, so a sparse RNA signal and a denser ADT signal end up stretched across visually similar-looking scales. This is exactly why the zero-rate numbers matter: they show the real difference in what fraction of cells read as positive in each modality, a difference the rescaled color gradient hides. The published figure could silently show CD4 RNA when CD4 protein was intended, or vice versa, and nothing in the image itself would flag the mismatch. Habit: set DefaultAssay explicitly at the top of any plotting block, AND/OR pass the assay inside the call; better still, edit the plot title to include the assay name and consider reporting the zero rate alongside the figure so the modality difference is documented, not just visible to whoever already knows to look for it.",
    demo   = "DefaultAssay(sobj_filt) <- \"RNA\"\nmean(LayerData(sobj_filt, layer=\"counts\")[\"CD4\", ] == 0) * 100   # RNA zero rate\nDefaultAssay(sobj_filt) <- \"ADT\"\nmean(LayerData(sobj_filt, layer=\"counts\")[\"CD4\", ] == 0) * 100   # ADT zero rate\nDefaultAssay(sobj_filt) <- \"RNA\"\nFeaturePlot(sobj_filt, \"CD4\") + ggtitle(\"CD4 protein (ADT)\")\nFeaturePlot(sobj_filt, \"CD4\") + ggtitle(\"CD4 mRNA (RNA)\")\n",
    plot   = "Two FeaturePlots side by side, one per assay, distinct titles; the zero-rate numbers explain what the plots alone do not show"
  ),

  # QUESTION 6.8 (Block 6, Step 6.8)
  "6.8" = list(
    kind   = "QUESTION",
    block  = 6,
    step   = "6.8",
    prompt = "Two ADT channels show rho near 0 against their own RNA gene, while the cross pair is high. Confirm the swap with the visual.",
    answer = "Spearman rho between each ADT protein and its RNA counterpart across cells. Healthy markers show rho 0.3-0.7. Swap fingerprint: ADT_X vs RNA_X near zero AND ADT_X vs RNA_Y high; same with X,Y reversed. In the injected dataset CD14 and CD19 ADT rownames are swapped. The fix block rebuilds the ADT assay with rownames re-swapped and re-runs CLR. Conditional, so on clean data it does nothing.",
    demo   = "DefaultAssay(sobj_filt) <- \"ADT\"\nFeatureScatter(sobj_filt, \"CD14\", \"CD19\") + ggtitle(\"ADT CD14 vs ADT CD19\")\nDefaultAssay(sobj_filt) <- \"RNA\"\nFeatureScatter(sobj_filt, \"CD14\", \"CD19\") + ggtitle(\"RNA CD14 vs RNA CD19\")\n",
    plot   = "Two scatter plots side by side. Healthy: ADT and RNA scatters match. With a swap: they diverge"
  )

)

message("Instructor answers loaded. ",
        length(.answers), " entries. Try: reveal(\"1.2b\")")
