#Script to be run each day to update the Birdle web app

library(shiny)
library(shinyWidgets)
library(shinyBS)
library(shinyjs)

ShinyAppDataDirectory <- "D:\\Projects\\Birdle\\Birdle\\data"
ShinyWWWDirectory     <- "D:\\Projects\\Birdle\\Birdle\\www"
ProjectSoundFiles     <-   "D:\\Projects\\Birdle\\SoundFiles"

NoOfSounds <- 5
BirdNames  <- c("Chaffinch","Miromiro","Kakaruai","Thrush","Blackbird",
                "Pipipi","Tauhou","Riroriro","Korimako","Kakariki",
                "Tititipounamu")
BirdToolTips <- c("Chaffinch<br/>Pahirini","Miromiro<br/>Tomtit","Kakaruai<br/>Robin","Thrush<br/>Manu-kai-hua-rakau","Blackbird<br/>Manu pango",
                  "Pipipi<br/>Brown creeper","Tauhou<br/>Silvereye","Riroriro<br/>Grey warbler","Korimako<br/>Bellbird","Kakariki<br/>Parakeet",
                  "Tititipounamu<br/>Rifleman")
NoOfBirds  <- length(BirdNames)
SoundBirds <- sample(seq_len(NoOfBirds),NoOfSounds,replace=FALSE)

SoundButtons <- lapply(seq_len(NoOfSounds), function(SoundNo) {
  SoundID <- paste0("Sound",SoundNo)
  actionButton(SoundID,label=NULL,icon = icon("play"), width = '15%')
})

#Prepare the bird buttons
BirdButtons <- lapply(seq_len(NoOfBirds), function(BirdNo) {
  BirdID <- paste0("Bird",BirdNo)
  BirdImageFile <- paste0(BirdNames[BirdNo],".png")
  ToolTip <- BirdToolTips[BirdNo]
  
  #Specify the custom style javascript needed when creating the button, complete with image file
  StyleDetails <- paste0("width: 95px; height: 95px; background: url('",BirdImageFile,"'); background-size: cover; background-position: center;")
  
  #Create the button
  Button <- actionButton(BirdID,label=NULL,style=StyleDetails)
  
  #Add tool tip
  ButtonWithTooltip <- tipify(Button,title=ToolTip)
  return(ButtonWithTooltip)
})

#Prepare the "Sound" files
#There are five of them named Sound1.mp3, Sound2.mp3...Sound5.mp3
#They need to have the correct sound file for the bird that they have been allocated to
for (SoundIndex in seq_len(NoOfSounds)) {
  RelatedBirdIndex <- SoundBirds[SoundIndex]
  BirdName <- BirdNames[RelatedBirdIndex]
  BirdSoundFileName <- paste0(BirdName,".mp3")
  ThisSoundsFileName <- paste0("Sound",SoundIndex,".mp3")
  file.copy(file.path(ProjectSoundFiles,BirdSoundFileName),file.path(ShinyWWWDirectory,ThisSoundsFileName),overwrite = TRUE)
  #Copy/update the sound files on the shiny server
  curl::curl_upload(file=file.path(ShinyWWWDirectory,paste0("Sound",SoundIndex,".mp3")),
                    url=paste0("sftp://157.245.105.6/opt/shiny-server/samples/sample-apps/Birdle/www/Sound",SoundIndex,".mp3"), verbose=TRUE,reuse=TRUE,
                    userpwd = paste0("tim:",keyring::key_get("Rainfall.NZ Shiny Server","tim")),
                    ssl_verifypeer = 0,
                    ssl_verifyhost = FALSE
  )
}



#Put all of these objects in a list and save to an RData file
BirdleSetupData <- list("NoOfSounds"=NoOfSounds, "BirdNames" = BirdNames,"NoOfBirds"=NoOfBirds,"SoundBirds"=SoundBirds,"SoundButtons"=SoundButtons,"BirdButtons"=BirdButtons)
saveRDS(BirdleSetupData, file=file.path(ShinyAppDataDirectory,"BirdleInitialisationData.rds"))

#And copy to the Rainfall.NZ's Digital Ocean shiny-server, using curl. Note that I must have write 
#permissions on the file (and possibly its directory) if it is already in the Shiny Server. 
curl::curl_upload(file=file.path(ShinyAppDataDirectory,"BirdleInitialisationData.rds"),
                  url="sftp://157.245.105.6/opt/shiny-server/samples/sample-apps/Birdle/data/BirdleInitialisationData.rds", verbose=TRUE,reuse=TRUE,
                  userpwd = paste0("tim:",keyring::key_get("Rainfall.NZ Shiny Server","tim")),
                  ssl_verifypeer = 0,
                  ssl_verifyhost = FALSE
)
