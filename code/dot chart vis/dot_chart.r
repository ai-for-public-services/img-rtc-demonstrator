library(readxl)
library(ggplot2)
library(dplyr)
library(tidyr)

setwd("C:/Users/simon/Desktop/Turing/img demonstrator")

df<- read_excel('rtc_dot_chart.xlsx', sheet='data')

df <- df[df$Mode %in% c('Total', 'Cycle', 'Pedestrian', 'Motorcycle'),]

ggplot(df, aes(color=Cluster, shape=Cluster, y=Y, x=Mode)) +
  geom_point(size = 5, alpha=0.5) + 
  geom_point(data=df %>% filter(Circled == 1),
             pch=21,
             size=10,
             colour='black') +
  facet_wrap(~City, scales='free', ncol=2) +
  theme_minimal() + xlab('') + ylab('Average Z-Score of RTCs') +
  scale_color_brewer(guide=F, palette='Dark2') + scale_shape_discrete(guide=F) 

ggsave('dot chart.png')
  