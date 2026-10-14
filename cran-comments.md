## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.

## Test environments

* Cloud container (Ubuntu 24.04), R 4.3.3: `R CMD check --as-cran --run-donttest`
  on the built tarball.
* GitHub Actions, R-CMD-check run 38512781529: ubuntu-latest with R-devel,
  R-release and R-oldrel-1; macos-latest R-release; windows-latest R-release.
* win-builder (R-devel): <date, result>
* mac-builder (R-release): <date, result>

## Notes

* "New submission" is the only NOTE.
* Examples (slowest 0.5 s), the test suite (245 tests, about 10 s) and the five
  vignettes together run in under a minute.
* No reverse dependencies: this is the first release.

## Method references

The cut-set algorithm is MOCUS (Fussell and Vesely, 1972); the Description cites
it and the Fault Tree Handbook (Vesely, Goldberg, Roberts and Haasl, 1981,
NUREG-0492). A journal article describing the package is in preparation and
will be added to the Description when it appears.
