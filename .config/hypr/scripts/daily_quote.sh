#!/bin/bash

# Script para mostrar cita inspiracional diaria en hyprlock

# Array de citas motivacionales en español
quotes=(
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

# Obtener el día del año para consistencia diaria
day_of_year=$(date +%j)
# Usar el día para seleccionar una cita consistente
quote_index=$((day_of_year % ${#quotes[@]}))

echo "${quotes[$quote_index]}"
