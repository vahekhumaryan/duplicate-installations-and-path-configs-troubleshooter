#!/bin/bash

# Function to check duplicates in standard paths
check_duplicates() {
    local paths=()  # Array to collect installation paths
    local found_path

    # Collect paths using 'which -a'
    while IFS= read -r line; do
        if [[ ! " ${paths[@]} " =~ " ${line} " ]]; then  # Check if path is already in array
            paths+=("$line")
        fi
    done < <(which -a $1 2>/dev/null)

    # Check additional common paths
    local additional_paths=("/usr/local/$1" "/opt/$1")
    for add_path in "${additional_paths[@]}"; do
        if [ -d "$add_path" ]; then
            while IFS= read -r line; do
                found_path="$add_path/$line"
                if [[ ! " ${paths[@]} " =~ " ${found_path} " ]]; then  # Check if path is already in array
                    paths+=("$found_path")
                fi
            done < <(ls "$add_path" 2>/dev/null)
        fi
    done

    # Format output for paths and versions
    if [ ${#paths[@]} -gt 0 ]; then
        printf "%-15s %-60s\n" "$1" "DETECTED" >> duplicates_report.txt
        for path in "${paths[@]}"; do
            local version_info=$("$path" --version 2>&1 | head -n 1)
            printf "%-15s %-60s\n" "" "$version_info $path" >> duplicates_report.txt
        done
    else
        printf "%-15s %-60s\n" "$1" "Not Found" >> duplicates_report.txt
    fi
}

# Clearing or creating the file
echo "Duplicate installations report" > duplicates_report.txt
date >> duplicates_report.txt
printf "%-15s %-60s\n" "Binary" "Status" >> duplicates_report.txt
echo "--------------------------------------------------------------------------------" >> duplicates_report.txt

# Default binaries to check if no arguments are provided
binaries=("npm" "node" "ruby" "gem" "java" "php" "perl" "go" "rustc" "cargo" "scala" "erl" "elixir" "brew" "mysql" "postgres" "httpd" "nginx" "redis-server" "python" "python3" "pip" "pip3")

# Check if arguments are provided and override defaults if so
if [ $# -ne 0 ]; then
    binaries=("$@")
fi

# Loop through all provided or default binaries
for bin in "${binaries[@]}"; do
    check_duplicates $bin
done

# Checking PATH conflicts
check_path_conflicts() {
    declare -A path_count
    IFS=':' read -ra ADDR <<< "$PATH"
    for path in "${ADDR[@]}"; do
        ((path_count["$path"]++))
    done
    for path in "${!path_count[@]}"; do
        if [ "${path_count[$path]}" -gt 1 ]; then
            printf "Duplicate PATH entry: %s\n" "$path" >> duplicates_report.txt
        fi
    done
}

# Add PATH configuration file info
echo "" >> duplicates_report.txt
echo "CHECKING USER AND SYSTEM-WIDE SHELL CONFIGURATION FILES FOR PATH SETTINGS:" >> duplicates_report.txt
config_files=(".bashrc" ".bash_profile" ".profile" ".bash_logout" ".zlogin" ".zlogout" ".cshrc" ".login" ".logout" ".tcshrc" ".kshrc" "/etc/bash.bashrc" "/etc/zsh/zshrc" "/etc/zsh/zprofile" "/etc/profile" "/etc/bashrc" ".zprofile" ".zshrc")

for file in "${config_files[@]}"; do
    if [[ "$file" == /* ]]; then
        file_path="$file"
    else
        file_path="$HOME/$file"
    fi
    if [ -f "$file_path" ]; then
        printf "%-20s %-20s\n" "$file_path" "exists" >> duplicates_report.txt
        grep 'PATH' "$file_path" | while read -r line; do
            printf "%-20s %-20s\n" "" "$line" >> duplicates_report.txt
        done
    else
        printf "%-20s %-20s\n" "$file_path" "not found" >> duplicates_report.txt
    fi
done
