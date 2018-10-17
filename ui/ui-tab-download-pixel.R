tabPanel(
	title = "Pixel",
	icon = icon(name = "thumb-tack", lib = "font-awesome", class = "fa-lg"),

	style = "margin-top: 71px;",

	sidebarPanel(
		# id = "map-toolbar",

		# Set up shinyjs
		useShinyjs(),

		fileInput(inputId = "pixel_datafile",
					 label = "Choose CSV File",
					 accept = c(".csv")),
		helpText("The input data must be a .csv file, with comma sep. There must be three columns: plot (id), lat (latitude) and long (longitude)."),

		checkboxInput("pixel_showMap", "Show points on the map?", FALSE),
		checkboxInput("pixel_cluster", "Group points?", FALSE),

		br(),

		textInput(inputId = "pixel_filename",
					 label = "Downloaded data file name",
					 value = "downloaded-data"),

		selectInput(inputId = "pixel_versionLS",
						label = "Landsat SR Version",
						choices = list("Collection 1" = "new",
											"Pre-Collection" = "old")),
		bsButton(
			inputId = "pixel_botaoDownload",
			label = "Download",
			style = "primary",
			icon = icon("download", lib = "font-awesome"),
			width = "50%"
		)#,
		# downloadButton(
		# 	outputId = "action_downloadDataPixel",
		# 	label = "Data",
		# 	class = "btn-primary"
		# )
		# verbatimTextOutput("teste", placeholder = FALSE)
	),

	mainPanel(
		div(
			tags$style(type = "text/css", "#pixel_leaf {height: calc(100vh - 80px) !important;}"),

			leafletOutput(
				outputId = "pixel_leaf"
			)
		)
	)
)
