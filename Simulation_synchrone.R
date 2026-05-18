library(BoolNet)
library(tools)

## ============================================================
## CONFIGURATION — Modify only this section
## ============================================================
file_rules <- "./nsclc_9_nodes_fit.txt"

# Genes to be forced ON (=1). Leave c() if you don't want to turn any ON.
# Genes to be forced OFF (=0). Leave c() if you don't want to turn any OFF.
# Note: If both are empty (i.e. the network is not modified), the output
#       file will be labeled as WT (wild type).

 genes_ON  <- c("miR_145","p53_A")              # e.g. c("X1", "X2")  or  c()
 genes_OFF <- c("BMI1")              # e.g. c("X4", "X7")  or  c()

# genes_ON  <- c()              # e.g. c("X1", "X2")  or  c()
# genes_OFF <- c()              # e.g. c("X4", "X7")  or  c()


## ============================================================

{
  ## ---------- 1. Load network and find attractors ----------
  net <- loadNetwork(file_rules)
  
  # Build arguments dynamically: ON/OFF are only passed if not empty
  args_list <- list(network = net, returnTable = TRUE)
  if (length(genes_ON)  > 0) args_list$genesON  <- genes_ON
  if (length(genes_OFF) > 0) args_list$genesOFF <- genes_OFF
  
  att <- do.call(getAttractors, args_list)
  
  genes  <- net$genes
  nGenes <- length(genes)
  
  ## ---------- 2. Integer -> binary vector ----------
  decodeState <- function(idx, n = nGenes) {
    as.integer(intToBits(idx))[1:n]
  }
  
  ## ---------- 3. Build the gene x attractor matrix ----------
  attractor_columns <- lapply(att$attractors, function(A) {
    state_mat <- sapply(A$involvedStates, decodeState)
    if (is.null(dim(state_mat)))
      state_mat <- matrix(state_mat, nrow = nGenes)
    apply(state_mat, 1, paste0, collapse = "")
  })
  
  stateMat <- do.call(cbind, attractor_columns)
  colnames(stateMat) <- paste0("Attractor_", seq_along(att$attractors))
  rownames(stateMat) <- genes
  
  df_states <- data.frame(Gene = rownames(stateMat), stateMat, row.names = NULL,
                          check.names = FALSE)
  
  ## ---------- 4. Basin size table ----------
  basin_df <- data.frame(
    Attractor = paste0("Attractor_", seq_along(att$attractors)),
    BasinSize = sapply(att$attractors, `[[`, "basinSize")
  )
  
  total_basin <- sum(basin_df$BasinSize)
  basin_df$Percentage <- round(100 * basin_df$BasinSize / total_basin, 2)
  
  ## ---------- 5. Merge everything into a single table ----------
  # 5a. Row with basin sizes
  row_size <- data.frame(
    Gene = "BasinSize",
    as.list(setNames(basin_df$BasinSize, basin_df$Attractor)),
    check.names = FALSE
  )
  
  # 5b. Row with percentages
  row_pct  <- data.frame(
    Gene = "BasinPercentage",
    as.list(setNames(basin_df$Percentage, basin_df$Attractor)),
    check.names = FALSE
  )
  
  # 5c. Combine
  combined_df <- rbind(df_states, row_size, row_pct)
  
  ## ---------- 6. Automatic output name with perturbations ----------
  base_name <- file_path_sans_ext(basename(file_rules))
  
  # Suffix: G10_ON_G15_OFF, G3_ON_G10_ON_G15_OFF, etc.
  suffix_parts <- c()
  if (length(genes_ON)  > 0) suffix_parts <- c(suffix_parts, paste0(genes_ON,  "_ON"))
  if (length(genes_OFF) > 0) suffix_parts <- c(suffix_parts, paste0(genes_OFF, "_OFF"))
  
  suffix <- if (length(suffix_parts) > 0) {
    paste0("_", paste(suffix_parts, collapse = "_"))
  } else {
    "_WT"   # no perturbations (wild type)
  }
  
  out_combined <- paste0("attractors_and_basins_", base_name, suffix, ".csv")
  
  ## ---------- 7. Save file ----------
  write.table(combined_df,
              file      = out_combined,
              sep       = ";",
              dec       = ".",
              quote     = FALSE,
              row.names = FALSE)
  
  cat("Result saved in:\n  -", out_combined, "\n")
  cat("  Genes ON : ", if (length(genes_ON)  > 0) paste(genes_ON,  collapse = ", ") else "(none)", "\n")
  cat("  Genes OFF: ", if (length(genes_OFF) > 0) paste(genes_OFF, collapse = ", ") else "(none)", "\n")
}

combined_df

net
