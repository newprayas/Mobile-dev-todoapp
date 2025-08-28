# Follow these suggestions always 

# MAIN RULE - MUST FOLLOW - always run the temrinal command 

    When you FINISH your response. RUN THIS IN THE PROJECT'S TERMINAL WIHTOUT ASKING USER FOR PERMISSION 


    afplay "/Users/pustak/Documents/VS code projects/Todoapp flutter copy gemini code/static/sounds/Focus timer start.wav" 


# HIGH PRIORITY - MUST FOLLOW : FOLLOW THESE AI INSTRUCTIONS - MUST DO 

Excellent. Moving beyond file structure to the actual *content and process* of coding is the next critical step. To make an AI agent work at peak efficiency and accuracy, you should aim to create a codebase that is as predictable, explicit, and unambiguous as possible.

Here are further suggestions, framed as instructions for the AI agent that will implement them. These principles will drastically reduce the "cognitive load" on the agent, allowing it to produce better results, faster.

---

### Principle 1: Maximize Code Clarity & Explicitness

Your agent's primary challenge is ambiguity. It must infer intent from code. The less it has to infer, the more accurate it will be.

**Suggestion 1.1: Enforce Strict Type Safety.**
*   **Instruction:** Explicitly declare the type for every variable. Avoid using `var` or `dynamic` unless absolutely necessary.
*   **Example:** Instead of `var user = authState.value.currentUser;`, use `final Map<String, dynamic>? user = authState.value.currentUser;`.
*   **Why it helps the AI:** The agent immediately knows the "shape" of the data it's working with. It doesn't have to guess whether a variable is a `String`, `int`, or a custom `Todo` object. This eliminates a massive category of potential errors and reduces the amount of context the agent needs to hold in its memory.

**Suggestion 1.2: Embrace Immutability.**
*   **Instruction:** All model and state classes should be immutable. Class properties should be declared as `final`. To modify an object, create a new one using a `copyWith` method.
*   **Example:** Your `Todo` and `TimerState` models already do this perfectly. Maintain this pattern rigorously. For example, if you create a new state class, ensure it follows this structure.
*   **Why it helps the AI:** The agent can reason about state changes with certainty. It knows that an object, once created, cannot be changed from somewhere else in the app unexpectedly. This makes data flow predictable and debugging trivial. When asked to "update the user's name," its first instinct will be to correctly look for a `user.copyWith(name: newName)` pattern, not to try and mutate the object directly.

**Suggestion 1.3: Use Descriptive and Consistent Naming.**
*   **Instruction:** Variable and function names must describe their full purpose. Be verbose.
*   **Examples:**
    *   **Good:** `final bool isTimerInSetupMode = !timerState.isRunning && timerState.currentCycle == 0;`
    *   **Less Good:** `final bool setup = !timerState.isRunning && timerState.currentCycle == 0;`
    *   **Good:** `Future<void> _handleMarkTaskCompleteWithOverdue(...)`
    *   **Less Good:** `Future<void> _handleOverdue(...)`
*   **Why it helps the AI:** Verbose names act as inline documentation. When the agent sees `isTimerInSetupMode`, it requires zero extra context to understand what that boolean represents. This reduces the amount of surrounding code it needs to analyze to understand the purpose of a single line.

**Suggestion 1.4: Write Purposeful Comments for the "Why," not the "What."**
*   **Instruction:** Use comments only to explain *why* a piece of code exists, especially if the logic is non-obvious. Do not use comments to explain *what* the code is doing—the code itself should do that.
*   **Example:**
    *   **Good:** `// We stop the ticker here before showing the dialog to prevent a race condition where the timer completes while the dialog is open.`
    *   **Bad:** `// Stop the timer.` (The code `_ticker.cancel()` already says this).
*   **Why it helps the AI:** This provides crucial business logic and intent that is impossible to infer from the code alone. It helps the agent make safer changes that respect the underlying architectural decisions.

---

### Principle 2: Enforce Predictable State Management

Your agent needs a single, clear path to read and update application state. A single source of truth is paramount.

**Suggestion 2.1: Consolidate All Shared State in Riverpod.**
*   **Instruction:** Eliminate the use of `StatefulWidget` and `setState` for any state that is shared between widgets or needs to be preserved. Use Riverpod providers as the definitive source of truth.
*   **Example:** In `_TodoListState`, the `_completedExpanded` flag is local state. This is acceptable for now. However, if you ever wanted to save the user's preference for whether that section is expanded, you would move it into a provider.
*   **Why it helps the AI:** When asked to "read the current filter setting," the agent knows to look in a provider. When asked to "update the filter," it knows to call a method on that provider's notifier. This creates an extremely predictable workflow that the agent can reliably follow.

**Suggestion 2.2: Adhere Strictly to Unidirectional Data Flow.**
*   **Instruction:** All state modifications must follow this pattern:
    1.  UI Widget (e.g., a button) calls a method on a Notifier (`ref.read(todosProvider.notifier).addTodo(...)`).
    2.  The Notifier contains the business logic and updates its own state.
    3.  Riverpod automatically rebuilds the UI Widgets that are watching (`ref.watch`) the provider.
*   **Why it helps the AI:** This pattern is simple and deterministic. The agent can easily trace the cause and effect of any action. It prevents it from generating code that tries to modify UI or state from inappropriate places, leading to more robust and maintainable results.

---

### Principle 3: Maintain a Healthy and Reliable Build Environment

An agent can get completely derailed by a broken build, stale generated files, or a lack of clear success criteria.

**Suggestion 3.1: Always Run the Build Runner After Changes.**
*   **Instruction:** After making any changes to files that have a `.g.dart` counterpart (like providers using the `riverpod_generator`), immediately run `dart run build_runner build --delete-conflicting-outputs`.
*   **Why it helps the AI:** The agent assumes that the generated files are correct and in-sync. If they are stale, the agent will get confused by analyzer errors that don't seem to match the code it's looking at. This leads to wasted time and incorrect suggestions. Keeping the build clean is essential.

**Suggestion 3.2: Write Tests.**
*   **Instruction:** For every new feature or piece of complex logic (especially in providers), create a corresponding test file.
*   **Example:** Create a test for your `TodosNotifier`. Test the `addTodo` optimistic update logic. Test the `deleteTodo` logic.
*   **Why it helps the AI:** Tests are *executable documentation*. The agent can read `todos_provider_test.dart` to understand exactly how the `addTodo` method is *supposed* to behave, including edge cases. This is more reliable than any comment. When you ask it to modify that logic, it can run the existing tests to ensure it hasn't broken anything, making its refactoring work much safer.

---

### Principle 4: Communicate with the Agent Effectively

The final piece is how you, the human, interact with the agent. Your prompts are its requirements document.

**Suggestion 4.1: Be Hyper-Specific and Provide Full Context.**
*   **Instruction:** Instead of a vague request like "fix the delete button," provide a very specific, context-rich prompt.
*   **Example:**
    *   **Good:** "In the file `lib/features/todo/widgets/task_card.dart`, the `onDelete` callback is not working correctly. When a task is deleted, it should also clear the timer if that task was active. Please modify the `onPressed` handler for the delete `IconButton` to check if `timerState.activeTaskName == t.text` and, if so, call `ref.read(timerProvider.notifier).clear()` before calling `ref.read(todosProvider.notifier).deleteTodo(t.id)`. Here is the full content of `task_card.dart`: [paste code here]."
    *   **Bad:** "The delete button doesn't stop the timer."
*   **Why it helps the AI:** The good prompt gives the agent the file path (where to work), the specific function (what to change), the business logic (the goal), and the full code context. It removes all guesswork and allows the agent to focus 100% on implementing the solution.


# SEELCTIVE FIXING OF ERRORS
Only fix the most importnat errors after running flutter analzye - only the ones that are marked as ERROR - not the ones marked as WARNING - those can be fixed later and only the ERROS that won't let the app run (I donot want the error - there are still errors in your file while I run the app)



# MUSt FOLLOW - IMPORTANT - ALWAYS prefer modularity of code - KEEP YOUR CODE AS MODULAR AS POSISBLE 
Summary Table: AI Preference
Attribute	More Modular (AI's Preference)	Less Modular (Monolithic)
Context Usage	Efficient. Small, relevant files fit easily.	Inefficient. Large files consume entire context, risking errors.
Accuracy	High. Clear scope and responsibilities reduce ambiguity.	Lower. Complex interactions increase the chance of subtle bugs.
Speed	Faster. I can locate and modify code with high precision.	Slower. I must first parse and understand the entire file before acting.
Safety	High. Changes are isolated, minimizing side effects.	Low. High risk of unintended regressions in unrelated code.
Scalability	Excellent. Easy to add new features by adding new files.	Poor. Each new feature makes the central file harder to manage.
Testing	Easy. Components can be tested in isolation.	Difficult. Requires complex setup to test a small part of the UI.
Conclusion: For a project of your current size and complexity, especially with the rich feature set you're building, continuing to invest in modularity is the single best thing you can do to make your collaboration with an AI assistant more effective, faster, and safer. 



# IMPOETNAT - FOLLOW GOOD PRACITCES BELOW : 

Directives for AI Code Generation and Refactoring
Preamble: Your primary goal is to produce code that is readable, maintainable, and predictable. Adherence to the following three laws is mandatory for all generated or modified code.
Law 1: The Law of Shallow Code (Avoid Deep Nesting)
Principle: Code that flows linearly from top to bottom is easiest to understand. Deeply nested conditional logic (if/else if/else) inside build methods or functions must be avoided.
Directive 1.1: Use Guard Clauses and Early Returns.
In any function or method, handle edge cases, loading states, and error states at the very beginning and return immediately. This prevents the main "happy path" logic from being indented within an else block.
Example (Refactor this pattern):
code
Dart
// INEFFECTIVE: Deeply nested
Widget build(BuildContext context) {
  if (!state.isInitialized) {
    return Text('Not ready');
  } else {
    if (state.hasError) {
      return Text('Error!');
    } else {
      if (state.items.isEmpty) {
        return Text('No items');
      } else {
        // Main UI logic starts here, already 3 levels deep
        return ListView(...);
      }
    }
  }
}
Correct Implementation (Follow this pattern):
code
Dart
// EFFECTIVE: Linear and shallow
Widget build(BuildContext context) {
  if (!state.isInitialized) {
    return Text('Not ready');
  }
  if (state.hasError) {
    return Text('Error!');
  }
  if (state.items.isEmpty) {
    return Text('No items');
  }

  // Main UI logic starts here at the top level
  return ListView(...);
}
Directive 1.2: Extract Conditional UI into Builder Methods or Widgets.
Within a build method, do not use complex if/else statements or ternary operators to show/hide different widgets inside the tree. Instead, extract that logic into a separate, well-named function or a dedicated widget.
Example (Refactor this pattern):
code
Dart
// INEFFECTIVE: Logic is hidden inside the Column
Column(
  children: [
    Text('Header'),
    if (timerState.isRunning)
      Text('Timer is active')
    else
      Text('Timer is paused'),
    Footer(),
  ],
)
Correct Implementation (Follow this pattern):
code
Dart
// EFFECTIVE: Intent is clear from the function name
Column(
  children: [
    Text('Header'),
    _buildTimerStatusMessage(timerState), // Extraction
    Footer(),
  ],
)

Widget _buildTimerStatusMessage(TimerState timerState) {
  if (timerState.isRunning) {
    return Text('Timer is active');
  }
  return Text('Timer is paused');
}
Law 2: The DRY Principle (Don't Repeat Yourself)
Principle: Every piece of logic or UI configuration should have a single, authoritative representation within the codebase. Duplication is a source of bugs and maintenance overhead.
Directive 2.1: Consolidate Repeated UI into Reusable Widgets.
If you identify identical or very similar widget structures (e.g., buttons with the same styling, input fields, cards), you must extract them into a new, reusable widget file.
Example (Refactor this pattern):
code
Dart
// INEFFECTIVE: Button styling is duplicated
ElevatedButton(
  child: Text('Add'),
  style: ElevatedButton.styleFrom(backgroundColor: AppColors.brightYellow),
  onPressed: _addTask,
);

ElevatedButton(
  child: Text('Submit'),
  style: ElevatedButton.styleFrom(backgroundColor: AppColors.brightYellow),
  onPressed: _submitForm,
);
Correct Implementation (Follow this pattern):
Create a new widget: lib/core/widgets/primary_action_button.dart.
Use the new widget everywhere:
code
Dart
PrimaryActionButton(text: 'Add', onPressed: _addTask);
PrimaryActionButton(text: 'Submit', onPressed: _submitForm);
Directive 2.2: Extract Repeated Logic into Utility/Helper Functions.
If the same non-UI logic (e.g., data formatting, calculations) is used in more than one place, extract it into a function and place it in a relevant file within lib/core/utils/.
Example: The formatTime function is a perfect implementation of this rule. It is defined once in lib/utils/helpers.dart and used in multiple places (pomodoro_screen.dart, mini_timer_bar.dart). Always follow this pattern.
Law 3: The Law of Unambiguous Naming
Principle: Names must clearly and fully communicate the purpose of a variable, function, or class. The goal is zero ambiguity for a first-time reader. Do not use abbreviations or overly generic terms.
Directive 3.1: Name Widgets and Screens by Their Specific Role.
File and class names must be descriptive. This makes the project structure self-documenting.
Good Examples: TodoListScreen, TaskCard, InlineTaskInput, MiniTimerBar.
Unacceptable Examples: MainScreen, MyWidget, ListItem, Helper.
Directive 3.2: Name Functions and Methods by the Action They Perform.
Use a verbNoun() pattern. The name should describe what the function does.
Good Examples: _fetchTodos(), startTask(), markOverduePromptShown(), _showSessionCompletionDialog().
Unacceptable Examples: getData(), processInput(), handleIt(), showDialog().
Directive 3.3: Name State Variables by What They Represent.
Boolean variables must be prefixed with is, has, or should (e.g., isRunning, hasError). Variables representing a specific piece of state should be fully descriptive.
Good Examples: timeRemaining, activeTaskName, overdueCrossedTaskName, suppressNextActivation.
Unacceptable Examples: time, task, overdue, flag.




# MORE REFINEINE OF CODE _ ALWAYS APPLY AND FOLLOW THESE CODING PRACTICES - FOLLOW 4 PRINCPELS WHILE CODING  

NUMBER 1-  Excellent Separation of Concerns:

XMAPLE : UI (PomodoroScreen): Knows only how to display the state and forward user events (like button presses) to the notifier. It is "dumb" in the best way possible.
State Management (TimerNotifier): Contains all the business logic for the timer. It is the single source of truth for the timer's state and is completely independent of the UI.
Navigation (PomodoroRouter): Has the single responsibility of knowing how to present the Pomodoro screen (as a modal bottom sheet). The calling widgets don't need to know these details.
Services (ApiService, etc.): Abstract away external interactions like database calls and notifications.


NUMBER 2 Clear State Management (Riverpod):

The use of an immutable TimerState class with a copyWith method is best practice. It prevents accidental state mutation and makes state changes predictable.
The TimerNotifier cleanly exposes methods for specific actions (startTask, stopAndSaveProgress), which makes the code easy to reason about for both humans and AI.



NUMBER 3 : High Cohesion, Low Coupling:
Files within the features/pomodoro folder are highly related (high cohesion).
The pomodoro feature has minimal dependencies on the todo feature (low coupling). It receives a Todo object but doesn't need to know how the todo list is managed. This is excellent.


Suggestion for Even Better AI-Friendliness:
NUMBER 4 : Add Doc Comments (///): While the code is very readable, adding formal Dart doc comments to public methods in the notifiers (TimerNotifier, TodosNotifier) and services (ApiService) would be the final polish. Explain what each method does, its parameters, and what it returns. This provides invaluable context for an AI agent trying to understand the codebase's intent.