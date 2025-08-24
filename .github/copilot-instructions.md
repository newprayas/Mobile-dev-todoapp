# Follow these suggestions always 

# General debug rule : 
    Whenever you are building a new feature in the app always add debugging code that shows up in the DEBUG CONSOLE in the IDE (VS CODE) [it should NOT show in my app GUI though] - which will give you good information of how the features are working or not (for debugging purpose) 


# IMPORTANT - DEBUG RULE  

    When the user says : ;debug in the chat : Execute the follwoing steps in order : 
     
    DO THIS FIRST : when debugging for an error or when the user says a certain feature is not working, ALWAYS run this command :  adb logcat -d --pid=$(adb shell pidof -s com.example.flutter_app) > logs.txt in the terminal of this directory  - which will put the debug logs into the logs.txt file

    FOLLOWED BY   - DO THIS SECOND

    Always check out information in the logs.txt file - for debugging information (this file contains output form the DEBUG CONSOLE of my IDE) -USE the information from 


# SEELCTIVE FIXING OF ERRORS
Only fix the most importnat errors after running flutter analzye - only the ones that are marked as ERROR - not the ones marked as WARNING - those can be fixed later and only the ERROS that won't let the app run (I donot want the error - there are still errors in your file while I run the app)