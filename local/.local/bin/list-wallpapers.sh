#!/bin/bash
find -L "$1" -type f -regextype posix-extended -regex '.*\.(jpg|png|jpeg|gif|webp)'
