shinyUI(navbarPage(
	title = div(em(strong("Data Acquisition Manager"))),
	windowTitle = "DAM",

	id = "navbar",
	position = "fixed-top",
	collapsible = T,
	header = {
		# load styles.css file with custom styles
		tags$head(includeCSS("www/styles.css"))
	},

	# pixel
	source(file.path("ui/ui-tab-download-pixel.R"), local = TRUE)$value,

	# raster
	source(file.path("ui/ui-tab-download-raster.R"), local = TRUE)$value,

	# tutorial
	tabPanel(
		title = "Tutorial",
		icon = icon(name = "question-circle", lib = "font-awesome", class = "fa-lg"),
		fluidPage(
			div(style = "max-width: 70%; margin-left: auto; margin-right: auto; margin-top: 71px;",
				 align = "justify",
				 includeMarkdown("./md/tutorial.md")
			)
		)
	),

	# about
	source(file.path("ui/ui-tab-about.R"), local = TRUE)$value

))
