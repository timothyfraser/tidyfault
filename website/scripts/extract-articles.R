# Render every vignette to an HTML fragment plus 300 dpi figures.
#
# Run from anywhere:   LANG=C.UTF-8 Rscript website/scripts/extract-articles.R
#
# Output (committed, never hand-edited):
#   website/src/generated/articles/index.json
#   website/src/generated/articles/<name>/<name>.html      (fragment, no <html>/<body>)
#   website/src/generated/articles/<name>/figures/*.png    (300 dpi)
#
# Each vignette is knit from a copy in a temporary directory, so nothing is
# written to vignettes/ and no *_files/ or .html strays are left behind.

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_dir <- if (length(script_arg) > 0) {
  dirname(normalizePath(sub("^--file=", "", script_arg[1])))
} else {
  normalizePath("website/scripts")
}
pkg_root <- normalizePath(file.path(script_dir, "..", ".."))
setwd(pkg_root)

out_root <- file.path(pkg_root, "website", "src", "generated", "articles")

stopifnot(requireNamespace("rmarkdown", quietly = TRUE))
stopifnot(requireNamespace("jsonlite", quietly = TRUE))
stopifnot(requireNamespace("devtools", quietly = TRUE))

# load_all() compiles src/ in place; remember what was there so the objects it
# creates can be removed at the end and the worktree stays clean.
src_objs <- function() {
  list.files(file.path(pkg_root, "src"), pattern = "\\.(o|so|dll)$", full.names = TRUE)
}
objs_before <- src_objs()

# Load the package from source so the articles match the working tree.
suppressMessages(devtools::load_all(pkg_root, quiet = TRUE))

vignettes <- sort(list.files(file.path(pkg_root, "vignettes"), pattern = "\\.Rmd$", full.names = TRUE))
stopifnot(length(vignettes) > 0)

strip_tags <- function(x) {
  x <- gsub("<[^>]+>", "", x)
  x <- gsub("&amp;", "&", x, fixed = TRUE)
  x <- gsub("&lt;", "<", x, fixed = TRUE)
  x <- gsub("&gt;", ">", x, fixed = TRUE)
  x <- gsub("&quot;", "\"", x, fixed = TRUE)
  x <- gsub("&#39;", "'", x, fixed = TRUE)
  trimws(gsub("[[:space:]]+", " ", x))
}

first_paragraph <- function(html) {
  m <- regmatches(html, regexpr("(?s)<p>.*?</p>", html, perl = TRUE))
  if (length(m) == 0) "" else strip_tags(m)
}

# Start from a clean generated tree so removed vignettes do not linger.
unlink(out_root, recursive = TRUE)
dir.create(out_root, recursive = TRUE)

index <- list()

for (rmd in vignettes) {
  name <- tools::file_path_sans_ext(basename(rmd))
  message("Rendering ", name)

  work <- tempfile(paste0("article-", name, "-"))
  dir.create(work)
  file.copy(rmd, file.path(work, basename(rmd)))

  out_dir <- file.path(out_root, name)
  fig_dir <- file.path(out_dir, "figures")
  dir.create(fig_dir, recursive = TRUE)

  out_file <- paste0(name, ".html")
  # mathjax = FALSE + --mathml: math becomes native MathML, no script to load.
  # section_divs = FALSE: the site's .section class must not match pandoc's wrappers.
  fmt <- rmarkdown::html_fragment(
    section_divs = FALSE,
    fig_width = 7,
    fig_height = 4.5,
    self_contained = FALSE,
    mathjax = FALSE,
    pandoc_args = "--mathml"
  )
  # 300 dpi for every figure, whatever the vignette's own chunk options say.
  fmt$knitr$opts_chunk$dpi <- 300
  rmarkdown::render(
    input = file.path(work, basename(rmd)),
    output_format = fmt,
    output_file = out_file,
    output_dir = work,
    intermediates_dir = work,
    knit_root_dir = work,
    envir = new.env(parent = globalenv()),
    quiet = TRUE
  )

  html <- paste(readLines(file.path(work, out_file), encoding = "UTF-8", warn = FALSE), collapse = "\n")

  # Move the figures and point the fragment at them (the page rewrites these
  # relative paths to hashed URLs at build time).
  figs <- list.files(file.path(work, paste0(name, "_files")), pattern = "\\.png$", recursive = TRUE, full.names = TRUE)
  for (f in figs) file.copy(f, file.path(fig_dir, basename(f)))
  html <- gsub(
    paste0(name, "_files/figure-html/"),
    "figures/",
    html,
    fixed = TRUE
  )
  if (length(figs) == 0) unlink(fig_dir, recursive = TRUE)

  writeLines(html, file.path(out_dir, out_file), useBytes = TRUE)

  meta <- rmarkdown::yaml_front_matter(rmd)
  index[[length(index) + 1]] <- list(
    name = name,
    title = meta$title,
    description = first_paragraph(html),
    file = paste0(name, "/", out_file)
  )

  unlink(work, recursive = TRUE)
}

jsonlite::write_json(
  index,
  file.path(out_root, "index.json"),
  auto_unbox = TRUE,
  pretty = TRUE
)

message("Wrote ", length(index), " articles to ", out_root)

unlink(setdiff(src_objs(), objs_before))
