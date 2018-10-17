tabPanel(
	title = "Raster",
	icon = icon(name = "image", lib = "font-awesome", class = "fa-lg"),

	style = "margin-top: 71px;",

	sidebarPanel(
		# id = "map-toolbar",

		# Set up shinyjs
		useShinyjs(),

		fileInput(inputId = "raster_datafile",
					 label = "Choose shapefile",
					 accept = c(".zip")),
		helpText(
			"The shape must be compressed into a zip with, at least, the .shp, .shx, .dbf, and .prj files. The zip file must have the same name as its contents."
		),
		br(),
		checkboxInput("raster_showMap", "Show shapefile on the map?", FALSE),
		checkboxInput("download_SRTM", "Download SRTM data?", FALSE),

		selectInput(inputId = "raster_versionLS",
						label = "Landsat SR Version",
						choices = list("Collection 1" = "SR_new",
											"Pre-Collection" = "SR_old",
											"TOA" = "TOA")),
		selectInput(inputId = "raster_satellite",
						label = "Landsat Number",
						choices = list(4, 5, 7, 8)),
		dateInput(
			inputId = "raster_periodStart",
			label = "Period start",
			width = "100%",
			format = "yyyy-mm-dd",
			startview = "decade"
		),
		dateInput(
			inputId = "raster_periodEnd",
			label = "Period end",
			width = "100%",
			format = "yyyy-mm-dd",
			startview = "decade"
		),
		bsButton(
			inputId = "raster_botaoDownload",
			label = "Download",
			style = "primary",
			icon = icon("download", lib = "font-awesome"),
			width = "50%"
		),
		downloadButton(
			outputId = "action_downloadDataRaster",
			label = "Data",
			class = "btn-primary"
		),
		textOutput("msg")
	),

	mainPanel(
		div(
			tags$style(type = "text/css", "#raster_leaf {height: calc(100vh - 80px) !important;}"),

			leafletOutput(
				outputId = "raster_leaf"
			)
		)
	)
)