#!/bin/bash
for i in $(ls source/tlang/testing/*.t); do ./tlang compile $i 1> /dev/null; done
