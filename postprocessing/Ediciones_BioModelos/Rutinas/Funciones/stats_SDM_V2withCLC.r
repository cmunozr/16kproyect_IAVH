# 1. Revisa coincidencia de las proyecciones
CheckProjection <- function(r, proj) {
  if(is.na(testN2@crs@projargs)){
    testN2@crs@projargs <- proj
    cat('sin proyeccion')
  }
  if (testN2@crs@projargs != proj){
    if (testN2@crs@projargs == "+proj=longlat +ellps=WGS84 +towgs84=0,0,0,0,0,0,0 +no_defs")
    { testN2@crs@projargs <- proj
    cat('Asignando datum_')
    } 
    else {
      testN2 <- projectRaster(testN2, crs = proj)
      compareRaster(testN2, clcBrick, extent = TRUE, rowcol = TRUE, crs = TRUE)
      cat('Resampling ... \n' )
    }
  }
}


# 2. Calcular el tamanno de ocurrencia de la espcie km2
EstimateRangeSize <- function(r, area.raster) {
  outArea_fx <- cellStats( r * area.raster, stat = "sum")
  return(outArea_fx)
}

# 3. Minimo poligono convexo para Raster
PredictMcpRast <- function(r, area.raster, rast) {
  cells <- Which(r == 1, cells = T)
  #pts<-xyFromCell(r, c(1, ncol(r), ncell(r)-ncol(r)+1, ncell(r)))
  pts <-  xyFromCell(r, cell = cells) 
  ch <- convHull(pts) 
  ch.pred <- predict(ch, r)
  ch.area <- cellStats(ch.pred * area.raster, "sum")
  if (rast == T) {
    writeRaster(ch.pred, paste0(sppFolder,'/mcp_Rast.tif'), overwrite=TRUE)
  }
  return (list (ch.area = ch.area, ch = ch.pred))
}

# 4. Extensión de ocurrencia en km2 (registros)

# EOO <- function (rast,s,sppPath){
#   library(red)
#   recc <- read.csv(as.character(sppPath$Rec_file[s]), sep=",",as.is = T)
#   if(dim(recc)[1]==0){
#     return (MCPrec_km2 = NA)
#   }else{
#     #recc <- recc[complete.cases(recc[ ,"longitud"]),]
#     recc <- recc[complete.cases(recc[ ,"lon"]),]#revisar el argumento sep
#     MCPrec_km2<-eoo(data.frame(recc$lon,recc$lat))
#     return(MCPrec_km2)
#   }
# }

PredictMcpRec <- function (r, Proj_col, rast, s, sppPath, proj, wr.mcp, col = gadm_colombia) {
  recc <- data.table::fread(as.character(sppPath$Rec_file[s]))
  recc <- as.data.frame(recc)
  #revisar el argumento sep
  if(dim(recc)[1]==0){
    return (list (MCP_recp = NA, MCPrec_km2 = NA))
  }else{
    
    lon_columns <- c("Lon", "Longitud", "Longitude", "longitud", "decimalLongitude", "lon", "longitude", "LONG")
    lat_columns <- c("Lat", "Latitud", "Latitude", "latitud", "decimalLatitude", "lat", "latitude", "LAT")
    
    lon <- recc %>% select(any_of(lon_columns)) %>% .[, 1]
    lat <- recc %>% select(any_of(lat_columns)) %>% .[, 1]
    
    # lon_lat <- matrix(nrow = nrow(recc), ncol = 2)
    # lon_lat[,1] <- lon
    # lon_lat[,2] <- lat
    
    # in.pts <- SpatialPoints(lon_lat, proj4string = CRS(proj))
    # cells <- unique(cellFromXY(r, in.pts))
    #   if(length(cells) > 2){
    #     ch_pol <- convHull(lon_lat)
    #     ch_pol@polygons@proj4string@projargs <- proj
    #     ch_proj <- spTransform(ch_pol@polygons, crs("+init=epsg:3116")) ##EPSG 3116 codigo Magna origen Bogota
    #     ch_proj <- spTransform(ch_pol@polygons, Proj_col)
    #     MCPrec_km2 <- gArea(ch_proj) / 1000000
    #     return (list (MCP_recp = ch_proj, MCPrec_km2 = MCPrec_km2))
    #   } else {
    #     return (list (MCP_recp = NA, MCPrec_km2 = NA))
    #   }
  
    
    lat_lon_sp <-  data.frame("lat" = lat, "lon" = lon,  "sp")
    lat_lon_sp <- lat_lon_sp[complete.cases(lat_lon_sp), ]
    
    colnames(lat_lon_sp) <- c("ddlat", "ddlon", "tax")
    
    eoo. <- ConR::EOO.computing(lat_lon_sp, exclude.area = T, country_map = gadm_colombia, write_results = F) %>% 
      unlist() 
    names(eoo.) <- "MCPrec_km2"
    return(eoo.)
  }

}

# 5. Área de ocupación en km2 (registros)

AOO <- function (r, Proj_col, rast, s, sppPath, proj, col = gadm_colombia){
  
  recc <- data.table::fread(as.character(sppPath$Rec_file[s]))
  recc <- as.data.frame(recc)#revisar el argumento sep
  if(dim(recc)[1]==0){
    return (AOO = NA)
  }else{
    
    lon_columns <- c("Lon", "Longitud", "Longitude", "longitud", "decimalLongitude", "lon", "longitude", "LONG")
    lat_columns <- c("Lat", "Latitud", "Latitude", "latitud", "decimalLatitude", "lat", "latitude", "LAT")
    
    # Extraer las coordenadas de longitud y latitud
    lon <- recc %>% select(any_of(lon_columns)) %>% .[, 1]
    lat <- recc %>% select(any_of(lat_columns)) %>% .[, 1]
    
    # Crear un objeto SpatialPoints con las coordenadas
    lon_lat <- cbind(lon, lat)
    in.pts <- SpatialPoints(lon_lat, proj4string = CRS(proj))
    
    # Filtrar los puntos que están dentro de la región de interés
    pts.in.col <- !is.na(over(in.pts, col)[, 1])
    
    # Preparar los datos para usar en ConR
    lat_lon_sp <- data.frame("lat" = lat, "lon" = lon, "sp")
    lat_lon_sp <- lat_lon_sp[pts.in.col, ]
    lat_lon_sp <- lat_lon_sp[complete.cases(lat_lon_sp), ]
    
    # Renombrar las columnas según el formato requerido por ConR
    colnames(lat_lon_sp) <- c("ddlat", "ddlon", "tax")
    
    aoo. <- ConR::AOO.computing(lat_lon_sp)
    names(aoo.) <- "AOO"
    return(aoo.)
  }
}

# 6. Habitat CLC
 HabitatAreaClc<- function (r, area.raster, clcBrick., clcTif, rast){
   r <- r * area.raster 
   clc_area <- rep( 0, nlayers(clcBrick))
   clc_area <- data.frame(matrix(0,nrow=1,ncol=nlayers(clcBrick)))
   colnames(clc_area) <- gsub('.tif', '', clcTif)
   for(l in 1:nlayers(clcBrick)){
     cat('review', names(clcBrick[[l]]), 'data \n' )
     clcSp <- (r * clcBrick[[l]])
     clc_area[1,l] <- cellStats(clcSp, stat ="sum", na.rm = TRUE)
   }
   return(clc_area)
 }

# 7. Historico perdida de bosque
ForestLoss <- function(r, area.raster, f90, f00, f05, f10, f12, f13, f14, f16, rast=TRUE) { 
  r <- r *area.raster
  com90 <- r * f90 # Los valores f90, f00, f05, f10, f12, corresponden a la proporcion de bosque en el pixel. El rango es de 0 a 1, siendo 1 el area total del pixel.
  com00 <- r * f00
  com05 <- r * f05
  com10 <- r * f10
  com12 <- r * f12
  com13 <- r * f13
  com14 <- r * f14
  com16 <- r * f16
  forestArea <- data.frame(y1990 = cellStats(com90, sum),
                           y2000 = cellStats(com00, sum),
                           y2005 = cellStats(com05, sum),
                           y2010 = cellStats(com10, sum),
                           y2012 = cellStats(com12, sum),
                           y2013 = cellStats(com13, sum),
                           y2014 = cellStats(com14, sum),
                           y2016 = cellStats(com16, sum))
  return(forestArea)
}

# 8. Escenarios 2030
Escenarios2030 <- function (r, area.raster, con2030_res,  des2030_res, his2030_res, sppFolder, rast) {
  inRaster <- r *area.raster
  escenarios2030 <- data.frame (con_2030 = NA, des_20302 = NA, his_2030 = NA) 
  #con2030
  inRaster_2030c <- con2030_res * inRaster
  escenarios2030[1,1] <- cellStats (inRaster_2030c, stat = "sum")
  #des2030
  inRaster_2030d <- des2030_res * inRaster
  escenarios2030[1,2] <- cellStats (inRaster_2030d, stat = "sum")
  #his2030
  inRaster_2030h <- his2030_res * inRaster
  escenarios2030[1,3] <-cellStats (inRaster_2030h, stat = "sum")
  return (escenarios2030)
}


# 9. Areas protegidas
AllProtectedFigures <- function(r, ap, pn, sc, ot, area.raster, rast){
  r <- r * area.raster
  spOccEx <- EstimateRangeSize( r = testN2, area.raster = area.raster) ##.............. Deber?a dividirse por el area dentro del poligono
  
  ap[ap != 0] <- 1
  intAp <- (ap * r)
  areaAp <- cellStats(intAp, stat = "sum")
  
  pn[pn != 0] <- 1
  intPn <- (pn * r)
  areaPn <- cellStats(intPn, stat = "sum") #Suma de las probabilidades de ocurrencia dentro de 'pn' para el calculo de las estadisticas
  
  sc[sc != 0] <- 1
  intSc <- (sc * r)
  intSc<-reclassify(intSc, c(-Inf,0,NA, 0.2,Inf,1))
  areaSc <- cellStats(intSc, stat = "sum")
  
  ot[ot != 0] <- 1
  intOt <- (ot * r)
  areaOt <- cellStats(intOt, stat = "sum")
  
  repr <- data.frame(protArea = areaAp*100/spOccEx, #Proporcion del area de distribucion entre el area protegida y el total
                     natPark =  areaPn*100/spOccEx,
                     civilRes = areaSc*100/spOccEx,
                     othFigur = areaOt*100/spOccEx)
  if (rast==T) {
    rastBrc <- stack(intAp, intPn, intSc, intOt)
    writeRaster(intAp, paste0(sppFolder,'/protArea.tif'), overwrite=TRUE)
    writeRaster(intPn, paste0(sppFolder,'/natPark.tif'), overwrite=TRUE)
    writeRaster(intSc, paste0(sppFolder,'/civilRes.tif'), overwrite=TRUE)
    writeRaster(intOt, paste0(sppFolder,'/othFigur.tif'), overwrite=TRUE)
    
    print('TIFF protected areas')
    
  }
  return(repr)
}


# AMENAZAS 

# 9.human foot print hfp
HumanFootPrint <- function (r, hfp, rast){
  r <- r * area.raster
  hfp_area <- rep( 0, nlayers(hfp))
  hfp_area <- data.frame(matrix(0,nrow=1,ncol=nlayers(hfp)))
  colnames(hfp_area) <- c("Alto","Bajo","Medio","Natural")
  for(l in 1:nlayers(hfp)){
    catHfp <- r * hfp[[l]]
    catHfp[catHfp == 0] <- NA
    areaCat <- cellStats(catHfp, stat = "sum") # sum(catHfp[], na.rm = TRUE)
    porcCat = areaCat*100/RangeSize
    hfp_area[1,l] <- porcCat
  }
  if (rast == T) {
    writeRaster(hfp, paste0(sppFolder,'/hfp.tif'), overwrite=TRUE)
  }
  return(hfp_area)
}


# 10. Titulos mineros
TitulosMineros <- function(r, area.raster, titMin, rast) {
  r <- r * area.raster
  nTit <- r * titMin
  nTit[nTit == 0] <- NA
  areaMin <- cellStats(nTit, stat = "sum") # sum(nTit[], na.rm = TRUE)
  porcMin <- areaMin*100/RangeSize
  
  if (rast == T) {
    print ('Raster titulos mineros')
    writeRaster(nTit, paste0(sppFolder,'/Tit_min.tif'), overwrite=TRUE)
  }
  return(porcMin)
}


