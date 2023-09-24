# Changelog

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
