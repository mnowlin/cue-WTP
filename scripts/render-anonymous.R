#!/usr/bin/env Rscript

# Renders anonymized copies of cue-WTP.qmd and supplemental-materials.qmd for
# blind review into submission-files/: drops the author blocks from the YAML
# header and, in the manuscript, the Statements and Declarations section
# (ethics, data availability with the GitHub link, funding, CRediT, etc.).
# The temporary .qmd files, their freeze caches, and any render byproducts
# are removed afterwards.
#
# Run from the project root: Rscript scripts/render-anonymous.R

render_anonymous <- function(src, out = "submission-files") {
  stem <- paste0(sub("\\.qmd$", "", src), "-anonymous")
  anon <- paste0(stem, ".qmd")

  lines <- readLines(src)

  # ---- Author blocks: "    author:" plus its more deeply indented lines --
  author_start <- grep("^    author:\\s*$", lines)
  drop <- unlist(lapply(author_start, function(i) {
    j <- i + 1
    while (j <= length(lines) && grepl("^      ", lines[j])) j <- j + 1
    i:(j - 1)
  }))

  # ---- Statements and Declarations, up to the page break before References
  stmt_start <- grep("^# Statements and Declarations", lines)
  if (length(stmt_start) == 1) {
    stmt_end <- grep("^\\\\newpage", lines)
    stmt_end <- stmt_end[stmt_end > stmt_start][1] - 1
    drop <- c(drop, stmt_start:stmt_end)
  }

  # Rendered outside the project, so _quarto.yaml's execute options don't
  # apply; add them to the front matter (after the opening "---").
  execute_opts <- c("execute:", "  echo: false", "  warning: false")
  keep <- setdiff(seq_along(lines), drop)
  anon_lines <- append(lines[keep], execute_opts, after = 1)

  writeLines(anon_lines, anon)
  on.exit({
    unlink(c(anon, paste0(stem, "_files")), recursive = TRUE)
    unlink(file.path("_freeze", stem), recursive = TRUE)
  })

  # The anonymous file is outside the project's render list, so quarto
  # renders it in place (--output-dir is not allowed); move the outputs.
  # HTML is self-contained so it needs no _files folder.
  status <- system2("quarto", c("render", anon, "-M", "embed-resources:true"))
  if (status != 0) stop("quarto render failed")

  dir.create(out, showWarnings = FALSE)
  for (ext in c("html", "pdf", "docx")) {
    f <- paste0(stem, ".", ext)
    file.rename(f, file.path(out, f))
  }
}

render_anonymous("cue-WTP.qmd")
render_anonymous("supplemental-materials.qmd")
