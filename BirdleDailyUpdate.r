#Script to be run each day to update the Birdle web app

library(shiny)
library(shinyWidgets)
library(shinyBS)
library(shinyjs)

ShinyAppDataDirectory <- "D:\\Projects\\Birdle\\Birdle\\data"

NoOfSounds <- 5
BirdNames  <- c("Chaffinch","Tomtit","Robin","Thrush","Blackbird")
NoOfBirds  <- length(BirdNames)
SoundBirds <- sample(seq_len(NoOfBirds),NoOfSounds,replace=FALSE)

SoundButtons <- lapply(seq_len(NoOfSounds), function(SoundNo) {
  SoundID <- paste0("Sound",SoundNo)
  actionButton(SoundID,label=NULL,icon = icon("play"))
})

#Prepare the bird buttons
BirdButtons <- lapply(seq_len(NoOfBirds), function(BirdNo) {
  BirdID <- paste0("Bird",BirdNo)
  BirdImageFile <- paste0(BirdNames[BirdNo],".png")
  ToolTip <- BirdNames[BirdNo]
  
  #Specify the custom style javascript needed when creating the button, complete with image file
  StyleDetails <- paste0("width: 50px; height: 50px; background: url('",BirdImageFile,"'); background-size: cover; background-position: center;")
  
  #Create the button
  Button <- actionButton(BirdID,label=NULL,style=StyleDetails)
  
  #Add tool tip
  ButtonWithTooltip <- tipify(Button,title=ToolTip)
  return(ButtonWithTooltip)
})

#Put all of these objects in a list and save to an RData file
BirdleSetupData <- list("NoOfSounds"=NoOfSounds, "BirdNames" = BirdNames,"NoOfBirds"=NoOfBirds,"SoundBirds"=SoundBirds,"SoundButtons"=SoundButtons,"BirdButtons"=BirdButtons)
saveRDS(BirdleSetupData, file=file.path(ShinyAppDataDirectory,"BirdleInitialisationData.rds"))

#And copy to the Rainfall.NZ's Digital Ocean shiny-server, using curl. Note that I must have write 
#permissions on the file (and possibly its directory) if it is already in the Shiny Server. 
curl::curl_upload(file=file.path(ShinyAppDataDirectory,"BirdleInitialisationData.rds"),
                  url="sftp://157.245.105.6/opt/shiny-server/samples/sample-apps/Birdle/Data/plotWithForecast.rds", verbose=TRUE,reuse=TRUE,
                  userpwd = paste0("tim:",keyring::key_get("Rainfall.NZ Shiny Server","tim")),
                  ssl_verifypeer = 0,
                  ssl_verifyhost = FALSE
)