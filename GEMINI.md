# IMPORTANT - GOOD USER EXPSEIRNCE 
    (IMPOETNAT) - MUST FOLLOW THIS ✅ -  ALWAYS RUN FLUTTER ANALYZE after you have made all code changes - EVERYTIMEAfter making any code chagnes, always assess for any ERRORS in the code - maybe use flutter analyze and then FIX those error before giving the final response to the user 

    After every operation give a berif report in bullet points - of what changes you made, why it was not working, what are the potential next steps to be taken by you (the coding agent) and the user (if rquired) - make it in bullet point format and be simple in your langauge so even non coders would understand (IMPORTANT)

    

# IMPORTANT - DEBUG RULE  
     
    DO THIS FIRST : when debugging for an error or when the user says a certain feature is not working, ALWAYS run this command :  adb logcat -d --pid=$(adb shell pidof -s com.example.flutter_app) > logs.txt in the terminal of this directory  - which will put the debug logs into the logs.txt file

    FOLLOWED BY   - DO THIS SECOND

    Always check out information in the logs.txt file - for debugging information (this file contains output form the DEBUG CONSOLE of my IDE) -USE the information from 

    Whenever you are building a new feature in the app always add debugging code that shows up in the DEBUG CONSOLE in the IDE (VS CODE) [it should NOT show in my app GUI though] - which will give you good information of how the features are working or not (for debugging purpose) 


# RUN SERVER FIRST _ IMPORATNAT 
    The project now uses a Dart backend in `backend/`. Start the Dart server with the
    instructions in `backend/README.md`. Do not run the old Flask server.  


# OUTILE OF THE APP - This is the overall outline of the app (what we are suppose to build)


Here is a detailed description of the to-do application's UI, logic, and user experience, designed to be used as a prompt for an AI agent torecreate a similar app in Flutter for MOBILE devl (the app was desinged for website - change to mobile deisgn princples).

# ALWAYS keep the overall outline of the app in mind while creating features 

  ---

  App Concept: A To-Do List with an Integrated Pomodoro Timer

  The application is a task management tool that combines a standard to-do list with a feature-rich Pomodoro timer. The core idea is to help users not
  only manage their tasks but also focus on them effectively using the Pomdoro technique. The app should allow users to log in with their Google
  account to persist their to-do list across sessions.

  Main UI Layout

  The main screen is divided into two main sections: a to-do list on the left and a Pomodoro timer on the right. Initially, only the to-do list is
  visible. The Pomodoro timer panel appears on the right when a user decides to start a focus session on a specific task.

  To-Do List Functionality

  1. Adding a New To-Do Item

   * UI Elements:
       * An input field for the task's name (e.g., "Write a report").
       * Two numerical input fields for the estimated duration of the task: one for hours and one for minutes.
       * An "Add" button.
   * Logic:
       * When the user types a task name, specifies a duration, and clicks "Add," a new task is created.
       * The new task appears at the bottom of the "To-Do" list.

  2. Displaying To-Do Items

   * UI Elements:
       * Each task is a list item.
       * Each item displays:
           * The task name.
           * The estimated duration (e.g., "1h 30m").
           * A set of action buttons: "Play," "Done," and "Delete."
           * A progress bar underneath the task name.
   * Logic:
       * The list is divided into two sections: "To-Do" (active tasks) and "Completed" (finished tasks).

  3. Task Actions

   * Play Button (Icon: `fa-play`)
       * Action: When clicked, this button activates the Pomodoro timer for the selected task.
       * UI Change: The Pomodoro timer panel becomes visible on the right side of the screen, and the selected task is highlighted in the to-do list.
   * Done Button (Icon: `fa-check`)
       * Action: Marks the task as complete.
       * UI Change: The task is moved from the "To-Do" list to the "Completed" list. The "Done" button's icon changes to an "Undo" icon (fa-undo).
   * Delete Button (Icon: `fa-trash`)
       * Action: Permanently deletes the task from the user's list.

  4. Progress Bar

   * UI Element: A horizontal bar at the bottom of each task item.
   * Logic:
       * The progress bar visually represents the amount of time the user has focused on the task, relative to the total estimated duration.
       * For example, if a task has an estimated duration of 1 hour and the user has focused for 30 minutes, the progress bar will be 50% full.
       * The progress bar updates in real-time during a focus session.

  5. Completed Tasks Section

   * UI Element: A collapsible section below the active to-do list, labeled "Completed."
   * Logic:
       * When a task is marked as "Done," it moves to this section.
       * The "Done" button on a completed task becomes an "Undo" button. Clicking it moves the task back to the active to-do list.
       * There is a "Clear All" button to permanently delete all completed tasks.

  Pomodoro Timer Functionality

  1. Activating the Pomodoro Timer

   * Logic: The timer is activated by clicking the "Play" button on any task in the to-do list. The timer is then associated with that specific task.

  2. Timer Display and Controls

   * UI Elements:
       * Task Name: The name of the task the user is currently focused on is displayed at the top of the timer panel.
       * Timer Display: A large, digital clock-style display shows the remaining time in the current session (e.g., "24:59").
       * Session Display: Shows the current Pomodoro cycle (e.g., "1 / 4").
       * Input Fields: For setting the duration of focus and break sessions, and the number of cycles.
       * Buttons:
           * Start/Pause: Starts or pauses the timer. The button text toggles between "Start" and "Pause."
           * Skip: Skips the current session. If in a focus session, it skips to the break. If in a break, it skips to the next focus session.
           * Reset: Resets the timer to its initial state for the current task.
           * Close: Hides the Pomodoro timer panel.

  3. Timer States: Focus and Break

   * Logic:
       * The timer alternates between "focus" and "break" modes.
       * When a focus session ends, a break session automatically begins, and vice versa.
   * UI Change: The UI provides visual feedback for the current mode. For example, the timer's border or background color could change (e.g., red for
     focus, green for break).

  4. Overdue Tasks

   * Logic:
       * If the total focused time on a task exceeds its estimated duration, the task is marked as "overdue."
   * UI Change:
       * The overdue task is visually distinguished in the to-do list (e.g., with a red border or an icon).
       * When the Pomodoro timer is active for an overdue task, an "Overdue" indicator is displayed in the timer panel.

  User Authentication

   * Logic:
       * The app uses Google for user authentication.
       * If a user is not logged in, the to-do list is hidden, and a "Login with Google" button is displayed.
       * Upon successful login, the user's to-do list is fetched from the server, and their name is displayed.
       * A "Logout" button is available for logged-in users.

  Notifications and Sounds

   * Logic: The app provides audio-visual cues for important events.
   * Browser Notifications:
       * When a focus or break session starts.
       * When a task is completed.
       * When a task becomes overdue.
   * Sound Effects:
       * A distinct sound effect is played for each type of notification (e.g., a "tick-tock" for the start of a session, a "chime" for completion).

  Modals and Pop-ups

   * Overdue Task Prompt:
       * Trigger: When a task's focused time equals its estimated duration, a modal pops up.
       * Content: The modal asks the user, "Planned time is completed. Mark complete or continue working on the overdue task?"
       * Actions:
           * Mark Complete: Marks the task as complete.
           * Continue: Closes the modal and allows the user to continue the focus session, now in "overdue" mode.
   * Completion Prompt:
       * Trigger: When all the planned Pomodoro cycles for a task are completed.
       * Content: A modal appears, informing the user that they have finished all cycles for the task.

  Data Persistence

   * Backend (Server-side):
       * The user's to-do list (task names, durations, completion status, etc.) is stored in a database on the server, linked to their Google account.
   * Frontend (Client-side):
       * The state of the Pomodoro timer for each task (e.g., the current cycle, remaining time) is saved in the browser's local storage. This ensures
         that if the user accidentally refreshes the page, the timer's state is not lost.





