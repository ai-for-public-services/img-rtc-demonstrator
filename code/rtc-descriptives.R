# Purpose: Ensure RTCs are usable for analyses, run some descriptive analyses
# Author: John Francis
# Date Created: Oct. 25, 2022

# Load Dependencies
library(tidyverse)
library(terra)
library(sf)
library(sp)
library(ggplot2)

################################################################################
# 1. Load in Data
################################################################################
# DATA SOURCE
# https://data.cambridgeshireinsight.org.uk/dataset/cambridgeshire-road-traffic-collision-data # new setup
# https://data.cambridgeshireinsight.org.uk/dataset/road-traffic-collisions-location # older data
# The collision data is sourced from the police and includes only collisions that:
#   * involved a vehicle
# * occurred on public highway (e.g. not private car parks, etc.)
# * resulted in a casualty to at least one of the involved parties
# DATA IS NOT COLLECTED FOR DAMAGE-ONLY RTCs... handled by insurance companies in UK


#https://www.cambs.police.uk/advice/advice-and-information/rs/road-safety/collisions/
# You don't need to report a collision to the police if you've exchanged details,
# nobody was injured and there are no allegations of driving offences.
# 
# You must report the collision to the police if you were unable to exchange details 
# at the scene, if anyone was injured, or if you suspect that the other person may have 
# committed a driving offence. 

# point location files
rtc_2016 <- readxl::read_xlsx("data/raw/cambridgeshire-RTCs/RTC Location 2016.xlsx")
rtc_2017 <- readxl::read_xlsx("data/raw/cambridgeshire-RTCs/RTC Location 2017_0.xlsx")

# this claims to be all the data from 2017-2022
rtc_all <- st_read("data/raw/cambridgeshire-RTCs/Cambridgeshire RTCs 2017-August 2022.shp")

# extent of the images i downloaded
total_extent = c(xmin = 541000, xmax = 551000, ymax = 254000, ymin = 264000)

# Note: Image data is available for 2016,2017,2020

################################################################################
# 2. Clean as necessary
################################################################################
# turn dfs into sf objects
rtc_2016 <- st_as_sf(rtc_2016,coords = c("Easting","Northing"),crs=st_crs(rtc_all))
rtc_2017 <- st_as_sf(rtc_2017,coords = c("Easting","Northing"),crs=st_crs(rtc_all))

# crop to image area, how many data points are we really working with?
rtc_all <- rtc_all %>% st_filter(st_as_sfc(st_bbox(total_extent,crs = st_crs(rtc_all))))
rtc_2017 <- rtc_2017 %>% st_filter(st_as_sfc(st_bbox(total_extent,crs = st_crs(rtc_all))))
rtc_2016 <- rtc_2016 %>% st_filter(st_as_sfc(st_bbox(total_extent,crs = st_crs(rtc_all))))

# do the files contain the same information?
rtc_all %>% filter(Date>=20170000 & Date<20180000) %>% count() # 397
rtc_2017 %>% count() # 383
# no there appears to be some difference in number of rows, although cols seem similar

# are points unique, or just LSOA centroids or something?
unique(rtc_2016$geometry)
unique(rtc_2017$geometry)
unique(rtc_all$geometry)
# <10 repeated geometries in each file, pretty confident these are the actual points
# https://www.cambs.police.uk/ro/report/rti/rti-beta-2.1/report-a-road-traffic-incident/
# The reporting tool dos allow people/police to pin the accident location on the map
# so these should actually be fairly close to accurate

# visualize points
rtc_all %>% st_geometry() %>% plot()
rtc_2016 %>% st_geometry() %>% plot()
rtc_2017 %>% st_geometry() %>% plot()


# more closely examine the two potential data files
rtc_all_2017 <- rtc_all %>% filter(Date>=20170000 & Date<20180000)


# Are all the police refs from the smaller file in the bigger one?
table(rtc_2017$Police_ref %in% rtc_all_2017$Police_ref) # all but one

# Given this, going to consider the big file as the 'final official #s'
# No data for 2016 in the official file, so going to keep the 2016 file (from gov uk)

# extract the 2020 datapoints
rtc_all_2020 <- rtc_all %>% filter(Date>=20200000 & Date<20210000)
################################################################################
# 3. Create Some Descriptives
################################################################################
# start with the 2016 data
# Severity - slight/serious
# Road_Class - good? not sure what the codes mean
# Junction Detail - too many categories, need to look a research for how to use this
# Light - good
# Weather - not much variation, could just code rain                 
# Surface -dry/wet/ice - collapse ice with wet
# Speed_limit - good, maybe code 30 below/above
# Cycle - many, good variable
# Ped - not too many, but good variable
# Number_Vehicles - straightforward, may 1,2,3+

rtc_2016 <- rtc_2016 %>% mutate(
  time_of_day = case_when(
    Time<500~"Night",
    Time>=500 & Time<1000 ~"Morning",
    Time>=1000 & Time<1500 ~"Middle of Day",
    Time>=1500 & Time<2000 ~"Afternoon/Evening",
    Time>=2000 ~"Night"),
  surface=if_else(Surface=="Dry","dry","wet"),
  cycle=if_else(Cycle=="Y",1,0),
  pedestrian=if_else(Ped=="Y",1,0),
  year=2016) %>% select(
    time_of_day,surface,cycle,pedestrian,Severity,Road_Class,Light,Speed_limit,
    Number_Vehicles,year) %>% janitor::clean_names()

# do the 2017/2020 data in a similar manner
rtc_all_2017 <- rtc_all_2017 %>% mutate(
  surface=if_else(Road_cond=="Dry","dry","wet"),
  light=if_else(Visibility=="1. Daylight","Day","Dark"),
  pedestrian=if_else(Pedestrian==0,0,1),
  cycle=if_else(Cycles==0,0,1),
  # time?
  Time=lubridate::hm(Time),
  time_of_day=case_when(
    Time<500~"Night",
    Time>=500 & Time<1000 ~"Morning",
    Time>=1000 & Time<1500 ~"Middle of Day",
    Time>=1500 & Time<2000 ~"Afternoon/Evening",
    Time>=2000 ~"Night"),
  year=2017,
  road_class=case_when(
    Roadclass1=="1. Motorway "~"M",
    Roadclass1=="3. A"~"A",
    Roadclass1=="4. B"~"B",
    Roadclass1=="5. C"~"C",
    Roadclass1=="6. Unclassified"~"U"
  )) %>% select(
      time_of_day,surface,cycle,pedestrian,Severity,road_class,light,
      Speed_limit=Speed_Lim,Number_Vehicles=Vehicles,year) %>% janitor::clean_names()

rtc_all_2020 <- rtc_all_2020 %>% mutate(
  surface=if_else(Road_cond=="Dry","dry","wet"),
  light=if_else(Visibility=="1. Daylight","Day","Dark"),
  pedestrian=if_else(Pedestrian==0,0,1),
  cycle=if_else(Cycles==0,0,1),
  # time?
  Time=lubridate::hm(Time),
  time_of_day=case_when(
    Time<500~"Night",
    Time>=500 & Time<1000 ~"Morning",
    Time>=1000 & Time<1500 ~"Middle of Day",
    Time>=1500 & Time<2000 ~"Afternoon/Evening",
    Time>=2000 ~"Night"),
  year=2020,
  road_class=case_when(
    Roadclass1=="1. Motorway "~"M",
    Roadclass1=="3. A"~"A",
    Roadclass1=="4. B"~"B",
    Roadclass1=="5. C"~"C",
    Roadclass1=="6. Unclassified"~"U"
  )) %>% select(
      time_of_day,surface,cycle,pedestrian,Severity,road_class,light,
      Speed_limit=Speed_Lim,Number_Vehicles=Vehicles,year) %>% janitor::clean_names()

################################################################################
# 4. Generate Some Descriptives
################################################################################
# All vars are categorical, can look over time, otherwise everything's pretty straightforward
# "time_of_day","surface","cycle","pedestrian","severity","road_class","light",
# "speed_limit","number_vehicles"

rtc_2016 %>% ggplot(aes(road_class)) + 
  geom_bar(stat='count', width=.5)  +
  geom_text(stat='count', aes(label=..count..), vjust=-1) 


# Chi square test for probability of differences
chisq.test(table(rtc_2016$time_of_day))


################################################################################
# 5. Getting RTC data for all of the UK
################################################################################
# following advice from the UA slack channel there is a package which is custom 
# made for using RTC data https://github.com/ropensci/stats19/
# USE THIS FOR THE NON CAMBRIDGE DATA

crashes <- stats19::get_stats19(year = 2017, type = "accident")
crashes <- crashes %>% dplyr::filter(is.na(location_easting_osgr)==FALSE)

total_extent=c(xmin = 541000, xmax = 551000, ymax = 254000, ymin = 264000)
rtc_2017 <- st_as_sf(crashes,coords = c("location_easting_osgr","location_northing_osgr"),crs=st_crs(rtc_all))


rtc_all <- rtc_all %>% st_filter(st_as_sfc(st_bbox(total_extent,crs = st_crs(rtc_all))))
rtc_all_2017 <- rtc_all %>% filter(Date>=20170000 & Date<20180000)
rtc_2017 <- rtc_2017 %>% st_filter(st_as_sfc(st_bbox(total_extent,crs = st_crs(rtc_all))))

# not as useful  i dont think 
#vehicles <- stats19::get_stats19(year = 2017, type = "vehicle")


# SAVE FINAL RTC FILES
cam_rtc<-bind_rows(rtc_2016,rtc_all_2017,rtc_all_2020)
cam_rtc <- cam_rtc %>%
  mutate(lon = st_coordinates(.)[,1],
                lat = st_coordinates(.)[,2])

cam_rtc <- cam_rtc %>% st_drop_geometry()
write.csv(cam_rtc,"data/processed/rtc/cam-rtc.csv",row.names = F)

