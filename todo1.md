TODO: Holidays (1-10th May)
===========================

- [ ] `parseStruct` 
    - [ ] Actually parse body
        - [ ] Only allow variables declarations
            - [ ] Allow assignments I guess
        - [ ] Maybe function definitions too (D-kinda thing)
        - [ ] Add constructor support (initializes values)
            - [ ] I guess this is nicer when you have functions
            in the struct too to make initialization code more modular
    - [ ] Allow nested structs
- [ ] Note to self, `parseClass` and `parseStruct` should be way more specific and not just call `parseBody`
    - As currently one can then use `static` outside of these contexts
    - [ ] `parseStruct`
        - [ ]  Adding missing support for `static` in it
    - [ ] `parseClass`
        - [ ] Add this