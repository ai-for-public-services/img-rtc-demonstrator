# Purpose: Clean RGB Images to be used in ML pipeline
# Author: John Francis
# Date Created: Oct. 20, 2022

# Load Dependencies
library(tidyverse)
library(terra)
library(sf)
library(sp)

################################################################################
#                          Data Cleaning Steps                                 #
################################################################################


################################################################################
# 1. Load in/Generate a clean road shapefile for the area of interest 
################################################################################
# NOTE: I know my shapefiles and images are all in British National Gird.
# If this was not the case for other datasets/images additional steps around reprojecting
# either the images, the shapefiles, or both may need to be done.

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


sampled_points <- generate_sample_ids(file_name="data/raw/Download_2087242/open-map-local_4707745/TL_Road.shp",
                                      point_density=1/100,
                                      total_extent=c(xmin = 541000, xmax = 551000, ymax = 254000, ymin = 264000))


################################################################################
# 2. Identify points along the road corresponding to the decided rules (with IDs)
################################################################################
# need to decide between these
# convert sf to shapefile
# shp_multiline <- as(roads, "Spatial")
# 
# # regularly sample points along line
# shp_points <- sp::spsample(shp_multiline, n=10, type="regular")
# 
# sf_linestring <- st_cast(sf_multiline, "LINESTRING")



################################################################################
# 3. Create two square buffers centered around each point
################################################################################
sample_20m_buffer <- st_buffer(sampled_points, 20, nQuadSegs = 1,endCapStyle = "SQUARE")

sample_200m_buffer <- st_buffer(sampled_points, 200, nQuadSegs = 1,endCapStyle = "SQUARE")

################################################################################
# 4. identify which image(s) are included within each buffer
################################################################################
# make into a spatvector to use terra
vect_200m_buffer<- vect(sample_200m_buffer)
vect_20m_buffer<- vect(sample_20m_buffer)

#for each image see which of the polygon intersect the img
imagelist <- list.files("data/raw/cambridge-rgb/getmapping-rgb-25cm-2016_4700173/tl/") %>% Filter(function(x) {str_detect(x,"jpg")}, .)
imagelist <- unlist(lapply(imagelist, function(i){paste0(
  "C:/Users/jfrancis/OneDrive - The Alan Turing Institute/Documents - AI for Government/6-Technical Projects/satellite-image-demonstrator/sat-img-demonstrator/data/raw/cambridge-rgb/getmapping-rgb-25cm-2016_4700173/tl/",i)}))
allrasters <- lapply(imagelist, terra::rast)

point_to_img_200m <- data.frame(point_id=1:6145,st_coordinates(sampled_points))
# for each image, what polygon fall within them
for(i in 1:length(allrasters)){
  a <- terra::is.related(vect_200m_buffer,allrasters[[i]],"intersects")
  a <- list(a)
  names(a)<- paste0("img_",i)
  point_to_img_200m <- bind_cols(point_to_img_200m,a)
}

point_to_img_200m %>% select(-point_id,-X,-Y) %>% rowSums() %>% table()

# 0    1    2    3    4 
# 405 2421 2537   48  734 
# 405 points do not fall within at least one image @ 200m (to be expected)

point_to_img_20m <- data.frame(point_id=1:6145,st_coordinates(sampled_points))
# for each image, what polygon fall within them
for(i in 1:length(allrasters)){
  a <- terra::is.related(vect_20m_buffer,allrasters[[i]],"intersects")
  a <- list(a)
  names(a)<- paste0("img_",i)
  point_to_img_20m <- bind_cols(point_to_img_20m,a)
}

point_to_img_20m %>% select(-point_id,-X,-Y) %>% rowSums() %>% table()

# 0    1    2    4 
# 588 5163  388    6 
# 588 points do not fall within at least one image @ 20m (to be expected)

# clean up env objects
rm(sample_20m_buffer,sample_200m_buffer,a,sampled_points,i,imagelist)


################################################################################
# 5. Crop the image corresponding to buffers for each point and save
################################################################################
# For each point, read in the image(s) that the buffer(s) falls within
# do 20m first

create_road_patch <- function(road_point_id=1, # id (row number) of centroid in point file
                              point_to_img_file=point_to_img_20m, # file connecting centroids to rasters
                              buffer_size=20, # size of squares that have already been made
                              image_resolution=.25,
                              buffer_file=vect_20m_buffer,
                              save_location="data/processed/",
                              allrasters=allrasters # list of all raster files
                              ){
  
  temp_row <- point_to_img_file %>% filter(point_id %in% road_point_id) %>% select(-point_id,-X,-Y)
  if(temp_row  %>% rowSums() <1 ){
    # Skip if point doesn't overlap an image
    return(paste0("Road segment for image ", road_point_id," not within saved aerial images."))
  }
  
  temp_row <- temp_row %>% select(where(~ . > 0))
  img_list <- as.numeric(gsub("img_","",names(temp_row)))
  
  # read in all of the images necessary for the given point
  merge_list = list()
  temp_buffer <- buffer_file[road_point_id]
  for(d in 1:length(img_list)){
    temp_img <- allrasters[[img_list[[d]]]]
    temp_img <- crop(temp_img, temp_buffer)
    merge_list <- append(merge_list, list(temp_img))
  }
  
  # if only one image things are super easy, just crop the image to the pointid of the buffer
  if(length(img_list)==1){
    final_temp_img <- merge_list[[1]]
  }
  
  # if multiple images, merge all of them together, and crop the larger image to the pointid of the buffer  
  if(length(img_list)>=1){
    rsrc <- sprc(merge_list)
    final_temp_img <- merge(rsrc)
  }
  
  dimension_check = buffer_size*(1/image_resolution)*2
  
  # add a check to ensure that the patch is the correct size
  if(dim(final_temp_img)[1]!=dimension_check | dim(final_temp_img)[2]!=dimension_check){
    return(paste0("Road segment buffer for image ", road_point_id," only partially overlaps saved images."))
  }
  
  # Save images
  invisible(writeRaster(final_temp_img, paste0(save_location,"cam-2017-",buffer_size,"m/cambdrige-",buffer_size,"m-point-",road_point_id,".tif"), overwrite=FALSE))
  
  return(paste0("Image patch ",road_point_id, " saved successfully to ", save_location,"cambdrige-20m-point-",road_point_id,".tif"))
  
  
}

# Loop over each centroid and save image if possible

# 20m sq buffer
start_time <- Sys.time()
for(i in 1:6145){ 
  temp_message <- create_road_patch(
    road_point_id=i, # id (row number) of centroid in point file
    point_to_img_file=point_to_img_20m, # file connecting centroids to rasters
    buffer_size=20, # size of squares that have already been made
    image_resolution=.25,
    buffer_file=vect_20m_buffer,
    save_location="data/processed/",
    allrasters=allrasters # list of all raster files
  )
  
  print(temp_message)
}
end_time <- Sys.time()
loop_time_20m <- end_time - start_time


# 200m sq buffer
start_time <- Sys.time()
for(i in 1:6145){ 
  temp_message <- create_road_patch(
    road_point_id=i, # id (row number) of centroid in point file
    point_to_img_file=point_to_img_200m, # file connecting centroids to rasters
    buffer_size=200, # size of squares that have already been made
    image_resolution=.25,
    buffer_file=vect_200m_buffer,
    save_location="data/processed/",
    allrasters=allrasters # list of all raster files
  )
  
  print(temp_message)
}
end_time <- Sys.time()
loop_time_200m <- end_time - start_time


################################################################################
# Random Workspace/Scrap Code
################################################################################

# whats the total extent of my image files? might want to crop my road file based on this earlier...
# get a list of all the paths for one year
# imagelist <- list.files("data/raw/cambridge-rgb/getmapping-rgb-25cm-2016_4700173/tl/") %>% Filter(function(x) {str_detect(x,"jpg")}, .)
# imagelist <- unlist(lapply(imagelist, function(i){paste0(
#   "C:/Users/jfrancis/OneDrive - The Alan Turing Institute/Documents - AI for Government/6-Technical Projects/satellite-image-demonstrator/sat-img-demonstrator/data/raw/cambridge-rgb/getmapping-rgb-25cm-2016_4700173/tl/",i)}))
# 
# img_extents <- lapply(imagelist, raster::extent)
# do.call(raster::merge, shape_extents)
# 
# allrasters <- lapply(imagelist, terra::rast)
# all_extents <- lapply(allrasters, ext)
# 
# #total <- terra::merge(all_extents[[1]],all_extents[[2]])
# 
# # drop all of the points that i dont have images
# vrtfile <- paste0(tempfile(), ".vrt")
# v <- vrt(imagelist, vrtfile)
# head(readLines(vrtfile))
#v
#extent      : 541000, 551000, 254000, 264000  (xmin, xmax, ymin, ymax)


# ### 24/10/2022 ###
# # turng these into functions and adding a step to validate the image size
# 
# 
# start_time <- Sys.time()
# for(i in 1:6145){ 
#   print(i)
#   temp_row <- point_to_img_20m %>% filter(point_id %in% i) %>% select(-point_id,-X,-Y)
#   if(temp_row  %>% rowSums() <1 ) next # Skip if point doesn't overlap an image
#   temp_row <- temp_row %>% select(where(~ . > 0))
#   img_list <- as.numeric(gsub("img_","",names(temp_row)))
#   
#   # read in all of the images necessary for the given point
#   merge_list = list()
#   for(d in 1:length(img_list)){
#     temp_img <- allrasters[[img_list[[d]]]]
# 
#     merge_list <- append(merge_list, list(temp_img))
#   }
#   
#   # if only one image things are super easy, just crop the image to the pointid of the buffer
#   if(length(img_list)==1){
#     temp_buffer <- vect_20m_buffer[i]
#     final_temp_img <- crop(merge_list[[1]], temp_buffer)
#     
#   }
#   
#   # if multiple images, merge all of them together, and crop the larger image to the pointid of the buffer  
#   if(length(img_list)>=1){
#     rsrc <- sprc(merge_list)
#     m <- merge(rsrc)
#     temp_buffer <- vect_20m_buffer[i]
#     
#     final_temp_img <- crop(m, temp_buffer)
#   }
#   
#   # Save images
#   writeRaster(final_temp_img, paste0("data/processed/cam-2017-20m/","cambdrige-20m-point-",i,".tif"), overwrite=FALSE)
#   
# }
# end_time <- Sys.time()
# loop_time_20m <- end_time - start_time
# 
# # next do 200m
# start_time <- Sys.time()
# for(i in 2299:6145){ 
#   print(i)
#   temp_row <- point_to_img_200m %>% filter(point_id %in% i) %>% select(-point_id,-X,-Y)
#   if(temp_row  %>% rowSums() <1 ) next # Skip if point doesn't overlap an image
#   temp_row <- temp_row %>% select(where(~ . > 0))
#   img_list <- as.numeric(gsub("img_","",names(temp_row)))
#   
#   ### 22/10/2022 Switching things up to crop images before merging, hoping this is faster
#   # read in all of the images necessary for the given point
#   merge_list = list()
#   temp_buffer <- vect_200m_buffer[i]
#   for(d in 1:length(img_list)){
#     temp_img <- allrasters[[img_list[[d]]]]
#     temp_img <- crop(temp_img, temp_buffer)
#     merge_list <- append(merge_list, list(temp_img))
#   }
#   
#   # if only one image things are super easy, just crop the image to the pointid of the buffer
#   if(length(img_list)==1){
#     final_temp_img <- merge_list[[1]]
#   }
#   
#   # if multiple images, merge all of them together, and crop the larger image to the pointid of the buffer  
#   if(length(img_list)>=1){
#     rsrc <- sprc(merge_list)
#     final_temp_img <- merge(rsrc)
#     # temp_buffer <- vect_200m_buffer[i]
#     # 
#     # final_temp_img <- crop(m, temp_buffer)
#   }
#   
#   # Save images
#   writeRaster(final_temp_img, paste0("data/processed/cam-2017-200m/","cambdrige-200m-point-",i,".tif"), overwrite=FALSE)
#   
# }
# end_time <- Sys.time()
# loop_time_200m <- end_time - start_time
# 
# # Time difference of 1.178173 hours
