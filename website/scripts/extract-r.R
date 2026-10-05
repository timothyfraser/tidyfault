# Generate website/src/generated/reference-r.json from the R package's Rd files.
#
#   Rscript website/scripts/extract-r.R        (from anywhere; paths resolve from this file)
#
# Base R only (tools::parse_Rd). One entry per Rd topic that documents an export in
# NAMESPACE (export() and S3method() lines) or a dataset (\docType{data}). Rd markup is
# converted to escaped, minimal HTML (<p>, <code>, <a>, <em>, <strong>, lists); usage and
# examples are plain text. The file is committed; scripts/check-generated.mjs fails the
# build when its source hash no longer matches NAMESPACE + DESCRIPTION + _pkgdown.yml +
# man/*.Rd. Never edit the JSON by hand: fix the roxygen, re-document, rerun this.

local({
  arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  here <- if (length(arg)) dirname(normalizePath(sub("^--file=", "", arg[1]))) else getwd()
  assign("site_dir", normalizePath(file.path(here, "..")), envir = globalenv())
  assign("pkg_dir", normalizePath(file.path(here, "..", "..")), envir = globalenv())
})
stopifnot(file.exists(file.path(pkg_dir, "DESCRIPTION")), file.exists(file.path(pkg_dir, "NAMESPACE")))

# ---- source hash (must match check-generated.mjs) ---------------------------------------
# md5 of "relpath  md5(file with CR bytes removed)\n" over the sorted source list.
md5_bytes <- function(bytes) {
  tmp <- tempfile(); on.exit(unlink(tmp))
  writeBin(bytes, tmp)
  unname(tools::md5sum(tmp))
}
r_sources <- function() {
  rd <- sort(list.files(file.path(pkg_dir, "man"), pattern = "\\.Rd$"), method = "radix")
  c("DESCRIPTION", "NAMESPACE", "_pkgdown.yml", file.path("man", rd))
}
source_hash <- function(files) {
  lines <- vapply(files, function(f) {
    p <- file.path(pkg_dir, f)
    b <- readBin(p, "raw", file.info(p)$size)
    paste0(f, "  ", md5_bytes(b[b != as.raw(13)]), "\n")
  }, character(1))
  md5_bytes(charToRaw(enc2utf8(paste(lines, collapse = ""))))
}

# ---- NAMESPACE, DESCRIPTION, _pkgdown.yml ------------------------------------------------
ns <- readLines(file.path(pkg_dir, "NAMESPACE"), warn = FALSE)
exports <- sub("^export\\((.*)\\)$", "\\1", grep("^export\\(", ns, value = TRUE))
exports <- gsub('^"|"$', "", exports)
s3 <- regmatches(ns, regexec("^S3method\\(([^,]+),\\s*([^)]+)\\)$", ns))
s3 <- Filter(length, s3)
s3_generics <- unique(vapply(s3, `[`, "", 2))
s3_methods <- vapply(s3, function(m) paste0(m[2], ".", m[3]), "")
exported_names <- unique(c(exports, s3_generics, s3_methods))

version <- unname(read.dcf(file.path(pkg_dir, "DESCRIPTION"), fields = "Version")[1, 1])

# reference: sections of _pkgdown.yml -> topic -> group (tiny line parser, no yaml dep)
pkgdown_groups <- local({
  y <- readLines(file.path(pkg_dir, "_pkgdown.yml"), warn = FALSE)
  start <- which(y == "reference:")
  out <- character()
  if (length(start)) {
    title <- NA_character_
    for (line in y[seq.int(start + 1, length(y))]) {
      if (grepl("^\\S", line)) break
      if (grepl("^\\s*-\\s*title:", line)) {
        title <- trimws(gsub("[\"']", "", sub("^\\s*-\\s*title:", "", line)))
      } else if (!is.na(title) && grepl("^\\s+-\\s+[A-Za-z0-9._-]+\\s*$", line)) {
        out[trimws(sub("^\\s+-", "", line))] <- title
      }
    }
  }
  out
})
group_order <- unique(unname(pkgdown_groups))
group_order <- c(setdiff(group_order, "Data"), intersect("Data", group_order))  # datasets last, as the design lists them

# ---- Rd helpers --------------------------------------------------------------------------
tag <- function(x) { t <- attr(x, "Rd_tag"); if (is.null(t)) "" else t }
esc <- function(s) {
  s <- gsub("&", "&amp;", s, fixed = TRUE)
  s <- gsub("<", "&lt;", s, fixed = TRUE)
  s <- gsub(">", "&gt;", s, fixed = TRUE)
  gsub('"', "&quot;", s, fixed = TRUE)
}
squish <- function(s) trimws(gsub("[ \t\r\n]+", " ", s))
section <- function(rd, name) {
  hit <- Filter(function(x) tag(x) == name, rd)
  if (length(hit)) hit[[1]] else NULL
}
strip_tags <- function(h) {
  h <- gsub("<[^>]+>", "", h)
  h <- gsub("&lt;", "<", h, fixed = TRUE); h <- gsub("&gt;", ">", h, fixed = TRUE)
  h <- gsub("&quot;", '"', h, fixed = TRUE); gsub("&amp;", "&", h, fixed = TRUE)
}

# alias -> topic, filled before rendering so \link can resolve
alias_topic <- character()
topic_kind <- character()

TEXT_TAGS <- c("TEXT", "RCODE", "VERB", "USERMACRO")
BLOCK_TAGS <- c("\\itemize", "\\enumerate", "\\describe", "\\subsection", "\\section",
                "\\preformatted", "\\tabular")

# plain-text rendering for usage and examples
render_text <- function(x, examples = FALSE) {
  t <- tag(x)
  if (is.character(x)) return(if (t == "COMMENT") "" else paste(x, collapse = ""))
  kids <- function(y) paste(vapply(y, render_text, "", examples = examples), collapse = "")
  switch(t,
    "\\method" = , "\\S3method" = paste0("## S3 method for class '", kids(x[[2]]), "'\n", kids(x[[1]])),
    "\\S4method" = paste0("## S4 method for signature '", kids(x[[2]]), "'\n", kids(x[[1]])),
    "\\dots" = , "\\ldots" = "...",
    "\\R" = "R",
    "\\dontshow" = , "\\testonly" = "",
    "\\dontrun" = paste0("## Not run:\n", trimws(kids(x)), "\n## End(Not run)"),
    "\\donttest" = , "\\dontdiff" = kids(x),
    "\\Sexpr" = , "\\figure" = , "\\if" = , "\\ifelse" = , "\\out" = "",
    kids(x)
  )
}

link_html <- function(x) {
  label <- render_inline_kids(x)
  opt <- attr(x, "Rd_option")
  target <- if (is.null(opt)) strip_tags(label) else sub("^=", "", paste(as.character(opt), collapse = ""))
  external <- !is.null(opt) && !startsWith(paste(as.character(opt), collapse = ""), "=")
  if (external || is.na(alias_topic[target])) return(label)
  if (identical(unname(topic_kind[alias_topic[[target]]]), "function") && !grepl("(", label, fixed = TRUE)) {
    label <- paste0(label, "()")
  }
  sprintf('<a href="/reference/%s.html">%s</a>', esc(alias_topic[[target]]), label)
}

render_inline_kids <- function(x) paste(vapply(x, render_inline, ""), collapse = "")

render_inline <- function(x) {
  t <- tag(x)
  if (is.character(x)) {
    if (t == "COMMENT") return("")
    return(esc(paste(x, collapse = "")))
  }
  if (t %in% BLOCK_TAGS) return(render_block(x))
  inner <- function() render_inline_kids(x)
  switch(t,
    "\\code" = , "\\samp" = , "\\verb" = , "\\kbd" = , "\\env" = , "\\option" = ,
    "\\command" = , "\\file" = , "\\var" = paste0("<code>", inner(), "</code>"),
    "\\link" = link_html(x),
    "\\linkS4class" = inner(),
    "\\emph" = , "\\dfn" = , "\\cite" = paste0("<em>", inner(), "</em>"),
    "\\strong" = , "\\bold" = paste0("<strong>", inner(), "</strong>"),
    "\\sQuote" = paste0("‘", inner(), "’"),
    "\\dQuote" = paste0("“", inner(), "”"),
    "\\pkg" = inner(),
    "\\acronym" = inner(),
    "\\email" = inner(),
    "\\url" = {
      u <- strip_tags(inner())
      if (grepl("^https?://", u)) sprintf('<a href="%s">%s</a>', esc(u), esc(u)) else esc(u)
    },
    "\\href" = {
      u <- squish(render_text(x[[1]]))
      label <- render_inline_kids(x[[2]])
      if (grepl("^https?://", u)) sprintf('<a href="%s">%s</a>', esc(u), label) else label
    },
    "\\eqn" = , "\\deqn" = paste0("<code>", render_inline_kids(x[[if (length(x) > 1) 2 else 1]]), "</code>"),
    "\\dots" = , "\\ldots" = "...",
    "\\R" = "R",
    "\\cr" = "<br>",
    "\\tab" = " ",
    "\\enc" = render_inline_kids(x[[1]]),
    "\\method" = , "\\S3method" = render_inline_kids(x[[1]]),
    "\\Sexpr" = , "\\figure" = , "\\if" = , "\\ifelse" = , "\\out" = , "\\special" = ,
    "\\dontshow" = , "\\testonly" = "",
    inner()
  )
}

# split a sequence of Rd nodes into list items at each \item marker
split_items <- function(x) {
  items <- list(); cur <- list(); started <- FALSE
  for (k in x) {
    if (tag(k) == "\\item") {
      if (started) items[[length(items) + 1]] <- cur
      cur <- if (length(k)) list(k) else list(); started <- TRUE
    } else if (started) {
      cur[[length(cur) + 1]] <- k
    }
  }
  if (started) items[[length(items) + 1]] <- cur
  items
}
unwrap_p <- function(h) {
  if (grepl("^<p>", h) && endsWith(h, "</p>") && lengths(regmatches(h, gregexpr("<p>", h))) == 1) {
    substr(h, 4, nchar(h) - 4)
  } else h
}

render_block <- function(x) {
  t <- tag(x)
  switch(t,
    "\\itemize" = , "\\enumerate" = {
      lis <- vapply(split_items(x), function(it) paste0("<li>", unwrap_p(render_blocks(it)), "</li>"), "")
      el <- if (t == "\\itemize") "ul" else "ol"
      paste0("<", el, ">", paste(lis, collapse = ""), "</", el, ">")
    },
    "\\describe" = {
      its <- Filter(function(k) tag(k) == "\\item" && length(k) == 2, x)
      dl <- vapply(its, function(k) paste0("<dt>", render_inline_kids(k[[1]]), "</dt><dd>",
                                           unwrap_p(render_blocks(k[[2]])), "</dd>"), "")
      paste0("<dl>", paste(dl, collapse = ""), "</dl>")
    },
    "\\subsection" = , "\\section" = paste0("<h4>", squish(render_inline_kids(x[[1]])), "</h4>",
                                            render_blocks(x[[2]])),
    "\\preformatted" = paste0("<pre>", esc(trimws(render_text(x), "right")), "</pre>"),
    "\\tabular" = {
      cells <- strsplit(paste(vapply(x[[2]], function(k) {
        if (tag(k) == "\\tab") "\u0001" else if (tag(k) == "\\cr") "\u0002" else render_inline(k)
      }, ""), collapse = ""), "\u0002", fixed = TRUE)[[1]]
      rows <- vapply(Filter(function(r) nzchar(trimws(r)), cells), function(r) {
        paste0("<tr>", paste0("<td>", squish(strsplit(r, "\u0001", fixed = TRUE)[[1]]), "</td>", collapse = ""), "</tr>")
      }, "")
      paste0("<table>", paste(rows, collapse = ""), "</table>")
    },
    render_inline(x)
  )
}

# block container: paragraphs separated by blank lines; block macros break paragraphs
render_blocks <- function(x) {
  out <- character(); buf <- ""
  flush <- function() {
    s <- squish(buf)
    if (nzchar(s)) out <<- c(out, paste0("<p>", s, "</p>"))
    buf <<- ""
  }
  for (k in x) {
    t <- tag(k)
    if (t %in% BLOCK_TAGS) {
      flush(); out <- c(out, render_block(k))
    } else if (t %in% TEXT_TAGS && grepl("\n[ \t]*\n", paste(k, collapse = ""))) {
      pieces <- strsplit(paste(k, collapse = ""), "\n[ \t]*\n")[[1]]
      for (i in seq_along(pieces)) {
        if (i > 1) flush()
        buf <- paste0(buf, esc(pieces[i]))
      }
      if (grepl("\n[ \t]*\n[ \t\n]*$", paste(k, collapse = ""))) flush()
    } else {
      buf <- paste0(buf, render_inline(k))
    }
  }
  flush()
  paste(out, collapse = "")
}

# ---- topics ------------------------------------------------------------------------------
rd_files <- sort(list.files(file.path(pkg_dir, "man"), pattern = "\\.Rd$", full.names = TRUE), method = "radix")
parsed <- lapply(rd_files, function(f) {
  rd <- tools::parse_Rd(f, encoding = "UTF-8")
  name <- sub("\\.Rd$", "", basename(f))
  doctype <- section(rd, "\\docType")
  doctype <- if (is.null(doctype)) "" else squish(render_text(doctype))
  aliases <- vapply(Filter(function(x) tag(x) == "\\alias", rd), function(a) squish(render_text(a)), "")
  usage <- section(rd, "\\usage")
  kind <- if (doctype == "data") "data" else if (!is.null(usage) && grepl("## S3 method", render_text(usage))) "S3 method" else "function"
  src <- grep("^% Please edit documentation in ", readLines(f, warn = FALSE), value = TRUE)
  src <- if (length(src)) sub("^% Please edit documentation in ", "", src[1]) else ""
  list(file = f, rd = rd, name = name, doctype = doctype, aliases = unique(c(name, aliases)),
       kind = kind, source_file = src)
})

datasets <- sub("\\.(rda|RData|rds)$", "", list.files(file.path(pkg_dir, "data"), pattern = "\\.(rda|RData|rds)$"))
keep <- vapply(parsed, function(p) {
  if (p$doctype == "package") return(FALSE)
  if (p$doctype == "data") return(any(p$aliases %in% datasets))
  any(p$aliases %in% exported_names)
}, TRUE)
parsed <- parsed[keep]

for (p in parsed) {
  topic_kind[p$name] <- if (p$kind == "data") "data" else "function"
  for (a in p$aliases) if (is.na(alias_topic[a])) alias_topic[a] <- p$name
}

# every export must land on a topic
missing <- setdiff(c(exports, s3_generics), names(alias_topic))
if (length(missing)) stop("exports with no Rd topic: ", paste(missing, collapse = ", "))

# <code>fn()</code> written without \\link still links when fn is a topic here
autolink <- function(h) {
  m <- gregexpr("<code>([A-Za-z][A-Za-z0-9._]*)\\(\\)</code>", h)
  regmatches(h, m) <- lapply(regmatches(h, m), function(hits) vapply(hits, function(hit) {
    fn <- sub("^<code>(.*)\\(\\)</code>$", "\\1", hit)
    if (is.na(alias_topic[fn])) hit else sprintf('<code><a href="/reference/%s.html">%s()</a></code>', esc(alias_topic[[fn]]), fn)
  }, ""))
  h
}
sec_html <- function(rd, name) { s <- section(rd, name); if (is.null(s)) "" else autolink(render_blocks(s)) }

topics <- lapply(parsed, function(p) {
  rd <- p$rd
  args_sec <- section(rd, "\\arguments")
  arguments <- if (is.null(args_sec)) list() else lapply(
    Filter(function(k) tag(k) == "\\item" && length(k) == 2, args_sec),
    function(k) list(name = squish(render_text(k[[1]])), description = autolink(unwrap_p(render_blocks(k[[2]]))))
  )
  usage <- section(rd, "\\usage")
  examples <- section(rd, "\\examples")
  title <- squish(strip_tags(render_inline_kids(section(rd, "\\title"))))
  description <- sec_html(rd, "\\description")
  summary <- title
  if (grepl("^[A-Za-z0-9_.]+\\(\\)\\s+[Ff]unction$", title) || grepl(paste0("^", p$name, "\\b"), title)) {
    first <- squish(strip_tags(gsub("</(p|li|dd)>", " ", description)))
    summary <- sub("^(.*?(?<!e\\.g)(?<!i\\.e)(?<!\\bvs)[.!?])(\\s.*)?$", "\\1", first, perl = TRUE)
  }
  extra <- Filter(function(x) tag(x) == "\\section", rd)
  group <- unname(pkgdown_groups[p$name])
  if (is.na(group)) group <- if (p$kind == "data") "Data" else "Other"
  list(
    name = p$name,
    aliases = as.list(p$aliases),
    kind = p$kind,
    title = title,
    summary = summary,
    description = description,
    usage = if (is.null(usage)) "" else trimws(render_text(usage)),
    arguments = arguments,
    format = sec_html(rd, "\\format"),
    value = sec_html(rd, "\\value"),
    details = sec_html(rd, "\\details"),
    sections = lapply(extra, function(s) list(title = squish(strip_tags(render_inline_kids(s[[1]]))),
                                               html = render_blocks(s[[2]]))),
    examples = if (is.null(examples)) "" else trimws(gsub("\n{3,}", "\n\n", render_text(examples, TRUE))),
    seealso = sec_html(rd, "\\seealso"),
    source_file = p$source_file,
    group = group
  )
})

# order: _pkgdown.yml group order, then listed order, then alphabetical
rank <- vapply(topics, function(t) {
  g <- match(t$group, c(group_order, "Data", "Other"))
  i <- match(t$name, names(pkgdown_groups)); if (is.na(i)) i <- 9999
  g * 1e4 + i
}, 0)
topics <- topics[order(rank, vapply(topics, `[[`, "", "name"), method = "radix")]

# ---- JSON (base R encoder) ---------------------------------------------------------------
json_str <- function(s) {
  s <- enc2utf8(s)
  s <- gsub("\\", "\\\\", s, fixed = TRUE)
  s <- gsub('"', '\\"', s, fixed = TRUE)
  s <- gsub("\n", "\\n", s, fixed = TRUE)
  s <- gsub("\r", "\\r", s, fixed = TRUE)
  s <- gsub("\t", "\\t", s, fixed = TRUE)
  s <- gsub("[\x01-\x08\x0b\x0c\x0e-\x1f]", "", s, perl = TRUE)
  paste0('"', s, '"')
}
to_json <- function(x, indent = 0) {
  pad <- strrep("  ", indent + 1); end <- strrep("  ", indent)
  if (is.null(x)) return("null")
  if (is.list(x) && !is.null(names(x))) {
    if (!length(x)) return("{}")
    body <- vapply(names(x), function(n) paste0(pad, json_str(n), ": ", to_json(x[[n]], indent + 1)), "")
    return(paste0("{\n", paste(body, collapse = ",\n"), "\n", end, "}"))
  }
  if (is.list(x)) {
    if (!length(x)) return("[]")
    body <- vapply(x, function(v) paste0(pad, to_json(v, indent + 1)), "")
    return(paste0("[\n", paste(body, collapse = ",\n"), "\n", end, "]"))
  }
  if (is.character(x) && length(x) == 1) return(json_str(x))
  if (is.character(x)) return(if (length(x)) paste0("[", paste(vapply(x, json_str, ""), collapse = ", "), "]") else "[]")
  if (is.logical(x) && length(x) == 1) return(if (isTRUE(x)) "true" else "false")
  if (is.numeric(x) && length(x) == 1) return(format(x))
  stop("cannot encode ", class(x))
}

files <- r_sources()
out <- list(
  language = "R",
  package = "tidyfault",
  version = version,
  generated_by = "website/scripts/extract-r.R",
  source_files = list("DESCRIPTION", "NAMESPACE", "_pkgdown.yml", "man/*.Rd"),
  source_hash = source_hash(files),
  exports = as.list(sort(exported_names, method = "radix")),
  topics = topics
)
dest <- file.path(site_dir, "src", "generated", "reference-r.json")
dir.create(dirname(dest), showWarnings = FALSE, recursive = TRUE)
con <- file(dest, open = "wb"); writeLines(enc2utf8(to_json(out)), con, useBytes = TRUE); close(con)
message(sprintf("extract-r: %d topics (%d exports, %d datasets) -> %s",
                length(topics), length(c(exports, s3_methods)),
                sum(vapply(topics, function(t) t$kind == "data", TRUE)), dest))
