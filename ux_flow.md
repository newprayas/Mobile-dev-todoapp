FINAL REVISED 

Of course. I have integrated the finalized logic for the `Reset` button, the "Stop & Save" `Close` button, and the "Switch Task" flow directly into the master flowchart you provided.

The changes are clearly marked with a `🔥 [REVISED LOGIC]` annotation. The rest of the flowchart remains the same, preserving the excellent structure you designed.

---

### Master UX Flowchart (Immutable Tasks Version - FINALIZED)

**A Note on Task Immutability:** *This workflow operates under the principle that once a task is created, its name and planned duration cannot be edited. To change these properties, a user must delete the existing task and create a new one. This simplifies the application's logic and encourages deliberate planning.*

**🚀 APP STARTUP**
|
├── NotificationService.init()
├── Backend readiness check (up to 8 attempts, DEBUG only)
|
|
**🔐 AUTHENTICATION CHECK**
|
├── `authProvider` checks for a saved token.
├── User authenticated?
│   ├── ✅ YES → **Navigate to `TodoListScreen`**
│   └── ❌ NO → **Navigate to `LoginScreen`**
|
|
**📱 LOGIN SCREEN (if not authenticated)**
|
├── Display: Welcome to TodoApp, Sign in with Google button.
├── **Event: User taps "Sign in with Google" button**
│   ├── UI → Show loading indicator: "Signing you in..."
│   ├── `authProvider.signInWithGoogle()` is called.
│   │   ├── ✅ **Success:** `isAuthenticated` becomes true.
│   │   │   └── `AuthWrapper` → **Rebuilds and navigates to `TodoListScreen`**.
│   │   └── ❌ **Failure:**
│   │       ├── `authProvider` reports an error.
│   │       └── UI → Shows a red `SnackBar`: "Google Sign-In failed". User remains on `LoginScreen`.
|
|
**🏠 TODO LIST SCREEN (Main App Interface)**
|
├── **TOP APP BAR**
│   ├── Title: "Todo List"
│   └── User Menu (Avatar, Name, Email)
│       └── **Event: User taps avatar/menu**
│           └── `Sign Out` dropdown option appears.
│               └── **Event: User taps "Sign Out"**
│                   └── **`Sign Out Confirmation Dialog`**
│                       ├── Shows: "Are you sure you want to sign out?"
│                       ├── **Option: "Cancel"** → Closes dialog.
│                       └── **Option: "Sign Out"** → `authProvider.signOut()` → Navigates to `LoginScreen`.
|
├── **MAIN CONTENT CARD**
│   ├── Header: "TO-DO APP"
│   ├── Welcome: "Welcome, {userName}!" (Dynamically loaded)
│   │
│   ├── **📝 ADD NEW TASK SECTION**
│   │   ├── Text input for task name.
│   │   ├── Duration inputs: Hours and Minutes (default: 0h 25m).
│   │   └── **Event: User taps "Add" button**
│   │       ├── `todosProvider.addTodo()` is called.
│   │       ├── ✅ **Success:** The form fields are cleared, keyboard dismissed.
│   │       └── ❌ **Failure (Network/API error):** A red `SnackBar` appears: "Failed to add task."
│   │
│   ├── **📋 ACTIVE TASKS LIST**
│   │   ├── If no incomplete tasks → Shows empty state message: "No tasks yet..."
│   │   └── **Task Cards (for each incomplete task)**
│   │       ├── **Task Name & Duration:** Displayed as read-only text.
│   │       ├── **Real-time Progress & Status Tags:** (As defined in the tag logic flowchart).
│   │       ├── **🔥 [REVISED LOGIC] Dynamic `▶️`/`⏸️` Play/Pause Button:**
│   │       │   ├── If timer is active for *this task* → Button shows `⏸️` (if running) or `▶️` (if paused). Tapping toggles the timer state.
│   │       │   └── If timer is inactive or for another task → Button shows `▶️`. Tapping **initiates the "Start Session" flow**:
│   │       │       ├── **1. Check if another task's timer is already active.**
│   │       │       │   ├── ✅ **YES** → **Triggers `Switch Task Confirmation Dialog`** (see Dialogs flowchart).
│   │       │       │   └── ❌ **NO** → **Opens `Pomodoro Screen` in Setup Mode** for this task.
│   │       ├── **Event: User taps `✅` Complete button** → `todosProvider.toggleTodo()` → Moves task to "Completed" section.
│   │       └── **Event: User taps `🗑️` Delete button** → **`Delete Task Confirmation Dialog`**
│   │           ├── **Option: "Cancel"** → Closes dialog.
│   │           └── **Option: "Delete"** → `todosProvider.deleteTodo()` → Task is removed. **If it was the active task, the timer is cleared, dismissing any active Pomodoro/Mini Bar UI.**
│   │
│   └── **📊 COMPLETED TASKS SECTION**
│       ├── Expandable section.
│       └── When expanded, shows completed tasks and a "Clear All" button, which triggers its own confirmation dialog.
│
└── **📊 MINI TIMER BAR (at the bottom)**
    ├── **Appears automatically** when `PomodoroScreen` is closed with an active timer.
    ├── Border color syncs with timer mode (Red for focus, Green for break).
    ├── Displays active task name and remaining time.
    ├── **Event: User taps `▶️`/`⏸️` Play/Pause button** → Toggles the global timer state.
    ├── **Event: User taps anywhere on the bar** → **Re-opens the full `Pomodoro Screen`**, preserving the timer's current state.
    └── **Is automatically hidden** if the associated task is deleted, completed, or the session is stopped.
|
|
**🍅 POMODORO SCREEN (Modal Bottom Sheet)**
|
├── **SETUP MODE (Initial state)**
│   ├── Fields for Work Duration and Break Time are pre-filled.
│   └── Automatic Cycle Calculation: The "Cycles" field is read-only and calculated as: `ceil(planned_task_duration / work_duration)`.
	NOTE the focus duration CANNOT be more than the Total task duration (If user puts this and tries to start the timer. - give a pop up with appropriate error message) 
│
├── **RUNNING MODE**
│   ├── Displays current cycle (`X / Y`) and a progress bar (Normal Mode) or an Overdue Timer (Overdue Mode).
│   └── **🔥 [REVISED LOGIC] `🔄` Reset button →** Reverts the timer for the *current phase only* back to its full duration. Any time passed *within that specific interval* is subtracted from the task's total `focused_time`. This works for both normal and overdue sessions, correctly preserving all previously accumulated time.
│
├── **AUTOMATIC BEHAVIORS**
│   ├── Focus/Break timers automatically transition with sound and notifications.
│   ├── **`focused_time` >= `planned_duration`** → **Triggers `Overdue Dialog`**.
│   └── **`current_cycle` > `total_cycles`** → **Triggers `All Sessions Complete Dialog`**.
|
└── **🔥 [REVISED LOGIC] Event: User taps `❌` Close button** → **Triggers `Stop Session Confirmation Dialog`** (see Dialogs flowchart).

---

### Flowchart for Pop-ups and Dialogs (Immutable Tasks Version - FINALIZED)

This flowchart details every modal interaction in the application.

**📱 USER ACTION TRIGGERS**
|
├── **Taps "Sign Out"**
│   └── `Sign Out Confirmation Dialog`
│       ├── Shows: "Are you sure you want to sign out?"
│       ├── **Option: "Cancel"** → Closes dialog.
│       └── **Option: "Sign Out"** → `authProvider.signOut()` → Navigates to `LoginScreen`.
|
├── **Taps `🗑️` on a Task Card**
│   └── `Delete Task Confirmation Dialog`
│       ├── Shows: "This will remove the task permanently."
│       ├── **Option: "Cancel"** → Closes dialog.
│       └── **Option: "Delete"** → `todosProvider.deleteTodo()` → Task removed.
|
├── **Taps `🗑️` in "Completed" Section**
│   └── `Clear Completed Confirmation Dialog`
│       ├── Shows: "This will permanently delete all completed tasks."
│       ├── **Option: "Cancel"** → Closes dialog.
│       └── **Option: "Clear"** → `todosProvider.clearCompleted()` → Completed tasks removed.
|
├── **🔥 [REVISED LOGIC] Taps `▶️` on a Task Card while another session is active**
│   └── **`Switch Task Confirmation Dialog`**
│       ├── Shows: "Switch to '{New Task}'? This will stop the current session for '{Old Task}' and save its progress."
│       ├── **Option: "Cancel"** → Closes dialog. The original session for '{Old Task}' continues uninterrupted.
│       └── **Option: "Switch"** → **Stops & Saves** the session for '{Old Task}', banking any partial progress. Then opens `Pomodoro Screen` in **Setup Mode** for '{New Task}'.
|
├── **🔥 [REVISED LOGIC] Taps `❌` on Pomodoro Screen**
│   └── **`Stop Session Confirmation Dialog`**
│       ├── **Pauses the timer** while the dialog is active.
│       ├── Shows: "Stop session for '{Task Name}'? Your progress of {X minutes} from this interval will be saved."
│       ├── **Option: "Cancel"** → The dialog is dismissed. **The timer resumes** from where it was paused.
│       └── **Option: "Stop & Save"** → Captures and saves partial progress, terminates the session, and closes the `Pomodoro Screen`. The `Mini Timer Bar` does not appear.
|
└── **Taps `▶️` on a Task Card (no other session active) OR taps on the `MiniTimerBar`**
    └── **`Pomodoro Screen (Modal Bottom Sheet)`**
        └── This is the main timer interface, whose complex logic is detailed in the main flowchart.

**🤖 AUTOMATIC SYSTEM TRIGGERS (Inside Pomodoro Screen)**
|
├── **`focused_time` >= `planned_duration`**
│   └── **`Overdue Dialog`**
│       ├── **Pauses timer.**
│       ├── Shows: "Planned time is complete. Mark task as done or continue working?"
│       ├── **Option: "Mark Complete"** → `todosProvider.toggleTodo()`, closes Pomodoro screen, clears timer.
│       └── **🔥 [REVISED LOGIC] Option: "Continue"** → Dialog is dismissed. **The timer resumes and continues running** in an "Overdue Mode". The task is flagged internally to show the persistent `🔴` overdue icon on the main list.
|
└── **`current_cycle` > `total_cycles`**
    └── **`All Sessions Complete Dialog`**
        ├── **Pauses timer.**
        ├── Shows: "You have completed all X focus sessions..."
        └── **🔥 [REVISED LOGIC] Option: "Dismiss"** → **The session gracefully ends.** The `PomodoroScreen` closes, the `Mini Timer Bar` is hidden, and the user is returned to the `TodoListScreen`.

---

### Master Flowchart for Task Card Status & Tag Logic (Immutable Task Version)
*(This section had no required changes and remains the same as your excellent original version.)*

**entryway TaskCard Widget Build Process**
|
├── 1. Check Overall Task Status
│   └── Is task.completed == true?
│   ├── ✅ YES → Go to ➡️ Flow for Completed Tasks
│   └── ❌ NO → Go to ➡️ Flow for Incomplete Tasks
|
|
➡️ **Flow for Incomplete Tasks**
|
├── 2. Check for Active Timer State (Visual Indicator)
│   └── Is timerProvider.activeTaskName == task.text?
│   └── ✅ YES → Display a bright yellow border around the entire TaskCard.
│   └── This visually links the card to the active MiniTimerBar or PomodoroScreen, indicating it's the "task in focus."
|
├── 3. Check for Overdue Status (Text Tag & Visual Cue)
│   └── Does task.planned_duration > 0?
│   ├── ❌ NO (Task has no planned duration) → No tag is displayed. The task can never be overdue.
│   └── ✅ YES (Task has a planned duration)
│   └── Calculate: Use the live_focused_time from the timerProvider's cache if available; otherwise, use the value from the database.
│   └── Is live_focused_time >= task.planned_duration?
│   ├── ❌ NO → No tag is displayed. The task is on track.
│   └── ✅ YES → The task is now considered Overdue.
│   ├── Display Text Tag: "Overdue: X:XX" (in red)
│   │   └── Calculation: The displayed time is live_focused_time - task.planned_duration, formatted as minutes and seconds (or hours). This provides a running clock of the "overage" time.
│   │
│   └── Check for "Continued Overdue" Status:
│   └── Is task.text present in the timerProvider.overdueContinued set?
│   └── ✅ YES (User explicitly chose "Continue" from the Overdue Dialog in a previous session for this task) → Display a red dot 🔴 icon next to the task text as a persistent visual reminder that this task has exceeded its plan.
|
|
➡️ **Flow for Completed Tasks**
|
├── 4. Set Visual Style
│   └── The entire TaskCard is rendered with 50% opacity to visually de-emphasize it.
|
├── 5. Check for Underdue/Completed Status (Text Tag)
│   └── Does task.planned_duration > 0?
│   ├── ❌ NO (Task had no planned duration) → Display Text Tag: "Completed" (in green).
│   └── ✅ YES (Task had a planned duration)
│   └── Is task.focused_time < task.planned_duration?
│   ├── ✅ YES → The task was completed before its planned time was met.
│   │   └── Display Text Tag: "Underdue task X%" (in orange).
│   │   └── Calculation: The percentage is (task.focused_time / task.planned_duration) * 100.
│   │
│   └── ❌ NO (task.focused_time >= task.planned_duration) → The task was completed at or after its planned time was met.
│   └── Display Text Tag: "Completed" (in green). The "Overdue" status is no longer shown because the primary status is now "Completed".


now evlauate this revised chart 