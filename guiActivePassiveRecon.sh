#!/bin/bash

# ---------------------- GUI Setup & Tool Check ----------------------#
GREEN="\033[0;32m"
RED="\033[0;31m"
BLUE="\033[0;34m"
NC="\033[0m" # No color

REQUIRED_TOOLS=("whois" "dig" "dnsenum" "theHarvester" "nmap")

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" > /dev/null 2>&1; then
        echo -e "${RED} Error: Required tool '${tool}' is not installed.${NC}"
        exit 1
    fi
done

# ---------------------- Generic Tool Status Function with Skip ----------------------#
# Usage:
#   run_tool_with_status "command args" output_file "Tool Name"
run_tool_with_status() {
    local cmd="$1"
    local output_file="$2"
    local tool_name="$3"

    SKIPPED=0  # Reset skip flag before starting this tool

    echo -e "${GREEN}Starting $tool_name...${NC}"

    # Run the command in background redirecting output to file
    bash -c "$cmd" > "$output_file" 2>&1 &
    local pid=$!

    while kill -0 "$pid" 2>/dev/null; do
        echo -e "${BLUE}$tool_name in progress... Press 's' + Enter to skip.${NC}"

        read -r -t 5 input
        if [[ "$input" == "s" || "$input" == "S" ]]; then
            kill "$pid" 2>/dev/null
            SKIPPED=1
            echo -e "${BLUE}Skipping $tool_name...${NC}"
            wait "$pid" 2>/dev/null
            break
        fi
    done

    if [[ $SKIPPED -eq 0 ]]; then
        wait "$pid"
        local status=$?
        if [[ $status -eq 0 ]]; then
            echo -e "${GREEN}$tool_name completed successfully.${NC}"
        else
            echo -e "${RED}$tool_name failed or was killed with exit code $status.${NC}"
        fi
    else
        # Rename the output file to *_skipped.txt
        if [[ -f "$output_file" ]]; then
            mv "$output_file" "${output_file%.txt}_skipped.txt"
        fi
    fi
}



# ---------------------- Get NMAP Scan Type Function ----------------------#
get_nmap_scan_type() {
    echo -e "${GREEN} Choose Nmap scan type(s) to run:"
    echo " 1) -sS (Stealth SYN Scan)"
    echo " 2) -sT (TCP Connect Scan)"
    echo " 3) -sU (UDP Scan)"
    echo " 4) -sV (Version Detection)"
    echo " 5) -O (OS Detection)"
    echo " 6) --script vuln (Vulnerability Scripts)"
    echo " 7) -sN (TCP Null Scan)"
    echo " 8) -A (Aggressive Scan)"
    echo " 9) -v (Verbose Mode)"
    echo "10) -T (Timing Template: 0-5)"
    echo "11) -p (Specify Ports)"
    echo -en "${BLUE} Enter choices separated by space (e.g., 1 4 6): ${NC}"
    read -r scan_choices

    NMAP_OPTIONS=""
    for choice in $scan_choices; do
        case $choice in
            1) NMAP_OPTIONS+=" -sS";;
            2) NMAP_OPTIONS+=" -sT";;
            3) NMAP_OPTIONS+=" -sU";;
            4) NMAP_OPTIONS+=" -sV";;
            5) NMAP_OPTIONS+=" -O";;
            6) NMAP_OPTIONS+=" --script vuln";;
            7) NMAP_OPTIONS+=" -sN";;
            8) NMAP_OPTIONS+=" -A";;
            9) NMAP_OPTIONS+=" -v";;
            10)
                echo -en "${GREEN}Enter timing value (0-5): ${NC}"
                read -r timing
                if [[ $timing =~ ^[0-5]$ ]]; then
                    NMAP_OPTIONS+=" -T$timing"
                else
                    echo -e "${RED}Invalid timing value.${NC}"
                fi
                ;;
            11)
                echo -en "${GREEN}Enter ports to scan (e.g., 22,80,443 or 1-1024): ${NC}"
                read -r ports
                NMAP_OPTIONS+=" -p $ports"
                ;;
            *) echo -e "${RED}Invalid option: $choice${NC}";;
        esac
    done
}

# ---------------------- NMAP Scan Output ----------------------#
nmap_scan() {
    echo -e "${GREEN}Starting Nmap scan on: ${BLUE}$1${NC}"
    mkdir -p "$OUTPUT_DIR/nmap_scan"

    get_nmap_scan_type
    echo -e "${GREEN}Running Nmap with options:${BLUE}$NMAP_OPTIONS${NC}"

    local nmap_output_file="$OUTPUT_DIR/nmap_scan/nmap.txt"
    local nmap_cmd="nmap $NMAP_OPTIONS \"$1\" -oN \"$nmap_output_file\""

    run_tool_with_status "$nmap_cmd" "$nmap_output_file" "Nmap Scan"
}

# ---------------------- Passive Recon Tool Selection ----------------------#
choose_passive_tools() {
    echo -e "${GREEN}Select Passive Recon tools to run (separate choices by space eg. 1 3 4):${NC}"
    echo " 1) WHOIS Lookup"
    echo " 2) DIG Lookup"
    echo " 3) DNSENUM (domain only)"
    echo " 4) theHarvester(domain only)"
    echo -en "${BLUE}Enter choices: ${NC}"
    read -r passive_choices

    # Convert to array for easier checks
    PASSIVE_SELECTION=()
    for choice in $passive_choices; do
        case $choice in
            1) PASSIVE_SELECTION+=("whois");;
            2) PASSIVE_SELECTION+=("dig");;
            3) PASSIVE_SELECTION+=("dnsenum");;
            4) PASSIVE_SELECTION+=("theHarvester");;
            *) echo -e "${RED}Invalid passive recon option: $choice${NC}";;
        esac
    done
}

# ---------------------- Passive Recon Function ----------------------#
passive_recon() {
    echo -e "${GREEN}Starting passive recon on: ${BLUE}$1${NC}"
    mkdir -p "$OUTPUT_DIR/passive_recon"

    for tool in "${PASSIVE_SELECTION[@]}"; do
        case $tool in
            whois)
                run_tool_with_status "whois \"$1\"" "$OUTPUT_DIR/passive_recon/whois.txt" "WHOIS Lookup"
                ;;
            dig)
                run_tool_with_status "dig \"$1\"" "$OUTPUT_DIR/passive_recon/dig.txt" "DIG Lookup"
                ;;
            dnsenum)
                if [[ "$1" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                    run_tool_with_status "dnsenum \"$1\"" "$OUTPUT_DIR/passive_recon/dnsenum.txt" "DNSENUM"
                else
                    echo -e "${RED}Skipping DNSENUM: not a valid domain.${NC}"
                fi
                ;;
            theHarvester)
                if [[ "$1" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                    run_tool_with_status "theHarvester -d \"$1\" -b bing -v" "$OUTPUT_DIR/passive_recon/theHarvester.txt" "theHarvester"
                else
                    echo -e "${RED}Skipping theHarvester: not a valid domain.${NC}"
                fi
                ;;
        esac
    done
}

# ---------------------- Select Target Type ----------------------#
while true; do
    echo -e  "${GREEN}Scan a ${BLUE}(N)etwork, ${BLUE}(H)ost, or ${BLUE}(D)omain?${NC}"
    read -r SCAN_TYPE

    case $SCAN_TYPE in
        [Nn])
            echo -e "${GREEN}Enter CIDR (e.g., 192.168.1.0/24):${NC}"
            read -r TARGET
            [[ -z "$TARGET" ]] && echo -e "${RED}Empty target.${NC}" && continue
            [[ "$TARGET" =~ ^[0-9.]+/[0-9]+$ ]] || { echo -e "${RED}Invalid CIDR.${NC}"; continue; }
            TARGET_TYPE="network"
            ;;
        [Hh])
            echo -e "${GREEN}Enter Host IP:${NC}"
            read -r TARGET
            [[ "$TARGET" =~ ^[0-9.]+$ ]] || { echo -e "${RED}Invalid IP.${NC}"; continue; }
            TARGET_TYPE="host"
            ;;
        [Dd])
            echo -e "${GREEN}Enter Domain name:${NC}"
            read -r TARGET
            [[ "$TARGET" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] || { echo -e "${RED}Invalid domain.${NC}"; continue; }
            TARGET_TYPE="domain"
            ;;
        *)
            echo -e "${RED}Invalid input.${NC}"
            continue
            ;;
    esac
    break
done

# ---------------------- Directory Setup ----------------------#
TOP_OUTPUT_DIR="./guiActivePassiveRecon_scan_results"
mkdir -p "$TOP_OUTPUT_DIR"
SANITIZED_TARGET=$(echo "$TARGET" | tr -s '.' '_' | tr '/' '_')
TIMESTAMP=$(date +%Y_%m_%d_%H_%M)
OUTPUT_DIR="$TOP_OUTPUT_DIR/scan_of_${SANITIZED_TARGET}_$TIMESTAMP"
mkdir -p "$OUTPUT_DIR"

# ---------------------- Passive Recon Selection ----------------------#
choose_passive_tools
if [ ${#PASSIVE_SELECTION[@]} -eq 0 ]; then
    echo -e "${BLUE}No passive recon tools selected. Skipping passive recon.${NC}"
else
    passive_recon "$TARGET"
fi

# ---------------------- NMAP Scan Prompt ----------------------#
echo -e "${GREEN}Perform NMAP scan? (Y/N)${NC}"
read -r RESP
if [[ "$RESP" =~ ^[Yy]$ ]]; then
    nmap_scan "$TARGET"
else
    echo -e "${BLUE}Skipping Nmap scan.${NC}"
fi

# ---------------------- Final Output & Validation ----------------------#
ABSOLUTE_OUTPUT_DIR=$(realpath "$OUTPUT_DIR")
echo -e "${GREEN}Scan complete. Results saved to: ${BLUE}$ABSOLUTE_OUTPUT_DIR${NC}"
