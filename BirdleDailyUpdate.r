#Script to be run each day to update the Birdle web app.
#
#The birds of the day are selected from all the available birds
#The sound for each bird are selected from all available sound files
#A list of all the data needed for the app, including the days images and sound files
#are saved to a single list, encased in a file, and copied to the shiny app server's directory.

if (!require(rollbar)) install.packages("rollbar",repos='https://cloud.r-project.org'); library(rollbar)

#Setup Rollbar process monitoring configuration
rollbar::rollbar.configure(access_token = '2358e1c706cf49a9804faf995c0195b5')
rollbar::rollbar.info("Birdle update script started")
print("Birdle update script started")

#Log to a file, sometimes useful, sometimes not, gets saved to working directory
#which may not be where you think it is
#con <- file('BirdleDailyUpdate.log', open = "wt")
#sink(con)
#sink(con, type = "message")

print("Birdle update script started")

#load libraries
list.of.packages <- c("shiny","shinyWidgets","shinyBS","shinyjs","curl","keyring","ssh","this.path")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages,repos='https://cloud.r-project.org')

librariesToLoad <- list.of.packages[!(list.of.packages %in% (.packages()))]
if(length(librariesToLoad)) sapply(librariesToLoad, library, character.only = TRUE)

#Set the working directory to the same location as this file
setwd(this.path::this.dir())

ShinyAppDataDirectory <- "Birdle/data"
ShinyWWWDirectory     <- "Birdle/www"
ProjectSoundFiles     <-   "SoundFiles"

NoOfSounds <- 5
AllBirdNames  <- c("Chaffinch","Miromiro","Kakaruai","Thrush","Blackbird",
                "Pipipi","Tauhou","Riroriro","Korimako","Kakariki",
                "Tititipounamu","Piwakawaka")
AllBirdToolTips <- c("Chaffinch<br/>Pahirini","Miromiro<br/>Tomtit","Kakaruai<br/>Robin","Thrush<br/>Manu-kai-hua-rakau","Blackbird<br/>Manu pango",
                  "Pipipi<br/>Brown creeper","Tauhou<br/>Silvereye","Riroriro<br/>Grey warbler","Korimako<br/>Bellbird","Kakariki<br/>Parakeet",
                  "Tititipounamu<br/>Rifleman","Piwakawaka<br/>Fantail")
TotalBirds <- length(AllBirdNames)
NoOfBirdButtons  <- 9
BirdSampleIndices <- sample(seq_len(TotalBirds),NoOfBirdButtons,replace=FALSE)

BirdNames    <- AllBirdNames[BirdSampleIndices]
BirdToolTips <- AllBirdToolTips[BirdSampleIndices]

SoundBirds <- sample(seq_len(NoOfBirdButtons),NoOfSounds,replace=FALSE)

SoundButtons <- lapply(seq_len(NoOfSounds), function(SoundNo) {
  SoundID <- paste0("Sound",SoundNo)
  actionButton(SoundID,label=NULL,icon = icon("play"), width = '15%')
})

#Prepare the bird buttons
BirdButtons <- lapply(seq_len(NoOfBirdButtons), function(BirdNo) {
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
#Each bird can have multiple sound recordings, so need to randomly pick one
for (SoundIndex in seq_len(NoOfSounds)) {
  RelatedBirdIndex <- SoundBirds[SoundIndex]
  BirdName <- BirdNames[RelatedBirdIndex]
  BirdSoundFiles <- list.files(file.path(ProjectSoundFiles),pattern=paste0("^",BirdName,".*\\.mp3$"))
  BirdSoundFileName <- sample(BirdSoundFiles,1,replace=FALSE)
  #BirdSoundFileName <- paste0(BirdName,".mp3")
  ThisSoundsFileName <- paste0("Sound",SoundIndex,".mp3")
  file.copy(file.path(ProjectSoundFiles,BirdSoundFileName),file.path(ShinyWWWDirectory,ThisSoundsFileName),overwrite = TRUE)
}

#Put all of these objects in a list and save to an RData file
BirdleSetupData <- list("NoOfSounds"=NoOfSounds, "BirdNames" = BirdNames,"NoOfBirds"=NoOfBirdButtons,"SoundBirds"=SoundBirds,"SoundButtons"=SoundButtons,"BirdButtons"=BirdButtons)
saveRDS(BirdleSetupData, file=file.path(ShinyAppDataDirectory,"BirdleInitialisationData.rds"))

#Open an SSH session and copy the files to the shinyapp server which is the Digital Ocean droplet called RainfallNZ
#This requires key pairs to be setup and available
#I generated key pairs using the windows ssh facility, and NOT PuTTYGen
#I have yet to setup the key pairs from the METSolJobs server to the shinyapps server
if (all((Sys.info()['sysname'] == "Windows"),(Sys.info()['nodename'] == "DESKTOP-H33OPJ4"))){
  session <- ssh::ssh_connect("tim@157.245.105.6",verbose=FALSE) #use verbose = TRUE for fault finding.
} else if ((Sys.info()['sysname'] == "Linux") & (Sys.info()['user'] == "tim")) {
  session <- ssh::ssh_connect("tim@157.245.105.6")
}
ssh::scp_upload(session,files=list.files(ShinyWWWDirectory,paste0("^Sound[1-",NoOfSounds,"]\\.mp3$"),full.names=TRUE),
                "/opt/shiny-server/samples/sample-apps/Birdle/www")
ssh::scp_upload(session,files=file.path(ShinyAppDataDirectory,"BirdleInitialisationData.rds"), to="/opt/shiny-server/samples/sample-apps/Birdle/data")
ssh::scp_upload(session,files=file.path("Birdle","app.R"), to="/opt/shiny-server/samples/sample-apps/Birdle")
ssh::ssh_disconnect(session)

rollbar::rollbar.info("Birdle update script ended")
print("Birdle update script ended")