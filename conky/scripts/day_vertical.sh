#!/bin/bash
# Returns uppercase day abbreviation split into individual vertical lines (e.g. M \n O \n N)
date +%^a | fold -w1 | head -n 3
