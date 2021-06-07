TODO List
=========

# Now

## Parsing

- [ ] `parseStruct` 
    - [x] Actually parse body
        - [x] Only allow variables declarations
            - [ ] Allow assignments I guess
        - [x] Maybe function definitions too (D-kinda thing)
        - [ ] Add constructor support (initializes values)
            - [ ] I guess this is nicer when you have functions
            in the struct too to make initialization code more modular
    - ~~[ ] Allow nested structs~~
        * Removed, why? That would be weird?
- [ ] Note to self, `parseClass` and `parseStruct` should be way more specific and not just call `parseBody`
    - As currently one can then use `static` outside of these contexts
    - [x] `parseStruct`
        - [x]  Adding missing support for `static` in it
    - [ ] `parseClass`
        - [ ] Add this

## Typechecking

- [ ] Dependency generation
    - [ ] Classes declared at the module level should be marked as static in `parse()`
        - [ ] `parseClass()` should not use
    - [ ] Structs declared at the module level should be marked as ~~marked~~ seen in `parse()` (not in `parseBody()` <- this is a note we don't do this)
    - [ ] Functions (?) declared at the module level should be ~~marked~~ seen as static in `parse()` (not in `parseBody()` <- this is a note we don't do this)
    - [ ] Variables declared at the module level should be marked as ~~marked~~ seen in `parse()` (not in `parseBody()` <- this is a note we don't do this)

# Future

- [ ] Make the compiler a library
    - [ ] Remove `exit` from `expect` and rather throw an error
    - [ ] Split it up into two projects with...
        - [ ] Library
        - [ ] Frontend interface
    - [ ] Publish to dub