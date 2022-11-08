#!/bin/bash

function main {
	maim -s | xclip -selection clipboard -t image/png
}


main
