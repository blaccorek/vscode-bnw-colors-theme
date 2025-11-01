#!/bin/bash

# Function to say hello
say_hello() {
    local name=$1
    echo "Hello, $name!"
}

# Check if a parameter was provided
if [ $# -eq 0 ]; then
    echo "Please provide a name as parameter"
    exit 1
fi

# Call the function with the first parameter
say_hello "$1"
