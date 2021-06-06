TODO: Holidays (1-10th May)
===========================

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