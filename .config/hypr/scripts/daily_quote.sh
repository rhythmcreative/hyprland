#!/bin/bash

# Script para mostrar cita inspiracional diaria en hyprlock

# Motivational quotes in English
quotes=(
    "\"Creativity is intelligence having fun.\" - Albert Einstein"
    "\"Design is not just what it looks like and feels like. Design is how it works.\" - Steve Jobs"
    "\"Simplicity is the ultimate sophistication.\" - Leonardo da Vinci"
    "\"Good design is as little design as possible.\" - Dieter Rams"
    "\"The art challenges the technology, and the technology inspires the art.\" - John Lasseter"
    "\"Perfection is achieved, not when there is nothing more to add, but when there is nothing left to take away.\" - Antoine de Saint-Exupéry"
    "\"Everything you can imagine is real.\" - Pablo Picasso"
    "\"Innovation distinguishes between a leader and a follower.\" - Steve Jobs"
    "\"Code is poetry.\" - WordPress"
    "\"Make it as simple as possible, but not simpler.\" - Albert Einstein"
)

# Get day of the year for daily consistency (base 10 to avoid octal error with leading zeroes)
day_of_year=$((10#$(date +%j)))
# Use the day to select a consistent quote
quote_index=$((day_of_year % ${#quotes[@]}))

echo "${quotes[$quote_index]}"
