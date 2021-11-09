Codegen TODO
============


When we linearise, before we process it. We have dependencies that don't
generate code in a linear way. An example of this would be function declarations.
These tehmselves don't do anything.

When we process such types we should obviousl dependency check them (which would be done
way before linearisaiton in any case) but we should not add them to the code quueue.

Or, wait, no, maybe we should, but they should be ordered as such that at the end we
group their instructions which are properly re-ordered in the codegen/typeChecker
under the emit for each function. This way we can add segments to the memory region for emitted code-per-function.



Just some notes and ideas.