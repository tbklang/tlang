### Imports and modules

Most aspects of the parser are concerned with entities that are only ever created _within the parser_ itself. There is however, one case where this is not true. This is when dealing with `import` statements.

For such a feature such as module importing to work we need to have a way to manage what modules need be imported given a set of _already in-progress_ modules.