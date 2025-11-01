#!/usr/bin/env fish

# Function to say hello
function say_hello
    # Check if we have exactly one argument
    if test (count $argv) -ne 1
        echo "Please provide a name as parameter"
        return 1
    end
    
    # Get the name from the first argument
    set -l name $argv[1]
    echo "Hello, $name!"
end

# Call the function with the provided argument
if test (count $argv) -eq 0
    echo "Please provide a name as parameter"
    exit 1
end

say_hello $argv[1]
