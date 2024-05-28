#load libraries
list.of.packages <- c("shiny","shinyWidgets","shinyBS","shinyjs")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages,repos='https://cloud.r-project.org')

librariesToLoad <- list.of.packages[!(list.of.packages %in% (.packages()))]
if(length(librariesToLoad)) sapply(librariesToLoad, library, character.only = TRUE)

BirdleSetupData <- readRDS(file="data/BirdleInitialisationData.rds")

list2env(BirdleSetupData,envir = .GlobalEnv)

ui <- tagList(
  tags$div(id='Everything',class="container",
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
             tags$head(tags$link(rel="shortcut icon", href="favicon.ico")),
             useShinyjs(),
             tags$script("var snd;"),
             
             #Set the title
             titlePanel(h1("Birdle",align="center"),windowTitle = "Birdle"),
             
             #Add the bird sound buttons
             fluidRow(align="center",do.call(fluidRow, SoundButtons)),

             #Add the timing counter 
             h2(textOutput("Counter"),align="center"),
             
             #Add all the bird option buttons in a fluid row that is wrapped in a fluid row with centre allignment
             fluidRow(align="center",width=12,do.call(fluidRow, BirdButtons[1:3])),
             fluidRow(align="center",do.call(fluidRow, BirdButtons[4:6])),
             fluidRow(align="center",do.call(fluidRow, BirdButtons[7:9])))
           ))

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
    print(SoundNo)
    
    #Update the reactive value that keeps track of which sound was last played. This is needed for other observers.
    isolate({CurrentSound(SoundNo)})
    
    #Get the current sound's button ID
    CurrentSoundButtonID <- paste0("Sound",SoundNo)
  })
  
  #This observer is for controlling the sound. It is all in javascript to enable 
  #correct operation on IOS devices.See https://stackoverflow.com/questions/73934037/stop-all-audio-when-a-new-one-is-playing
  #I haven't seen this issue referenced with respect to RShiny
  observe(priority = 1, {
    JavascriptText <- "
    
    function pauseAudio() {
          if(snd && !snd.paused) {   // Pause and rewind any currently playing audio
        snd.pause(); 
        snd.currentTime = 0;
       };
    }
    function playAudio(src) {
      pauseAudio()   // Pause and rewind any currently playing audio
      snd = new Audio(src);      // Save a reference
      snd.play();
    }

    const button = document.getElementById('Sound1');
    const button2 = document.getElementById('Sound2');
    const button3 = document.getElementById('Sound3');
    const button4 = document.getElementById('Sound4');
    const button5 = document.getElementById('Sound5');
    
    const Birds = document.querySelectorAll('button[id^=Bird]');

    let snd = null;
        
    button.addEventListener('click', () => {
          playAudio('Sound1.mp3')
        });
    button2.addEventListener('click', () => {
           playAudio('Sound2.mp3')
        })
    button3.addEventListener('click', () => {
           playAudio('Sound3.mp3')
        })
    button4.addEventListener('click', () => {
           playAudio('Sound4.mp3')
        })
    button5.addEventListener('click', () => {
           playAudio('Sound5.mp3')
        })
    //Turn off sound if any Bird button is clicked    
    Birds.forEach(Bird => {
      Bird.addEventListener('click', () => {pauseAudio()})
    })
    "
    shinyjs::runjs(JavascriptText)
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
        print(CurrentSoundButtonID)
        #Update the record of which sounds have been answered
        if(CurrentSoundButtonID %in% c("Sound1","Sound2","Sound3","Sound4","Sound5")){
          Answered[[CurrentSoundButtonID]] <- 1
          
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
        }
        #Check if all the sounds have been answered
        if(NoAnswered()==5){
          
          #Wait for 3 seconds, and if they're not all correctly answered then reset the sound buttons and the records of which sounds have been answered and correctly answered
          shinyjs::delay(1500, 
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
