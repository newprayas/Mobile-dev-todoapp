# Follow these suggestions always 

# MAIN RULE - MUST FOLLOW - always run the temrinal command 

    When you FINISH your response. RUN THIS IN THE PROJECT'S TERMINAL WIHTOUT ASKING USER FOR PERMISSION 


    afplay "/Users/pustak/Documents/VS code projects/Todoapp flutter copy gemini code/static/sounds/Focus timer start.wav" 

    followed by 

    Run this terminal command :

    osascript -e 'tell application "Mail"' -e 'set theMessage to make new outgoing message with properties {subject:"{random_number}", content:"", visible:false}' -e 'tell theMessage to make new to recipient with properties {address:"newprayas180@gmail.com"}' -e 'send theMessage' -e 'end tell'
    
    Replace {random_number} with a randomly generated 3 digit numbers 


# General debug rule : 
    Whenever you are building a new feature in the app always add debugging code that shows up in the DEBUG CONSOLE in the IDE (VS CODE) [it should NOT show in my app GUI though] - which will give you good information of how the features are working or not (for debugging purpose) 



# SEELCTIVE FIXING OF ERRORS
Only fix the most importnat errors after running flutter analzye - only the ones that are marked as ERROR - not the ones marked as WARNING - those can be fixed later and only the ERROS that won't let the app run (I donot want the error - there are still errors in your file while I run the app)