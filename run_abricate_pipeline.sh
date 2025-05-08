#!/bin/bash

# The script use abricate to screen contigs for AMR, virulence, and plasmid detection
# Databases used:
# AMR: resfinder, card, argannot, ncbi, megres
# Virulence: vfdb 
# Plasmid: plasmidfinder
#
# The script takes the input directory containing the fasta files either as an argument to the command
# or uses the default value hardcoded in the code. The script runs abricate on the fasta files with each
# databases as mentioned earlier and the outputs are stored in a dedicated folder named after the database.
# A summary file is also generated. One per database.


# Input directory (use first argument or default)
FASTA_FILE_LOC="${1:-"."}"
OUTPUT_LOG="output.log"
ERROR_LOG="error.log"

# Log output and errors into file
exec 1> "$OUTPUT_LOG" 2> "$ERROR_LOG"

# Validate input
echo "Validating input..."
if [ ! -d "$FASTA_FILE_LOC" ]; then
    echo "Error: Directory '$FASTA_FILE_LOC' does not exist"
    exit 1
fi

# Create array and then a directory of the type of detections as well as the abricate DBs to be used. 
DETECTION_TYPE=("AMR" "virulence" "plasmid")
AMR_DBS=("resfinder" "card" "argannot" "ncbi" "megares")
VIRULENCE_DBS=("vfdb")
PLASMID_DBS=("plasmidfinder")

# Unpack all the databases into a larger one.
ALL_DBS=("${AMR_DBS[@]}" "${VIRULENCE_DBS[@]}" "${PLASMID_DBS[@]}")


# Check and then setup abricate DBs
echo "Checking/setting up databases..."
for db in "${ALL_DBS[@]}"; do
    echo "  Checking $db..."
    if abricate --check --db "$db"; then
        echo "      $db is ready"
    else
        echo "      Setting up $db..."
        abricate --setupdb --db "$db"
    fi
done

# Iterate through the input directory and perform abricate on the fasta files
for FASTA_FILE in "${FASTA_FILE_LOC}"/*.fasta; do
    # Check if value is an actual file
    if [ ! -f "$FASTA_FILE" ]; then
        echo "$FASTA_FILE is not a fasta file. Skipping..."
        continue
    fi

    file_base_name=$(basename "$FASTA_FILE" .fasta)
    echo "Processing $file_base_name"
    echo $file_base_name >> "list.txt"
    
    # Process AMR databases
    for db in "${AMR_DBS[@]}"; do
        echo "Processing AMR analysis with $db"
	outdir="AMR/$db"
        mkdir -p "$outdir"
        abricate --db "$db" "$FASTA_FILE" > "$outdir/${file_base_name}.tsv"
    done

    # Process Virulence database
    for db in "${VIRULENCE_DBS[@]}"; do
        echo "Processing Virulence analysis with $db"
	outdir="Virulence/$db"
        mkdir -p "$outdir"
        abricate --db "$db" "$FASTA_FILE" > "$outdir/${file_base_name}.tsv"
    done

    # Process Plasmid database
    for db in "${PLASMID_DBS[@]}"; do
        echo "Processing Plasmid analysis with $db"
	outdir="Plasmid/$db"
        mkdir -p "$outdir"
        abricate --db "$db" "$FASTA_FILE" > "$outdir/${file_base_name}.tsv"
    done
done

# Create consolidated summaries for each DB
echo "Generating summaries..."
for detection_dir in "${DETECTION_TYPE[@]}"; do
    case $detection_dir in
        "AMR") dbs=("${AMR_DBS[@]}") ;;
        "Virulence") dbs=("${VIRULENCE_DBS[@]}") ;;
        "Plasmid") dbs=("${PLASMID_DBS[@]}") ;;
    esac

    for db in "${dbs[@]}"; do
        # Check if value is a directory, then proceed.
        if [ -d "$detection_dir/$db" ]; then
            outfile="$detection_dir/${db}_combined_summary.txt"
            tsv_files=("$detection_dir/$db"/*.tsv)  # Create an array of all the tsv files in there

            # Check if there the tsv files about actually exist. i.e. array > 0
            if [ ${#tsv_files[@]} -gt 0 ]; then
                echo "Summurasie results of $detection_dir"
		abricate --summary "$detection_dir/$db"/*.tsv > "$outfile"
            else
                echo "No results(tsv files) found for $db"
            fi
        fi
    done
done

echo "Pipeline completed successfully!"
