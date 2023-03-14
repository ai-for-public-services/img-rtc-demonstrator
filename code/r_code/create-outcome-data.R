# Purpose: Create outcome datasets linking sampled points and RTC data
# Author: John Francis
# Date Created: Nov. 1, 2022

# Load Dependencies
library(tidyverse)
library(terra)
library(sf)
library(sp)

# create a function to select points from the roads file
generate_sample_ids <- function(file_name="data/raw/Download_2087242/open-map-local_4707745/TL_Road.shp",
                               point_density=1/100,
                               total_extent=c(xmin = 541000, xmax = 551000, ymax = 254000, ymin = 264000)){
  # read in the roads shapefile, note that TL correspondonds to the area with Cambridge
  roads <- read_sf(file_name)
  
  # transform to BNG
  roads <- st_transform(roads, crs=27700)
  
  # crop roads to the extent of my images
  roads <- st_crop(roads,st_bbox(total_extent))
  
  # for OSM remove paths unsuitable for cars https://download.geofabrik.de/osm-data-in-gis-formats-free.pdf
  roads <- roads %>% filter(!fclass %in% c(
    "footway","bridleway","cycleway","steps")) 
  
  # getting rid of these tiny roads as well - appear to be private anyways
  roads <- roads %>% filter(str_detect(fclass,"track")==FALSE)
  
  # ensure road file is in linestring
  roads <- st_cast(st_cast(roads, "MULTILINESTRING"),"LINESTRING") # have to double cast to avoid losing information
  
  sampled_points <- st_line_sample(roads, density = point_density) # one point every 25 m
  sampled_points <- st_cast(sampled_points, "POINT") # cast to point
  return(sampled_points)
  
}

# Extents
#cambridge: c(xmin = 541000, xmax = 551000, ymax = 254000, ymin = 264000)
#gloucester: c(xmin = 379000, xmax = 389000, ymax = 222000, ymin = 212000)
#oxford: c(xmin = 447000, xmax = 457000, ymax = 212000 , ymin = 202000)


# Spatial Join based on some sort of set of rules
create_outcome_data <- function(road_network_path = "data/raw/Download_2087242/open-map-local_4707745/TL_Road.shp",
                                 aerial_image_extent = c(xmin = 541000, xmax = 551000, ymax = 254000, ymin = 264000),
                                 sampled_point_density = 1/50, 
                                 rtc_data_path = "data/processed/rtc/all-rtc.csv",
                                 collision_buffer = 50 # number in meters
                                 ){
  # Sample Points
  sampled_points <- generate_sample_ids(file_name=road_network_path,
                                        point_density=sampled_point_density,
                                        total_extent=aerial_image_extent)
  
  sampled_points <- st_as_sf(sampled_points) # need this for the join later
  sampled_points$point_id <- 1:nrow(sampled_points)
  # Read in the RTC data
  rtc_data <- read_csv(rtc_data_path)
  #rtc_data$rtc_id <- 1:nrow(rtc_data)
  
  # Convert to a spatial object
  rtc_data <- st_as_sf(rtc_data,coords = c("lon","lat"),crs=st_crs(27700))
  
  rtc_data <- rtc_data %>% mutate(
    serious_cyclist= if_else(accident_severity=="Serious" & cyclist==1,1,0),
    serious_pedestrian= if_else(accident_severity=="Serious" & pedestrian==1,1,0),
    serious_dark= if_else(accident_severity=="Serious" & light=="Dark",1,0),
    serious_wet= if_else(accident_severity=="Serious" & surface=="wet",1,0),
    serious_dark_wet= if_else(accident_severity=="Serious" & surface=="wet" & light=="Dark",1,0),
    dark_pedestrian= if_else(light=="Dark" & pedestrian==1,1,0),
    dark_cyclist= if_else(light=="Dark" & cyclist==1,1,0),
    wet_cyclist= if_else(surface=="wet" & cyclist==1,1,0),
    dark_wet_cyclist= if_else(surface=="wet" & light=="Dark" & cyclist==1,1,0),
  )
  
  # Create buffers around each collision point
  rtc_data_buffer <- st_buffer(rtc_data, collision_buffer)
  
  # Join the buffers with the sampled points
  out_df <- st_join(sampled_points,rtc_data_buffer)
  
  # only keep points that have at least one RTC
  out_df <- out_df %>% filter(is.na(year)==FALSE) %>% st_drop_geometry()
  
  
  out_df_long <- out_df %>% mutate(across(everything(), as.character))
  out_df_long <- out_df_long %>% pivot_longer(
    !point_id
  )
  out_df_long <- out_df_long %>% mutate(
    night_count = if_else(name=="time_of_day" & value=="Night",1,0),
    morning_count = if_else(name=="time_of_day" & value=="Morning",1,0),
    afternoon_evening_count = if_else(name=="time_of_day" & value=="Afternoon/Evening",1,0),
    mid_of_day_count = if_else(name=="time_of_day" & value=="Middle of Day",1,0),
    wet_count = if_else(name=="surface" & value=="wet",1,0),
    cycle_count = if_else(name=="cyclist" & value=="1",1,0),
    pedestrian_count = if_else(name=="pedestrian" & value=="1",1,0),
    motorcycle_count = if_else(name=="motorcycle" & value=="1",1,0),
    serious_count = if_else(name=="accident_severity" & (
      value=="Fatal" | value=="Serious"),1,0),
    dark_count = if_else(name=="light" & value=="Dark",1,0),
    multi_vehicle_count = if_else(name=="number_vehicles" &
                                    (value=="2" | value=="3" | value=="4" | value=="5" |value=="6" |value=="7" |value=="10" ),1,0),
    speed_above30_count = if_else(name=="speed_limit" &  (
      value=="40" | value=="50"| value=="60"| value=="70"),1,0),
  )
  
  out_df_long <- out_df_long %>% mutate(
    serious_cyclist= if_else(name=="serious_cyclist" & value=="1",1,0),
    serious_pedestrian= if_else(name=="serious_pedestrian" & value=="1",1,0),
    serious_dark= if_else(name=="serious_dark" & value=="1",1,0),
    serious_wet= if_else(name=="serious_wet" & value=="1",1,0),
    serious_dark_wet= if_else(name=="serious_dark_wet" & value=="1",1,0),
    dark_pedestrian= if_else(name=="dark_pedestrian" & value=="1",1,0),
    dark_cyclist= if_else(name=="dark_cyclist" & value=="1",1,0),
    wet_cyclist= if_else(name=="wet_cyclist" & value=="1",1,0),
    dark_wet_cyclist= if_else(name=="dark_wet_cyclist" & value=="1",1,0),
  )

  
  out_df_wide <- out_df_long %>% select(-value,-name) %>% group_by(
    point_id) %>% summarise(across(everything(), list(sum)))
  names(out_df_wide)<- gsub("_1","",names(out_df_wide))
  count_per_year <- out_df %>% group_by(point_id,year) %>% summarise(
    rtc_count_by_year=n()) %>% ungroup() %>% pivot_wider(
      id_cols = point_id,
      names_from =year,
      names_prefix = "rtc_year_",
      values_from =rtc_count_by_year,
      values_fill =0)
  
  
  count_total <- out_df %>% group_by(point_id) %>% summarise(rtc_count_total=n())
  
  out_df_wide$point_id <- as.numeric(as.character(out_df_wide$point_id))
  out_df_wide <- left_join(out_df_wide,count_per_year,by=c("point_id"))
  out_df_wide <- left_join(out_df_wide,count_total,by=c("point_id"))
  return(out_df_wide)
}
#cambridge: c(xmin = 541000, xmax = 551000, ymax = 254000, ymin = 264000)
#gloucester: c(xmin = 379000, xmax = 389000, ymax = 222000, ymin = 212000)
#oxford: c(xmin = 447000, xmax = 457000, ymax = 212000 , ymin = 202000)

glo_rtc <- create_outcome_data(road_network_path = "data/raw/gloucester_osm_roads_full.shp",
                               aerial_image_extent = c(xmin = 379000, xmax = 389000, ymax = 222000, ymin = 212000),
                               sampled_point_density = 1/50, # point per meter 1/100 = 1 every 100m
                               rtc_data_path = "data/processed/rtc/all-rtc.csv",
                               collision_buffer = 55)
cam_rtc <- create_outcome_data(road_network_path = "data/raw/cambridge_osm_roads_full.shp",
                               aerial_image_extent = c(xmin = 541000, xmax = 551000, ymax = 254000, ymin = 264000),
                               sampled_point_density = 1/50, # point per meter 1/100 = 1 every 100m
                               rtc_data_path = "data/processed/rtc/all-rtc.csv",
                               collision_buffer = 55)
oxf_rtc <- create_outcome_data(road_network_path = "data/raw/oxford_osm_roads_full.shp",
                               aerial_image_extent = c(xmin = 447000, xmax = 457000, ymax = 212000 , ymin = 202000),
                               sampled_point_density = 1/50, # point per meter 1/100 = 1 every 100m
                               rtc_data_path = "data/processed/rtc/all-rtc.csv",
                               collision_buffer = 55)

# only 1009 unique points had an RTC within 50m
cam_rtc %>% ggplot(aes(rtc_count_total)) + 
  geom_bar(stat='count', width=.5)  +
  geom_text(stat='count', aes(label=..count..), vjust=-1) 

# append the image path to the files

glo_rtc <- glo_rtc %>% mutate(
  file_path = paste0("data/processed/glo-2018-25m/gloucester-25m-point-",point_id,".tif")
)

cam_rtc <- cam_rtc %>% mutate(
  file_path = paste0("data/processed/cam-2020-25m/cambridge-25m-point-",point_id,".tif")
)

oxf_rtc <- oxf_rtc %>% mutate(
  file_path = paste0("data/processed/oxf-2019-25m/oxford-25m-point-",point_id,".tif")
)

all_rtc <- bind_rows(glo_rtc,cam_rtc,oxf_rtc)


paths <- all_rtc$file_path
test <- terra::rast(paths[1])
plot(test)

#write.csv(all_rtc,"data/processed/rtc/all_rtc_points_03012023.csv",row.names = F)


# oxf <- oxf %>% st_drop_geometry() %>% select(-accident_index)
# 
# for(variable in names(oxf)){
#   print(paste("The table of", variable, "is: "))
#   print(table(oxf[variable]))
# }
