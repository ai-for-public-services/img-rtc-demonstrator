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

# osm_roads <- read_sf("data/raw/cambridge_osm_roads_full.shp")
# osm_roads <- st_transform(osm_roads, crs=27700)
# osm_roads   <- st_crop(osm_roads ,st_bbox(c(xmin = 541000, xmax = 551000, ymax = 254000, ymin = 264000)))
# osm_roads <- osm_roads %>% filter(!fclass %in% c(
#   "footway","bridleway","cycleway","steps")) # remove paths unsuitable for cars https://download.geofabrik.de/osm-data-in-gis-formats-free.pdf
# 
# osm_roads <- osm_roads %>% filter(str_detect(fclass,"track")==FALSE)
# osm_roads <- st_cast(st_cast(osm_roads, "MULTILINESTRING"),"LINESTRING") # have to double cast to avoid losing information
# sampled_points_osm <- st_line_sample(osm_roads , density = 1/50)
# sampled_points_osm <- st_cast(sampled_points_osm, "POINT")
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
  
  # transform to BNG
  roads <- st_transform(roads, crs=27700)
  # will experiment with the OSM road shapefile as well as the OS roads file
  
  # crop roads to the extent of my images
  roads <- st_crop(roads,st_bbox(total_extent))
  
  # for OSM remove paths unsuitable for cars https://download.geofabrik.de/osm-data-in-gis-formats-free.pdf
  roads <- roads %>% filter(!fclass %in% c(
    "footway","bridleway","cycleway","steps")) 

  # getting rid of these tiny roads as well - appear to be private anyways
  roads <- roads %>% filter(str_detect(fclass,"track")==FALSE)
  
  # ensure road file is in linestring
  roads <- st_cast(st_cast(roads, "MULTILINESTRING"),"LINESTRING") # have to double cast to avoid losing information
  #osm_roads <- st_cast(osm_roads,"LINESTRING")
  
  sampled_points <- st_line_sample(roads, density = point_density) # one point every 25 m
  sampled_points <- st_cast(sampled_points, "POINT") # cast to point
  # 5,935 roads, one point every 10m gives 62,425 points
  # 5,935 roads, one point every 25m gives 24,961 points
  # 5,935 roads, one point every 50m gives 12,459 points
  # 5,935 roads, one point every 100m gives 6,145 points
  return(sampled_points)
  
}


sampled_points <- generate_sample_ids(file_name="data/raw/cambridge_osm_roads_full.shp",
                                      point_density=1/50,
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
sample_25m_buffer <- st_buffer(sampled_points, 25, nQuadSegs = 1,endCapStyle = "SQUARE")

sample_100m_buffer <- st_buffer(sampled_points, 100, nQuadSegs = 1,endCapStyle = "SQUARE")

################################################################################
# 4. identify which image(s) are included within each buffer
################################################################################
# make into a spatvector to use terra
vect_100m_buffer<- vect(sample_100m_buffer)
vect_25m_buffer<- vect(sample_25m_buffer)

#for each image see which of the polygon intersect the img
imagelist <- list.files("data/raw/cambridge-rgb/getmapping-rgb-25cm-2016_4700173/tl/") %>% Filter(function(x) {str_detect(x,"jpg")}, .)
imagelist <- unlist(lapply(imagelist, function(i){paste0(
  "data/raw/cambridge-rgb/getmapping-rgb-25cm-2016_4700173/tl/",i)}))
allrasters <- lapply(imagelist, terra::rast)

point_to_img_100m <- data.frame(point_id=1:length(vect_100m_buffer),st_coordinates(sampled_points))
# for each image, what polygon fall within them
for(i in 1:length(allrasters)){
  a <- terra::is.related(vect_100m_buffer,allrasters[[i]],"intersects")
  a <- list(a)
  names(a)<- paste0("img_",i)
  point_to_img_100m <- bind_cols(point_to_img_100m,a)
}

point_to_img_100m %>% select(-point_id,-X,-Y) %>% rowSums() %>% table()

# 0    1    2    3    4 
# 405 2421 2537   48  734 
# 405 points do not fall within at least one image @ 200m (to be expected)

point_to_img_25m <- data.frame(point_id=1:length(vect_25m_buffer),st_coordinates(sampled_points))
# for each image, what polygon fall within them
for(i in 1:length(allrasters)){
  a <- terra::is.related(vect_25m_buffer,allrasters[[i]],"intersects")
  a <- list(a)
  names(a)<- paste0("img_",i)
  point_to_img_25m <- bind_cols(point_to_img_25m,a)
}

point_to_img_25m %>% select(-point_id,-X,-Y) %>% rowSums() %>% table()

# 0    1    2    4 
# 588 5163  388    6 
# 588 points do not fall within at least one image @ 20m (to be expected)

# clean up env objects
rm(sample_25m_buffer,sample_100m_buffer,a,sampled_points,i,imagelist)


################################################################################
# 5. Crop the image corresponding to buffers for each point and save
################################################################################
# For each point, read in the image(s) that the buffer(s) falls within
# do 20m first

create_road_patch <- function(road_point_id=1, # id (row number) of centroid in point file
                              point_to_img_file=point_to_img_file, # file connecting centroids to rasters
                              buffer_size=buffer_size, # size of squares that have already been made
                              image_resolution=.25,
                              buffer_file=buffer_file,
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
  
  return(paste0("Image patch ",road_point_id, " saved successfully to ", save_location,"cambdrige-",buffer_size,"m-point-",road_point_id,".tif"))
  
  
}

# Loop over each centroid and save image if possible

### 25m sq buffer ###
# At 20m buffer this takes 43.20307 mins to run
# At 25m buffer this takes mins to run
start_time <- Sys.time()
for(i in 1:length(vect_25m_buffer)){ 
  temp_message <- create_road_patch(
    road_point_id=i, # id (row number) of centroid in point file
    point_to_img_file=point_to_img_25m, # file connecting centroids to rasters
    buffer_size=25, # size of squares that have already been made
    image_resolution=.25,
    buffer_file=vect_25m_buffer,
    save_location="data/processed/",
    allrasters=allrasters # list of all raster files
  )
  
  print(temp_message)
}
end_time <- Sys.time()
loop_time_25m <- end_time - start_time




### 100m sq buffer ###
# At 100m this takes  hours to run
start_time <- Sys.time()
for(i in 1:length(vect_100m_buffer)){ 
  temp_message <- create_road_patch(
    road_point_id=i, # id (row number) of centroid in point file
    point_to_img_file=point_to_img_100m, # file connecting centroids to rasters
    buffer_size=100, # size of squares that have already been made
    image_resolution=.25,
    buffer_file=vect_100m_buffer,
    save_location="data/processed/",
    allrasters=allrasters # list of all raster files
  )
  
  print(temp_message)
}
end_time <- Sys.time()
loop_time_100m <- end_time - start_time

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

# ### 200m sq buffer ###
# # At 200m this takes 2.307753 hours to run
# start_time <- Sys.time()
# for(i in 1:6145){ 
#   temp_message <- create_road_patch(
#     road_point_id=i, # id (row number) of centroid in point file
#     point_to_img_file=point_to_img_200m, # file connecting centroids to rasters
#     buffer_size=200, # size of squares that have already been made
#     image_resolution=.25,
#     buffer_file=vect_200m_buffer,
#     save_location="data/processed/",
#     allrasters=allrasters # list of all raster files
#   )
#   
#   print(temp_message)
# }
# end_time <- Sys.time()
# loop_time_200m <- end_time - start_time
################################################################################
# 30/11/2022 Consider aggregating the cells of the 100m images to allow for training locally

# for each image see which of the polygon intersect the img

imagelist1 <- list.files("data/processed/cam-2020-100m/") %>% Filter(function(x) {str_detect(x,"tif")}, .) %>% Filter(function(x) {!str_detect(x,"xml")}, .)
imagelist1 <- unlist(lapply(imagelist1, function(i){paste0(
  "data/processed/cam-2020-100m/",i)}))
imagelist2 <- list.files("data/processed/cam-2016-100m/") %>% Filter(function(x) {str_detect(x,"tif")}, .) %>% Filter(function(x) {!str_detect(x,"xml")}, .)
imagelist2 <- unlist(lapply(imagelist2, function(i){paste0(
  "data/processed/cam-2016-100m/",i)}))
imagelist3 <- list.files("data/processed/glo-2018-100m/") %>% Filter(function(x) {str_detect(x,"tif")}, .) %>% Filter(function(x) {!str_detect(x,"xml")}, .)
imagelist3 <- unlist(lapply(imagelist3, function(i){paste0(
  "data/processed/glo-2018-100m/",i)}))
imagelist4 <- list.files("data/processed/glo-2021-100m/") %>% Filter(function(x) {str_detect(x,"tif")}, .) %>% Filter(function(x) {!str_detect(x,"xml")}, .)
imagelist4 <- unlist(lapply(imagelist4, function(i){paste0(
  "data/processed/glo-2021-100m/",i)}))
imagelist5 <- list.files("data/processed/oxf-2019-100m/") %>% Filter(function(x) {str_detect(x,"tif")}, .) %>% Filter(function(x) {!str_detect(x,"xml")}, .)
imagelist5 <- unlist(lapply(imagelist5, function(i){paste0(
  "data/processed/oxf-2019-100m/",i)}))
imagelist6 <- list.files("data/processed/oxf-2016-100m//") %>% Filter(function(x) {str_detect(x,"tif")}, .) %>% Filter(function(x) {!str_detect(x,"xml")}, .)
imagelist6 <- unlist(lapply(imagelist6, function(i){paste0(
  "data/processed/oxf-2016-100m/",i)}))
imagelist <- c(imagelist1,imagelist2,imagelist3,imagelist4,imagelist5,imagelist6)
rm(imagelist1,imagelist2,imagelist3,imagelist4,imagelist5,imagelist6)


a <- rast(imagelist[1]) # 800x800x3 at .25m
a2 <- terra::aggregate(a,4,fun="mean")
a3 <- terra::aggregate(a,2)
a4 <- terra::aggregate(a3,2)

a5 <- resample(a,a2,method="bilinear")
plotRGB(a2)
plotRGB(a)

start_time <- Sys.time()
for(i in 75295:length(imagelist)){ 
  print(i)
  a <- rast(imagelist[i]) # read in image
  a2 <- terra::aggregate(a,4,fun="mean") # aggregate to a usable resolution
  a3 <- resample(a,a2,method="bilinear") # but don't use aggregation, instead resample to the new resolution
  # save it to new location
  filename <- gsub("100m/","100m-agg/",imagelist[1])
  invisible(writeRaster(a3, filename, overwrite=TRUE))
}
end_time <- Sys.time()
loop_time_agg_rasters <- end_time - start_time

################################################################################
# 08/12/22 Look Into the overlapping points
#  There appears to be something going on with intersecting line segments and 
# parallel road such that points can be generated in basically the same location
# This needs to be fixed for the clustering, perhaps merge close points in some
# formulaic way that makes sense?

sampled_points <- generate_sample_ids(file_name="data/raw/oxford_osm_roads_full.shp",
                                      point_density=1/50,
                                      total_extent=c(xmin = 447000, xmax = 457000, ymax = 212000 , ymin = 202000))

#cambridge: c(xmin = 541000, xmax = 551000, ymax = 254000, ymin = 264000)
#gloucester: c(xmin = 379000, xmax = 389000, ymax = 222000, ymin = 212000)
#oxford: c(xmin = 447000, xmax = 457000, ymax = 212000 , ymin = 202000)

# get the distance from each point to every other point
test <- sampled_points %>% st_distance()

# get a list of points within 40m of each point
indices <- which(test < units::set_units(51, "m"), arr.ind = TRUE) # 50m felt too restrictive given the size of some of these small town streets, dont want to eliminate the next block over

# create df of row id problematic combinations
df.dist <- as.data.frame(indices)

# add in the distance
df.dist$dist <- as.numeric(test[indices])

# ignore the cross diagonal
df.dist <- df.dist %>% filter(!row==col) # 1 is 0m from 1
df.dist <- df.dist[order(df.dist$row),] # put in order of row id

# ignore the combinations pairs (dont need 1,2 and 2,1)
df.dist <- df.dist[!duplicated(t(apply(df.dist[c("row", "col")], 1, sort))), ]

# get a list of all the ids that show up in the col - i think this makes sense intuitively
# double check by rerunnin on result and it gives a df with 0 rows - good to go
problem_ids <- unique(df.dist$col)

sampled_points <- st_as_sf(sampled_points)
sampled_points$row_id <-  seq.int(nrow(sampled_points))

sampled_points <- sampled_points %>% filter(!row_id %in% problem_ids)

#sampled_points %>% st_geometry() %>% plot()

# run above lines separately for each city and then combine to be able to check in python
cambridge_points <- sampled_points %>% st_drop_geometry() %>% mutate(location="cam")
gloucester_points <- sampled_points %>% st_drop_geometry() %>% mutate(location="glo")
oxford_points <- sampled_points %>% st_drop_geometry() %>% mutate(location="oxf")

all_ref_ids <- bind_rows(cambridge_points,gloucester_points, oxford_points)

write.csv(all_ref_ids,"data/processed/image-features/final_points_200123.csv",row.names = FALSE)
