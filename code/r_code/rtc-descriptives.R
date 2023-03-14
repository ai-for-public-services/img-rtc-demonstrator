# Purpose: Ensure RTCs are usable for analyses, run some descriptive analyses
# Author: John Francis
# Date Created: Oct. 25, 2022

# Load Dependencies
library(tidyverse)
library(terra)
library(sf)
library(sp)
library(ggplot2)
library(tmap)
library(basemaps)

################################################################################
# Data Notes
################################################################################
#https://www.cambs.police.uk/advice/advice-and-information/rs/road-safety/collisions/
# You don't need to report a collision to the police if you've exchanged details,
# nobody was injured and there are no allegations of driving offences.
# 
# You must report the collision to the police if you were unable to exchange details 
# at the scene, if anyone was injured, or if you suspect that the other person may have 
# committed a driving offence. 


################################################################################
# Getting RTC data for all of the UK
################################################################################
# DATA SOURCE
# made for using RTC data https://github.com/ropensci/stats19/

# read in data
crashes17 <- stats19::get_stats19(year = 2017, type = "accident")
casualties17 <- stats19::get_stats19(year = 2017, type = "casualty")
crashes18 <- stats19::get_stats19(year = 2018, type = "accident")
casualties18 <- stats19::get_stats19(year = 2018, type = "casualty")
crashes19 <- stats19::get_stats19(year = 2019, type = "accident")
casualties19 <- stats19::get_stats19(year = 2019, type = "casualty")
crashes20 <- stats19::get_stats19(year = 2020, type = "accident")
casualties20 <- stats19::get_stats19(year = 2020, type = "casualty")


# extract casuality info and append to RTC data
casualties17 <- casualties17 %>% mutate(
  cyclist= if_else(str_detect(casualty_type,"Cyclist")==TRUE,1,0),
  pedestrian= if_else(str_detect(casualty_type,"Pedestrian")==TRUE,1,0),
  motorcycle= if_else(str_detect(casualty_type,"Motorcycle")==TRUE,1,0)
) %>% group_by(accident_reference) %>% summarise(
  cyclist=max(cyclist,na.rm = T),
  pedestrian=max(pedestrian,na.rm = T),
  motorcycle=max(motorcycle,na.rm = T),
)

casualties18 <- casualties18 %>% mutate(
  cyclist= if_else(str_detect(casualty_type,"Cyclist")==TRUE,1,0),
  pedestrian= if_else(str_detect(casualty_type,"Pedestrian")==TRUE,1,0),
  motorcycle= if_else(str_detect(casualty_type,"Motorcycle")==TRUE,1,0)
) %>% group_by(accident_reference) %>% summarise(
  cyclist=max(cyclist,na.rm = T),
  pedestrian=max(pedestrian,na.rm = T),
  motorcycle=max(motorcycle,na.rm = T),
)

casualties19 <- casualties19 %>% mutate(
  cyclist= if_else(str_detect(casualty_type,"Cyclist")==TRUE,1,0),
  pedestrian= if_else(str_detect(casualty_type,"Pedestrian")==TRUE,1,0),
  motorcycle= if_else(str_detect(casualty_type,"Motorcycle")==TRUE,1,0)
) %>% group_by(accident_reference) %>% summarise(
  cyclist=max(cyclist,na.rm = T),
  pedestrian=max(pedestrian,na.rm = T),
  motorcycle=max(motorcycle,na.rm = T),
)
casualties19[casualties19=='-Inf'] <- 0

casualties20 <- casualties20 %>% mutate(
  cyclist= if_else(str_detect(casualty_type,"Cyclist")==TRUE,1,0),
  pedestrian= if_else(str_detect(casualty_type,"Pedestrian")==TRUE,1,0),
  motorcycle= if_else(str_detect(casualty_type,"Motorcycle")==TRUE,1,0)
) %>% group_by(accident_reference) %>% summarise(
  cyclist=max(cyclist,na.rm = T),
  pedestrian=max(pedestrian,na.rm = T),
  motorcycle=max(motorcycle,na.rm = T),
)
casualties20[casualties20=='-Inf'] <- 0


# join by accident reference
crashes17 <- left_join(crashes17,casualties17,by="accident_reference")
crashes18 <- left_join(crashes18,casualties18,by="accident_reference")
crashes19 <- left_join(crashes19,casualties19,by="accident_reference")
crashes20 <- left_join(crashes20,casualties20,by="accident_reference")
rm(casualties17,casualties18,casualties19,casualties20)

# grab extents
cambridge_extent = c(xmin = 541000, xmax = 551000, ymax = 254000, ymin = 264000)
gloucester_extent= c(xmin = 379000, xmax = 389000, ymax = 222000, ymin = 212000)
oxford_extent= c(xmin = 447000, xmax = 457000, ymax = 212000 , ymin = 202000)

# filter out few cases without location data
crashes17 <- crashes17 %>% dplyr::filter(is.na(location_easting_osgr)==FALSE)
crashes18 <- crashes18 %>% dplyr::filter(is.na(location_easting_osgr)==FALSE)
crashes19 <- crashes19 %>% dplyr::filter(is.na(location_easting_osgr)==FALSE)
crashes20 <- crashes20 %>% dplyr::filter(is.na(location_easting_osgr)==FALSE)

crashes17 <- st_as_sf(crashes17,coords = c("location_easting_osgr","location_northing_osgr"),crs=st_crs(27700))
crashes18 <- st_as_sf(crashes18,coords = c("location_easting_osgr","location_northing_osgr"),crs=st_crs(27700))
crashes19 <- st_as_sf(crashes19,coords = c("location_easting_osgr","location_northing_osgr"),crs=st_crs(27700))
crashes20 <- st_as_sf(crashes20,coords = c("location_easting_osgr","location_northing_osgr"),crs=st_crs(27700))

crashes17_cam <- crashes17 %>% st_filter(st_as_sfc(st_bbox(cambridge_extent,crs = st_crs(27700))))
crashes18_cam <- crashes18 %>% st_filter(st_as_sfc(st_bbox(cambridge_extent,crs = st_crs(27700))))
crashes19_cam <- crashes19 %>% st_filter(st_as_sfc(st_bbox(cambridge_extent,crs = st_crs(27700))))
crashes20_cam <- crashes20 %>% st_filter(st_as_sfc(st_bbox(cambridge_extent,crs = st_crs(27700))))

crashes17_oxf <- crashes17 %>% st_filter(st_as_sfc(st_bbox(oxford_extent,crs = st_crs(27700))))
crashes18_oxf <- crashes18 %>% st_filter(st_as_sfc(st_bbox(oxford_extent,crs = st_crs(27700))))
crashes19_oxf <- crashes19 %>% st_filter(st_as_sfc(st_bbox(oxford_extent,crs = st_crs(27700))))
crashes20_oxf <- crashes20 %>% st_filter(st_as_sfc(st_bbox(oxford_extent,crs = st_crs(27700))))

crashes17_glo <- crashes17 %>% st_filter(st_as_sfc(st_bbox(gloucester_extent,crs = st_crs(27700))))
crashes18_glo <- crashes18 %>% st_filter(st_as_sfc(st_bbox(gloucester_extent,crs = st_crs(27700))))
crashes19_glo <- crashes19 %>% st_filter(st_as_sfc(st_bbox(gloucester_extent,crs = st_crs(27700))))
crashes20_glo <- crashes20 %>% st_filter(st_as_sfc(st_bbox(gloucester_extent,crs = st_crs(27700))))

rm(crashes17,crashes18,crashes19,crashes20)

# do the 2017/2020 data in a similar manner
crashes20_glo <- crashes20_glo %>% mutate(
  surface=if_else(road_surface_conditions=="Dry","dry","wet"),
  light=if_else(light_conditions=="Daylight","Light","Dark"),
  # pedestrian=if_else(Pedestrian==0,0,1),
  # cycle=if_else(Cycles==0,0,1),
  # time?
  Time=lubridate::hour(lubridate::hms(time)),
  time_of_day=case_when(
    Time<5~"Night",
    Time>=5 & Time<10 ~"Morning",
    Time>=10 & Time<15 ~"Middle of Day",
    Time>=15 & Time<20 ~"Afternoon/Evening",
    Time>=20 ~"Night"),
  year=accident_year,
  city="gloucester") %>% select(
    time_of_day,surface,accident_severity,light,speed_limit,number_of_vehicles,
    number_of_casualties,accident_index,year,cyclist,pedestrian,motorcycle) %>% janitor::clean_names() %>%
  mutate(lon = st_coordinates(.)[,1],
         lat = st_coordinates(.)[,2]) %>% st_drop_geometry()

# combine to save
crashes_all <- bind_rows(crashes17_cam,
                         crashes18_cam,
                         crashes19_cam,
                         crashes20_cam,
                         crashes17_oxf,
                         crashes18_oxf,
                         crashes19_oxf,
                         crashes20_oxf,
                         crashes17_glo,
                         crashes18_glo,
                         crashes19_glo,
                         crashes20_glo)
#write.csv(crashes_all,"data/processed/rtc/all-rtc.csv",row.names = F)

################################################################################
## 28/11/22 Adding in some XY info for mapping
library(raster)
all_rtc_points <- read_csv("data/processed/rtc/all_rtc_points_03012023.csv")


x_list = list()
y_list = list()

all_rtc_points$file_path <- str_replace(all_rtc_points$file_path,"cambridge","cambdrige")

for(i in 1:nrow(all_rtc_points)){
  print(i)
  # read in corresponding raster
  if(file.exists(all_rtc_points$file_path[i])==TRUE){
    temp_rast <- raster::raster(all_rtc_points$file_path[i])
    # convert to sf and get centroid
    poly<-st_as_sfc(st_bbox(temp_rast))
    cent<-st_centroid(poly)
    # Append the point coordinates
    x_list <- append(x_list,st_coordinates(cent)[1])
    y_list <- append(y_list,st_coordinates(cent)[2])
  }
  else{
    x_list <- append(x_list,"file does not exist")
    y_list <- append(y_list,"file does not exist")
  }
  
}

all_rtc_points$X <- unlist(x_list)
all_rtc_points$Y <- unlist(y_list)

write.csv(all_rtc_points,"data/processed/rtc/all_rtc_points.csv",row.names = F)

################################################################################
# 29/11/2022 Mock up some maps in R
rtc_points <- read_csv("data/processed/rtc/all_rtc_points_03012023.csv")
rtc_points <- rtc_points %>% mutate(
  location = case_when(
    str_detect(file_path,"cam")==T~"cam",
    str_detect(file_path,"glo")==T~"glo",
    str_detect(file_path,"oxf")==T~"oxf",
  )
)
rtc_points$merge <- paste0(rtc_points$point_id,rtc_points$location)

final_points <- read_csv("data/processed/image-features/final_points_200123.csv")
final_points$merge <- paste0(final_points$row_id,final_points$location)
rtc_points <- rtc_points %>% filter(rtc_points$merge %in% final_points$merge)

rtc_points <- rtc_points %>% mutate(
  city= case_when(
    str_detect(file_path,"cam")==TRUE~"cambrdige",
    str_detect(file_path,"glo")==TRUE~"gloucester",
    str_detect(file_path,"oxf")==TRUE~"oxford",
  )
)
rtc_points <- rtc_points %>% filter(!X %in% "file does not exist")
rtc_points <- st_as_sf(rtc_points, coords = c("X", "Y"), crs = 27700)
rtc_points %>% st_geometry() %>% plot()

cam_rtc <- rtc_points %>% filter(city %in% "cambrdige")
glo_rtc <- rtc_points %>% filter(city %in% "gloucester")
oxf_rtc <- rtc_points %>% filter(city %in% "oxford")

cam_rtc %>% st_geometry() %>% plot()
glo_rtc %>% st_geometry() %>% plot()
oxf_rtc %>% st_geometry() %>% plot()

cam_roads <- read_sf("data/raw/cambridge_osm_roads_full.shp")
cam_roads <- st_transform(cam_roads, crs=27700)
cam_roads <- st_crop(cam_roads,st_bbox(c(xmin = 541000, xmax = 551000, ymax = 254000, ymin = 264000)))
cam_roads <- cam_roads %>% filter(!fclass %in% c(
  "footway","bridleway","cycleway","steps")) 
cam_roads <- cam_roads %>% filter(str_detect(fclass,"track")==FALSE)


glo_roads <- read_sf("data/raw/gloucester_osm_roads_full.shp")
glo_roads <- st_transform(glo_roads, crs=27700)
glo_roads <- st_crop(glo_roads,st_bbox(c(xmin = 379000, xmax = 389000, ymax = 222000, ymin = 212000)))
glo_roads <- glo_roads %>% filter(!fclass %in% c(
  "footway","bridleway","cycleway","steps")) 
glo_roads <- glo_roads %>% filter(str_detect(fclass,"track")==FALSE)

oxf_roads <- read_sf("data/raw/oxford_osm_roads_full.shp")
oxf_roads <- st_transform(oxf_roads, crs=27700)
oxf_roads <- st_crop(oxf_roads,st_bbox(c(xmin = 447000, xmax = 457000, ymax = 212000 , ymin = 202000)))
oxf_roads <- oxf_roads %>% filter(!fclass %in% c(
  "footway","bridleway","cycleway","steps")) 
oxf_roads <- oxf_roads %>% filter(str_detect(fclass,"track")==FALSE)
#cambridge: c(xmin = 541000, xmax = 551000, ymax = 254000, ymin = 264000)
#gloucester: c(xmin = 379000, xmax = 389000, ymax = 222000, ymin = 212000)
#oxford: c(xmin = 447000, xmax = 457000, ymax = 212000 , ymin = 202000)

cam_merc <- st_transform(cam_roads,3857)
mybbox <- st_bbox(cam_merc)
bm <- basemaps::basemap_raster(mybbox, map_service = "esri", map_type = "world_light_gray_base")

cam_merc <- st_transform(glo_roads,3857)
mybbox <- st_bbox(cam_merc)
bm1 <- basemaps::basemap_raster(mybbox, map_service = "esri", map_type = "world_light_gray_base")

cam_merc <- st_transform(oxf_roads,3857)
mybbox <- st_bbox(cam_merc)
bm2 <- basemaps::basemap_raster(mybbox, map_service = "esri", map_type = "world_light_gray_base")

# https://jakob.schwalb-willmann.de/basemaps/
# bm  <- raster::projectRaster(bm,crs = crs(cam_rtc))
# bm[bm < 0] = 0

m1<-tm_shape(bm) +
  tm_rgb() +
  tm_shape(cam_rtc) +
  tm_dots("rtc_count_total",size = .05, palette=c("#FEE0D2","#FB6A4A","#CB181D","#67000D"), 
          breaks=c(0,5,10,20,Inf),title = "Total RTC Count",jitter=.06) +
 # tm_shape(cam_roads) +
 #   tm_lines(alpha = .3,lwd=1) +
  tm_layout(legend.outside = TRUE,
            main.title = "Cambridge RTCs 2017-2020")
m1

m2<-tm_shape(bm1) +
  tm_rgb() +
  tm_shape(glo_rtc) +
  tm_dots("rtc_count_total",size = .05, palette=c("#FEE0D2","#FB6A4A","#CB181D","#67000D"), 
          breaks=c(0,5,10,20,Inf),title = "Total RTC Count",jitter=.06) +
  # tm_shape(glo_roads) +
  # tm_lines(alpha = .3) +
  tm_layout(legend.outside = TRUE,
            main.title = "Gloucester RTCs 2017-2020")

m3<-tm_shape(bm2) +
  tm_rgb() +
  tm_shape(oxf_rtc) +
  tm_dots("rtc_count_total",size = .05, palette=c("#FEE0D2","#FB6A4A","#CB181D","#67000D"), 
          breaks=c(0,5,10,20,Inf),title = "Total RTC Count",jitter=.06) +
  # tm_shape(oxf_roads) +
  # tm_lines(alpha = .3) +
  tm_layout(legend.outside = TRUE,
            main.title = "Oxford RTCs 2017-2020")

mymap <- tmap_arrange(m1,m2,m3, ncol=2,nrow = 2,outer.margins = .1)


#tmap_save(mymap,filename = "reports/figures/rtc_locations.png", dpi=500)
#cam_rtc$nearest_point <- cam_rtc$geometry[st_nearest_feature(cam_rtc, cam_rtc)]


################################################################################
# Make a basic england map with gloucester, cambridge and Oxford labelled

uk <- st_read("data/raw/Countries_(December_2022)_GB_BFE/CTRY_DEC_2022_GB_BFE.shp")
uk <- uk %>% filter(CTRY22NM %in% "England")

Cam <-  c(52.205967, 0.130122)
Ox <-  c(51.754207, -1.259257)
Glo <- c(51.861458, -2.240096)
points <- st_as_sf(as.data.frame(rbind(Cam,Ox,Glo)),coords = c("V2", "V1"), crs = 4326)
points <- st_transform(points, crs = 27700)

tm_shape(uk) +
  tm_polygons(alpha=0) +
  tm_shape(points) +
  tm_dots(size=.4)
