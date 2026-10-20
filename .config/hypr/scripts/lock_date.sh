#!/bin/bash
lang=$(hypr-language 2>/dev/null || echo "es")
if [ "$lang" = "en" ]; then
    LC_TIME=en_US.UTF-8 date +"%A, %B %d"
else
    LC_TIME=es_ES.UTF-8 date +"%A, %d de %B"
fi
