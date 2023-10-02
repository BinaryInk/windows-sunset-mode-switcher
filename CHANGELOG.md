# Changelog

## Version 3 - 2023-10-02

Version 2 never really worked as expected. I both over- and under-thought the problem.

- Parameter `-SetMode` added to set the theme mode
  - Bullet proof, more or less. Instead of messing with delays and depending on the script to fire at a time greater than another time, the switch makes it explicit. Running without the switch functions as it previously did and is used for the logon task.
  - Requires separate task scheduler tasks.
- Reverted back to using the current user account for the security principal.
  - Running as SYSTEM, the script as-written wasn't resetting the explorer process.
  - This means that the console window will flash when executed.
  - I'm eventually going to make a decision on how to handle refreshing the GUI. This may affect what I use for security principal.
- Added `-ExecutionPolicy Bypass` argument to task.
- Various syntax and style changes

## Version 2.1 - 2023-09-24

- Changed delay from 3 seconds to 1 minute; Task Scheduler does not count seconds when creating the trigger.
- Added SYSTEM Principal -- should make the action silent.
- Converged all the triggers to a single task (initially, I was thinking about passing values to the script in Actions but decided against)
- Cleaned up unused code, debug messages.

## Version 2 - 2023-09-24

- Name change to reflect what is actually being managed by the script (Theme **mode**, not the theme itself)
- Major re-write that makes the script automatic
  - Creates and updates scheduled tasks on execution, no manual setup.
- No longer uses registry
- No longer needs to be run continuously to check state
  - Primary tasks are updated on each execution.

## Version 1 - 2023-09-17

- Initial version. Required manually setting up a task to run the script every *n* minutes.
