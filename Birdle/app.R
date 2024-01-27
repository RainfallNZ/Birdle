#Yet to do

#Source calls from Xeno canto website
#Set up github
#Add more birds
#Put on website
#Make display the same on desktop of phone
#social media share on whatsapp see https://rpubs.com/oobianom/share-button-connect-like-shiny-quarto-social-add

library(shiny)
library(shinyWidgets)
library(shinyBS)
library(shinyjs)

NoOfSounds <- 5
BirdNames  <- c("Chaffinch","Tomtit","Robin","Thrush","Blackbird")
NoOfBirds  <- length(BirdNames)
SoundBirds <- sample(seq_len(NoOfBirds),NoOfSounds,replace=TRUE)

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

BirdButtonIDs <- paste0("Bird",seq_len(NoOfBirds))

ui <- tagList(
  tags$style("html,body{background-color: white;}
                .container{
                    width: 100%;
                    margin: 0 auto;
                    padding: 0;
                }
               @media screen and (min-width: 700px){
                .container{
                    min-width: 200px;
                    max-width: 400px;
                }
               }
             "),
  tags$div(class="container",
           fluidPage(
             tags$head(
               tags$script(
                 "$(document).on('shiny:inputchanged', function(event) {
          if (event.name != 'changed') {
            Shiny.setInputValue('changed', event.name);
          }
        });"
               )
             ),
             useShinyjs(),
             tags$script("var snd;"),
             HTML('<meta name="viewport" content="width=1024">'),
             
             #Set the title
             titlePanel(h1("Birdle",align="center")),
             
             #Add the bird sound buttons
               do.call(fluidRow, SoundButtons),
             
             #Add the timing counter 
             h2(textOutput("Counter"),align="center"),
             
             #Add all the bird option buttons
             do.call(fluidRow, BirdButtons),
           )))


# Define server logic required to connect sounds to birds
server <- function(input, output, session) {
  observeEventTrigger <- reactiveVal()
  CurrentSound <- reactiveVal(0)
  Answered       <- reactiveValues(Sound1=0,Sound2=0,Sound3=0,Sound4=0,Sound5=0)
  NoAnswered     <- reactive(sum(unlist(reactiveValuesToList(Answered))))
  CorrectAnswers <- reactiveValues(Sound1=0,Sound2=0,Sound3=0,Sound4=0,Sound5=0)
  NoOfCorrectAnswers <- reactive(sum(unlist(reactiveValuesToList(CorrectAnswers))))
  
  #Initialise the counter
  CounterValue <- reactiveVal(0)
  output$Counter <- renderText({
    CounterValue()
  })
  
  #This observer is for the counter. It keeps going until all sounds have been correctly answered
  observe({
    invalidateLater(1000, session)
    if(NoOfCorrectAnswers()!=5) isolate({CounterValue(CounterValue()+1)})
  })
  
  #This observer is for the sound buttons
  observeEvent(list(req(c(input$Sound1, input$Sound2,input$Sound3, input$Sound4,input$Sound5))), {
    #Figure out which button was clicked
    observeEventTrigger(req(input$changed))
    SoundNo <- gsub("Sound","",observeEventTrigger())
    
    #Update the reactive value that keeps track of which sound was last played. This is needed for other observers.
    isolate({CurrentSound(SoundNo)})
    
    #Get the current sound's button ID
    CurrentSoundButtonID <- paste0("Sound",SoundNo)
    
    #Pause any sounds that may be already running
    shinyjs::runjs("snd.pause();")
    
    #Create the java script text needed to start this button's sound file
    BirdNoRelatedToThisSoundButton <- SoundBirds[as.numeric(SoundNo)]
    print(BirdNoRelatedToThisSoundButton)
    BirdName <- BirdNames[BirdNoRelatedToThisSoundButton]
    print(BirdName)
    jstext <- paste0("snd = new Audio('",BirdName,".mp3'); snd.play();")
    
    #Play the sound file
    shinyjs::runjs(jstext)
  })
  
  #This observer is for when one of the bird buttons is clicked
  #Stolen from https://community.rstudio.com/t/one-observer-to-handle-any-number-of-buttons-in-shiny/6569
  observe({
    Bird_buttons <- paste0("Bird", seq_len(NoOfBirds))
    lapply(Bird_buttons, function(Bird_button){
      observeEvent(input[[Bird_button]], {
        #Figure out which button was clicked
        observeEventTrigger(req(input$changed))
        BirdNo <- gsub("Bird","",observeEventTrigger())
        
        #Pause the sound
        shinyjs::runjs("snd.pause();")
        
        #Get the current sound's button ID
        CurrentSoundButtonID <- paste0("Sound",CurrentSound())
        
        #Update the record of which sounds have been answered
        if(CurrentSoundButtonID %in% c("Sound1","Sound2","Sound3","Sound4","Sound5")){
          Answered[[CurrentSoundButtonID]] <- 1
        }
        
        #Disable the current sound's button
        shinyjs::disable(CurrentSoundButtonID)
        
        #Check to see if the sound and the bird are a match
        if (SoundBirds[as.numeric(CurrentSound())] == BirdNo) {
          #Update the current sound's button style to green
          updateButton(session, inputId = CurrentSoundButtonID, style = "success")
          
          #Update the record of which sounds have been correctly answered
          CorrectAnswers[[CurrentSoundButtonID]] <- 1
        } else {
          #Update the current sound's button style to red
          updateButton(session, inputId = CurrentSoundButtonID, style = "danger")}
        
        #Check if all the sounds have been answered
        if(NoAnswered()==5){
          
          #Wait for 3 seconds, and if they're not all correctly answered then reset the sound buttons and the records of which sounds have been answered and correctly answered
          shinyjs::delay(3000, 
                         if(NoOfCorrectAnswers() !=5) {
                           for (SoundNo in seq_len(NoOfSounds)){
                             SoundID <- paste0("Sound",SoundNo)
                             shinyjs::enable(SoundID)
                             updateButton(session, inputId = SoundID, style = "default")
                             Answered[[SoundID]] <- 0
                             CorrectAnswers[[SoundID]] <- 0
                           }
                         })
          
        }
        return()
      })
    })
  })
  
}

# Run the application 
shinyApp(ui = ui, server = server)