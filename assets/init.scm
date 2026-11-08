; Plugins
(require "forest/forest.scm")
(forest-configure! 'left)
(require "streal/streal.scm")
(require "steel-pty/term.scm")
(require "trail/trail.scm")
(require "showkeys/showkeys.scm")
(require "obelisk/obelisk.scm")
;Run on startup
(showkeys-toggle)
