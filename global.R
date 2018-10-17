# --------------------------------------------------------------- LIBS ----

options(shiny.sanitize.errors = FALSE)

# this tool is still not compatible with Windows OS
if(Sys.info()[["sysname"]] == "Windows") {
	stop("This tool is not yet compatible with Windows.\nPlease use a UNIX-like system.")
}

# load and install packages if needed
if(!require("pacman")) {
	install.packages("pacman")
	require("pacman")
}

# CRAN
packs <- c(
	"beepr",
	"car",
	"caret",
	"data.table",
	"devtools",
	"dplyr",
	"knitr",
	"leaflet",
	"lubridate",
	"magrittr",
	"markdown",
	"parallel",
	"pryr",
	"purrr",
	"raster",
	"rgeos",
	"rgp",
	"rPython",
	"SDMTools",
	"shiny",
	"shinyBS",
	"shinyFiles",
	"shinyjs",
	"stringr",
	"strucchange",
	"tools",
	"xtable",
	"zoo"
)

p_load(char = packs)

# --------------------------------------------------------------- DEFS ----

# create a .md file from the following .Rmd, in order to be embedded into
# the Shiny app
# knit(input = "./md/tutorial.Rmd", output = "md/tutorial.md", quiet = T)

# longlat projection default CRS
proj_ll <- "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0"

proj_utm <- function(shape) {
	p <- "+proj=utm +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0 +units=m"
	paste0(p, " +zone=", zoneCalc(extent(shape)[1]))
}

zoneCalc <- function(long) {
	(floor((long + 180)/6) %% 60) + 1
}
