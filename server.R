library(shiny)
source("global.R", local = TRUE)

options(shiny.maxRequestSize=100*1024^2)

shinyServer(function(input, output, session) {

# ------------------------------------------------------------- SESSION ----

	# allow reconnection by a certain grace period
	session$allowReconnect(T)

# ------------------------------------------------------------- APP (DOWNLOAD) ----

	pixel_filedata <- reactive({
		infile <- input$pixel_datafile

		if (is.null(infile)) {
			return(NULL)
		} else {
			return(read.csv(infile$datapath, header = TRUE, sep = ","))
		}
	})

	raster_filedata <- reactive({

		infile <- input$raster_datafile
		infolder <- substr(infile$datapath, 1, nchar(infile$datapath) - 5)
		nameShape <- substr(infile$name, 1, nchar(infile$name) - 4)

		if (is.null(infile)) {
			return(NULL)
		} else {
			unzip(infile$datapath, exdir = infolder)
			shp <- shapefile(file.path(substr(infile$datapath, 1, nchar(infile$datapath) - 5), paste0(nameShape, ".shp")))
			return(list(nameShape, shp))
		}
	})

	# habilita/desabilita o botao de download conforme disponibilidade de df
	# se a condicao for satisfeita, eh habilitado
	observeEvent(input$pixel_datafile, ignoreNULL = F, {
		shinyjs::toggleState(
			id = "pixel_botaoDownload",
			condition = !is.null(input$pixel_datafile)
		)
		shinyjs::toggleState(
			id = "pixel_showMap",
			condition = !is.null(input$pixel_datafile)
		)
	})

	observeEvent(input$pixel_botaoDownload, ignoreNULL = F, {
		shinyjs::toggleState(
			id = "action_downloadDataPixel",
			condition = input$pixel_botaoDownload > 0,
			selector = NULL)
	})

	observeEvent(input$raster_datafile, ignoreNULL = F, {
		shinyjs::toggleState(
			id = "raster_botaoDownload",
			condition = !is.null(input$raster_datafile)
		)

		shinyjs::toggleState(
			id = "raster_showMap",
			condition = !is.null(input$raster_datafile)
		)

	})

	observeEvent(input$raster_botaoDownload, ignoreNULL = F, {
		shinyjs::toggleState(
			id = "action_downloadDataRaster",
			condition = input$raster_botaoDownload > 0,
			selector = NULL)
	})

	# Download pixel
	observeEvent(input$pixel_botaoDownload, {

		isolate ({
			dfCoords <- pixel_filedata()
		})

		collection <- input$pixel_versionLS
		pathAuxPixel <- getwd()

		if(collection == "new"){
			sat <- c("LT04/C01/T1_SR", "LT05/C01/T1_SR", "LE07/C01/T1_SR", "LC08/C01/T1_SR")
		} else{
			sat <- c("LT4_SR", "LT5_SR","LE7_SR", "LC8_SR")
		}


		filesInTheFolder <- list.files()
		if(paste0(input$pixel_filename, ".rds") %in% filesInTheFolder) {
			serieListPixel <<- readRDS(paste0(input$pixel_filename, ".rds"))
			startJ <- (serieListPixel %>% length()) + 1
		} else {
			serieListPixel <<- list()
			startJ <- 1
		}

		if(startJ <= nrow(dfCoords)) {
			withProgress(message = 'Downloading', value = 0, {
				for(j in startJ:nrow(dfCoords)) {
					setProgress(j / nrow(dfCoords), detail = paste0(j, "/", nrow(dfCoords)))

					# Ponto para ser baixado
					lat <- dfCoords$lat[j]
					lng <- dfCoords$long[j]
					python.assign("coords", c(lng, lat)) # <- deve estar na ordem (lng, lat)

					# Chama o script em Python para download das series
					df <- NULL
					for(i in 1:length(sat)) {
						# Define qual satelite vai ser baixado
						python.assign("satChoice", sat[i])

						# Executa o script do Python
						python.load(file.path(paste0("python-download/gee-px-ls-", collection,".py")))

						# Recebe o output do Python; se dados nao estiverem disponiveis, recebe NULL
						if (is.null(unlist(python.get("serie")))) {
							serie <- NULL
						} else {
							serie <- unlist(python.get("serie"))
						}

						if(serie %>% is.null %>% not) {
							# Transforma dados do Python em um df
							# Remove
							tmp <- matrix(serie,
											  ncol = python.get("numCol"),
											  byrow = T) %>% as.data.frame()
							isRowNA <- apply(tmp, MARGIN = 1, FUN = function(x) {
								(x == "NA") %>% sum
							})
							tmp <- tmp[isRowNA == 0, ]

							# Caso todas as linhas sejam NA, nao roda o resto do codigo
							if(nrow(tmp) > 0) {
								tmp[, 1] %<>% as.character
								tmp[, 2:python.get("numCol")] %<>% lapply(FUN = function(x) {
									x %>% as.character %>% as.numeric %>% round(4)
								})

								tmp %<>% as.data.frame()

								# Formatacao das classes dos dados e colunas do df
								tmp[, 1] <- as.Date(tmp[, 1], format = "%Y_%m_%d")
								tmp[, 2:ncol(tmp)] <- apply(tmp[, 2:ncol(tmp)],
																	 MARGIN = 2,
																	 as.numeric)
								colnames(tmp) <- python.get("colNames")

								# Exclui dados saturados, caso existam
								filterWhich <- which(rowSums(tmp[, 2:ncol(tmp)] == 2) > 0)
								if (length(filterWhich) > 0) {
									tmp <- tmp[-filterWhich, ]
								}

								# Se os dados existem, cria coluna com nome do satelite e cresce o df final
								if(tmp$date[1] %>% is.na %>% not) {
									tmp$sat <- sat[i]
									df <- rbind(df, tmp)
								}
							}
						}

						python.assign("aux", NULL)
						python.assign("serie", NULL)
						python.assign("values", NULL)
						python.assign("numCol", NULL)
						python.assign("colNames", NULL)
					}

					if(collection == "new" & df %>% is.null %>% not) {
						tmp <- intToBits(df$pixel_qa) %>% as.numeric %>% matrix(nrow = nrow(df), byrow = T)
						df$clearBit <- tmp[, 2]
						df$confBit <- tmp[, 7] + tmp[, 8] * 2
						setDT(df)
						df <- df[clearBit == 1, ]
						df <- df[, -c("pixel_qa", "clearBit")]
						df[sat == "LT04/C01/T1_SR", sat := "LSR4"]
						df[sat == "LT05/C01/T1_SR", sat := "LSR5"]
						df[sat == "LE07/C01/T1_SR", sat := "LSR7"]
						df[sat == "LC08/C01/T1_SR", sat := "LSR8"]
						setkey(df, "date")
					}

					if(collection == "old") {
						setDT(df)
						df[sat == "LT4_SR", sat := "LSR4"]
						df[sat == "LT5_SR", sat := "LSR5"]
						df[sat == "LT7_SR", sat := "LSR7"]
						df[sat == "LT8_SR", sat := "LSR8"]
					}

					serieListPixel[[j]] <<- df

					if((j %% 100 == 0) | (j == nrow(dfCoords))) {
						saveRDS(serieListPixel, paste0(input$pixel_filename, ".rds"))
					}

				}
			})
		}

		setwd(pathAuxPixel)

	})

	# Download raster
	observeEvent(input$raster_botaoDownload, {

		# isolate ({
		# 	infile <- input$raster_datafile
		# 	shapePath <- file.path(substr(infile$datapath, 1, nchar(infile$datapath) - 5))
		# 	shape <- raster_filedata()[[1]]
		# })
		#
		# python.assign("msg", NULL) # msg para ser exibida ao final
		# python.assign("shape", shape) # nome do shapefile
		# python.assign("shapePath", shapePath) # path da pasta descomprimida
		# python.assign("satellite", input$raster_satellite) # numero do satelite
		# python.assign("satprod", input$raster_versionLS) # versao do landsat
		# python.assign("periodStart", as.character(input$raster_periodStart)) # data para comecar a baixar
		# python.assign("periodEnd", as.character(input$raster_periodEnd)) # data que termina de baixar
		#
		# # Seta o caminho para salvar as imagens
		#
		# pathRaster <- file.path(tempdir())
		# python.assign("pathRaster", pathRaster)
		#
		# # Executa o script do Python
		# pathR <- getwd()
		# python.load(file.path("python-download/gee-ls-prepare.py"))
		#
		# # Pega o numero de imagens para serem baixadas
		# nRaster <- python.get("imgColLen")
		#
		# if(nRaster > 0) {
		# 	withProgress(message = 'Downloading', value = 0, {
		# 		for(i in 0:(nRaster-1)) {
		# 			setProgress((i+1) / nRaster, detail = paste0((i+1), "/", nRaster))
		# 			python.assign("i", i) # atualizada o valor de i do loop
		# 			python.load(file.path(pathR, "python-download/download-raster-ls.py"))
		# 		}
		# 	})
		# 	if(input$download_SRTM) {
		# 		python.load(file.path(pathR,"python-download/download-SRTM.py"))
		# 	}
		# }
		#
		# output$msg <- renderText({ python.get("msg") })
		#
		# setwd(pathR)

		workpath <- getwd()
		isolate ({
			infile <- input$raster_datafile
			shapePath <- file.path(substr(infile$datapath, 1, nchar(infile$datapath) - 5))
			shape <- raster_filedata()[[1]]
		})

		python.assign("msg", NULL) # nome da pasta descomprimida
		python.assign("shape", shape) # nome da pasta descomprimida
		python.assign("shapePath", shapePath) # path da pasta descomprimida
		python.assign("satellite", input$raster_satellite) # numero do satelite
		python.assign("satprod", input$raster_versionLS) # versao do landsat
		python.assign("periodStart", as.character(input$raster_periodStart)) # data para comecar a baixar
		python.assign("periodEnd", as.character(input$raster_periodEnd)) # data que termina de baixar

		# Executa o script do Python
		pathR <- getwd()
		python.load(file.path(pathR, "python-download/gee-ls-prepare.py"))

		# Pega o numero de imagens para serem baixadas
		nRaster <- python.get("imgColLen")

		if(nRaster > 0) {
			withProgress(message = 'Downloading', value = 0, {
				for(i in 0:(nRaster-1)) {
					setProgress((i+1) / nRaster, detail = paste0((i+1), "/", nRaster))
					python.assign("i", i) # atualizada o valor de i do loop
					python.load(file.path(pathR, "python-download/download-raster-ls.py"))
				}
			})
			if(input$download_SRTM) {
				python.load(file.path(pathR,"python-download/download-SRTM.py"))
			}
		}

		output$msg <- renderText({ python.get("msg") })

		setwd(workpath)

	})

	# Salvando dados de Raster
	# output$action_downloadDataRaster <- downloadHandler(
	# 	filename = paste0("images-downloaded", ".zip"),
	# 	content = {function(file) {
	# 			pathAux <- getwd()
	# 			setwd(file.path(tempdir(), "raster"))
	# 			zip(zipfile = file, files = isolate ({
	# 				shape <- raster_filedata()[[1]]
	# 			}))
	# 			setwd(pathAux)
	# 		}
	# 	}
	# )

	# Plotting
	output$pixel_leaf <- renderLeaflet({

		m3 <- leaflet(options = list(attributionControl = F))
		m3 <- addTiles(map = m3,
							urlTemplate = "http://{s}.google.com/vt/lyrs=s&x={x}&y={y}&z={z}",
							attribution = "Imagery &copy;2016 TerraMetrics",
							options = list(minZoom = 1,
												maxZoom = 16,
												noWrap = T,
												subdomains = c('mt0','mt1','mt2','mt3')))
		m3 <- setMaxBounds(m3, -180, -90, 180, 90)

		m3 <- setView(m3, lng = 22.909114, lat = -25.618960, zoom = 2)
		m3
	})

	observe({

		leafletProxy("pixel_leaf") %>%
			clearMarkers() %>%
			clearMarkerClusters()

		if(input$pixel_showMap){

			dfCoords <- pixel_filedata()

			if(input$pixel_cluster | (length(dfCoords$long) > 1000)) {
				leafletProxy("pixel_leaf") %>%
					addAwesomeMarkers(lng = dfCoords$long,
											lat = dfCoords$lat,
											label = dfCoords[,1] %>% as.character,
											icon = makeAwesomeIcon(
												icon = "circle",
												markerColor = "blue",
												iconColor = "#FFFFFF",
												library = "fa"
											),
											clusterOptions = markerClusterOptions(showCoverageOnHover = FALSE)) %>%
					flyTo(lat = mean(dfCoords$lat),
							lng = mean(dfCoords$long),
							zoom = 5,
							options = list(animate = FALSE))
			} else {
				leafletProxy("pixel_leaf") %>%
					addAwesomeMarkers(lng = dfCoords$long,
											lat = dfCoords$lat,
											label = dfCoords[,1] %>% as.character,
											icon = makeAwesomeIcon(
												icon = "circle",
												markerColor = "blue",
												iconColor = "#FFFFFF",
												library = "fa"
											)) %>%
					flyTo(lat = mean(dfCoords$lat),
							lng = mean(dfCoords$long),
							zoom = 5,
							options = list(animate = FALSE))
			}


		} else {
			leafletProxy("pixel_leaf") %>% setView(lng = 0,
																lat = 0,
																zoom = 1)
		}
	})

	output$raster_leaf <- renderLeaflet({

		m2 <- leaflet(options = list(attributionControl = F))
		m2 <- addTiles(map = m2,
							urlTemplate = "http://{s}.google.com/vt/lyrs=s&x={x}&y={y}&z={z}",
							attribution = "Imagery &copy;2016 TerraMetrics",
							options = list(minZoom = 1,
												maxZoom = 16,
												noWrap = T,
												subdomains = c('mt0','mt1','mt2','mt3')))

		m2 <- setMaxBounds(m2, -180, -90, 180, 90)

		m2 <- setView(m2, lng = 22.909114, lat = -25.618960, zoom = 2)

		m2
	})

	observe({


		leafletProxy("raster_leaf") %>%
			clearShapes()

		if(input$raster_showMap){
			shp <- raster_filedata()[[2]]

			extetentShape <- shp %>% extent

			leafletProxy("raster_leaf") %>% addPolygons(data = shp, color = "white", opacity=1, fillOpacity=0) %>%
				flyTo(lat = extetentShape[3] + (extetentShape[4]-extetentShape[3])/2,
						lng = extetentShape[1] + (extetentShape[2]-extetentShape[1])/2,
						zoom = 10,
						options = list(animate = FALSE))
		} else {
			leafletProxy("raster_leaf") %>% setView(lng = 0,
																 lat = 0,
																 zoom = 1)
		}
	})




})
