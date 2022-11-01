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
  # will experiment with the OSM road shapefile as well as the OS roads file
  
  # crop roads to the extent of my images
  roads <- st_crop(roads,st_bbox(total_extent))
  
  sampled_points <- st_line_sample(roads, density = point_density) # one point every 25 m
  sampled_points <- st_cast(sampled_points, "POINT") # cast to point
  # 5,935 roads, one point every 10m gives 62,425 points
  # 5,935 roads, one point every 25m gives 24,961 points
  # 5,935 roads, one point every 50m gives 12,459 points
  # 5,935 roads, one point every 100m gives 6,145 points
  
}

# # Read in the RTC data
# cam_rtc <- read_csv("data/processed/rtc/cam-rtc.csv")
# 
# # Sample Points
# sampled_points <- generate_sample_ids(file_name="data/raw/Download_2087242/open-map-local_4707745/TL_Road.shp",
#                                       point_density=1/100,
#                                       total_extent=c(xmin = 541000, xmax = 551000, ymax = 254000, ymin = 264000))

# Spatial Join based on some sort of set of rules
create_outcome_data <- function(road_network_path = "data/raw/Download_2087242/open-map-local_4707745/TL_Road.shp",
                                 aerial_image_extent = c(xmin = 541000, xmax = 551000, ymax = 254000, ymin = 264000),
                                 sampled_point_density = 1/100, # point per meter 1/100 = 1 every 100m
                                 rtc_data_path = "data/processed/rtc/cam-rtc.csv",
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
    cycle_count = if_else(name=="cycle" & value=="1",1,0),
    pedestrian_count = if_else(name=="pedestrian" & value=="1",1,0),
    serious_count = if_else(name=="severity" & (
      value=="1. Fatal" | value=="2. Serious"| value=="Serious"),1,0),
    dark_count = if_else(name=="light" & value=="Dark",1,0),
    multi_vehicle_count = if_else(name=="number_vehicles" & 
                                    (value=="2" | value=="3" | value=="4" | value=="5" |value=="6" ),1,0),
    speed_above30_count = if_else(name=="speed_limit" &  (
      value=="40" | value=="50"| value=="60"| value=="70"),1,0),
    roadclass_a_count = if_else(name=="road_class" &  value=="A",1,0),
    roadclass_c_count = if_else(name=="road_class" &  value=="C",1,0)
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


cam_rtc <- create_outcome_data(road_network_path = "data/raw/Download_2087242/open-map-local_4707745/TL_Road.shp",
                               aerial_image_extent = c(xmin = 541000, xmax = 551000, ymax = 254000, ymin = 264000),
                               sampled_point_density = 1/100, # point per meter 1/100 = 1 every 100m
                               rtc_data_path = "data/processed/rtc/cam-rtc.csv",
                               collision_buffer = 50)

# only 1009 unique points had an RTC within 50m
cam_rtc %>% ggplot(aes(rtc_count_total)) + 
  geom_bar(stat='count', width=.5)  +
  geom_text(stat='count', aes(label=..count..), vjust=-1) 

