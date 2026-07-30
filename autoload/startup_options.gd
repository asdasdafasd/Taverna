extends Node
## Tiny cross-scene handoff: options chosen on the main menu that the game
## scene reads during [code]_ready[/code]. Autoload name:
## [code]StartupOptions[/code].

## When true, Main loads the quicksave right after the scene is ready.
var load_save_on_start: bool = false
