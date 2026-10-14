## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.

## Test environments

* local: Windows 11 x64, R 4.5.2: `R CMD check --as-cran --run-donttest` on the
  built tarball, with `_R_CHECK_CRAN_INCOMING_REMOTE_=true` (2026-10-14).
* win-builder: R-devel (2026-10-13 r90668) and R-release (4.6.1) (2026-10-14).
* GitHub Actions, R-CMD-check run 38621966572: ubuntu-latest with R-devel,
  R-release and R-oldrel-1; macos-latest R-release; windows-latest R-release.

## Notes

* The only NOTE is "New submission". On win-builder it also lists "Possibly
  misspelled words in DESCRIPTION": Fussell, Vesely and Haasl are authors of the
  cited method references, and MOCUS is the name of the algorithm (Method of
  Obtaining Cut Sets), spelled out where it first appears.
* Examples (slowest 1.5 s), the test suite (about 10 s) and the five vignettes
  together run in under a minute.
* No reverse dependencies: this is the first release.

## Method references

The cut-set algorithm is MOCUS (Fussell and Vesely, 1972); the Description cites
it and the Fault Tree Handbook (Vesely, Goldberg, Roberts and Haasl, 1981,
NUREG-0492). A journal article describing the package is in preparation and
will be added to the Description when it appears.
