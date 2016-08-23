#!/bin/bash

options=() #Buffer array for papameters
eoo=0

while [[ $1 ]]
do
    if ! ((eoo)); then
        case "$1" in
            -a)
                shift
                ;;
            --all)
                shift
                ;;
            --)
                eoo=1
                options+=("$1")
                shift
                ;;
            *)
                options+=("$1")
                shift
                ;;
        esac
    else
        options+=("$1")
    fi
done
/bin/ls "${options[@]}"
