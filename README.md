# BashReconGUI

A terminal-based GUI tool for performing passive and active reconnaissance on a specified target using popular command-line utilities.

---

## 📋 Features

- Interactive text-based GUI for input and control
- Passive Reconnaissance using:
  - `whois`
  - `dig`
  - `dnsenum`
  - `theHarvester`
- Active Reconnaissance using:
  - `nmap` (multiple scan types)
- Output is saved in timestamped directories under: ./guiActivePassiveRecon_scan_results/


---

## 📦 Requirements

- `bash` (v4+ recommended)
- `nmap`
- `whois`
- `dig` (part of `dnsutils`)
- `dnsenum`
- `theHarvester`

---

## ⚙️ Usage

./guiActivePassiveRecon.sh
Follow on-screen prompts to perform active/passive recon

---

## 📂  Output

guiActivePassiveRecon_scan_results/
  └── 2025-06-11_14-05-32/
        ├── whois_output.txt
        ├── nmap_scan.txt
        └── ...

Any tools which are exited mid-scan are still saved, but will appear as:
        ├── whois_output_skipped.txt
        ├── nmap_scan_skipped.txt 

---

## 🚀 Installation

Clone the repository:

```bash
git clone https://github.com/yourname/BashReconGUI.git
cd BashReconGUI
chmod +x guiActivePassiveRecon.sh

