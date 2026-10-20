#!/bin/bash

# Script para mostrar cita inspiracional diaria en hyprlock / lockscreen

lang=$(hypr-language 2>/dev/null || echo "es")

quotes_es=(
    "\"La creatividad es la inteligencia divirtiéndose.\" - Albert Einstein"
    "\"El diseño no es solo cómo se ve o cómo se siente. El diseño es cómo funciona.\" - Steve Jobs"
    "\"La simplicidad es la sofisticación suprema.\" - Leonardo da Vinci"
    "\"Un buen diseño es tan poco diseño como sea posible.\" - Dieter Rams"
    "\"El arte desafía a la tecnología, la tecnología inspira al arte.\" - John Lasseter"
    "\"La perfección se logra, no cuando no hay nada más que agregar, sino cuando no hay nada más que quitar.\" - Antoine de Saint-Exupéry"
    "\"Todo lo que puedas imaginar es real.\" - Pablo Picasso"
    "\"La innovación distingue entre un líder y un seguidor.\" - Steve Jobs"
    "\"El código es poesía.\" - WordPress"
    "\"Hazlo simple, pero no más simple.\" - Albert Einstein"
)

quotes_en=(
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

if [ "$lang" = "en" ]; then
    quotes=("${quotes_en[@]}")
else
    quotes=("${quotes_es[@]}")
fi

# Get day of the year for daily consistency (base 10 to avoid octal error with leading zeroes)
day_of_year=$((10#$(date +%j)))
quote_index=$((day_of_year % ${#quotes[@]}))

echo "${quotes[$quote_index]}"
