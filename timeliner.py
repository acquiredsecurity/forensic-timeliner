# ─── Standard Library ────────────────────────────────────────────────
import os
import sys
from datetime import datetime
import pandas as pd


# ─── Third-Party Libraries ───────────────────────────────────────────
from rich import print as rprint



# ─── CLI & UI Modules ────────────────────────────────────────────────
from cli.args import parse_arguments
from ui.banner import print_banner
from ui.help import show_help
from ui.interactive import run_interactive_config

# ─── EZ Tools Parsers ────────────────────────────────────────────────
from tools.ez_tools import (
    amcache_parser, appcompat_parser, deleted_parser, eventlog_parser,
    jumplist_parser, lnk_parser, mft_parser, prefetch_parser,
    registry_parser, shellbags_parser
)

# ─── Axiom Parsers ───────────────────────────────────────────────────
from tools.axiom import (
    axiom_amcache_parser, axiom_appcompat_parser, axiom_autoruns_parser,
    axiom_chromehistory_parser, axiom_edge_parser, axiom_eventlog_parser, axiom_iehistory_parser, axiom_firefox_parser, axiom_jumplist_parser,
    axiom_lnk_parser, axiom_mrufolderaccess_parser, axiom_mruopensaved_parser,
    axiom_mrurecent_parser, axiom_opera_parser, axiom_prefetch_parser, axiom_recyclebin_parser,
    axiom_shellbags_parser, axiom_userassist_parser
)

# ─── Chainsaw Parsers ────────────────────────────────────────────────
from tools.chainsaw import (
    chainsaw_account_tampering_parser,
    chainsaw_antivirus_parser,
    chainsaw_applocker_parser,
    chainsaw_credential_access_parser,
    chainsaw_defense_evasion_parser,
    chainsaw_indicator_removal_parser,
    chainsaw_lateral_movement_parser,
    chainsaw_log_tampering_parser,
    chainsaw_login_attacks_parser,
    chainsaw_mft_parser,
    chainsaw_microsoft_rasvpn_events_parser,
    chainsaw_microsoft_rds_events_parser,
    chainsaw_persistence_parser,
    chainsaw_powershell_parser,
    chainsaw_rdp_events_parser,
    chainsaw_service_installation_parser,
    chainsaw_service_tampering_parser,
    chainsaw_sigma_parser
)


# ─── Hayabusa & Nirsoft Parsers ──────────────────────────────────────
from tools.hayabusa import hayabusa_parser
from tools.nirsoft import browsinghistoryview_parser

# ─── Utilities ───────────────────────────────────────────────────────
from utils.export import export_to_csv
from utils.logger import setup_logger, print_and_log
from utils.datefilter import filter_rows_by_date
from utils.config_override import load_config_override
from utils.config_export import export_default_config
from utils.summary import print_final_summary
from utils.dedupe import run_post_export_deduplication

# ─── Collector Function ───────────────────────────────────────────────────────
from collector.collector import get_all_rows


# Deupe functions
def normalize_value(val):
    if val is None or str(val).strip().lower() in ["none", "nan"]:
        return ""
    return str(val).strip().lower()

def deduplicate_rows(rows):
    print("[dedup.py] Using strict full-row dedup with normalization")
    seen = set()
    deduped = []
    for row in rows:
        normalized_row = {k: normalize_value(row.get(k)) for k in row.keys()}
        key = tuple((k, normalized_row[k]) for k in sorted(normalized_row.keys()))
        if key not in seen:
            seen.add(key)
            deduped.append(row)
    return deduped


#output path 

def resolve_output_path(output_arg: str) -> str:
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    if output_arg.lower().endswith(".csv"):
        return output_arg
    else:
        return os.path.join(output_arg, f"{timestamp}_forensic_timeliner.csv")

def main():
    args = parse_arguments()
    if not args.get("NoBanner", False):
        print_banner()
    

    if len(sys.argv) == 1:
        print("[*] No arguments provided. Launching Interactive Mode...")
        args["Interactive"] = True

    if args.get("Help"):
        show_help()
        return
    
    if args.get("ConfigExport"):
        export_default_config()
        return 

    if args.get("Interactive"):
        interactive_config = run_interactive_config()
        args.update(interactive_config)

       
    if args.get("LoadConfigOverride"):
        load_config_override(args["LoadConfigOverride"])    

    if args.get("BaseDir") and (args.get("Preview") or args.get("Interactive")):
        from utils.discovery_preview import run_discovery_preview
        run_discovery_preview(args["BaseDir"])
       

    # Only enforce --OutputFile if actual processing will run
    if (
        not args.get("OutputFile")
        and (
            args.get("ALL")
            or args.get("ProcessEZ")
            or args.get("ProcessAxiom")
            or args.get("ProcessChainsaw")
            or args.get("ProcessHayabusa")
            or args.get("ProcessNirsoft")
        )
    ):
        print("[!] --OutputFile not provided. Please specify an output path with --OutputFile")
        sys.exit(1)

    final_output_path = resolve_output_path(args["OutputFile"])
    output_dir = os.path.dirname(final_output_path)
    log_path = setup_logger(output_dir)

    if args.get("ALL"):
        args["ProcessEZ"] = True
        args["ProcessNirsoft"] = True
        args["ProcessHayabusa"] = True
        args["ProcessChainsaw"] = True
        args["ProcessAxiom"] = True

    # Set fallback input directories
    if args.get("ProcessEZ") and not args.get("EZDirectory"):
        args["EZDirectory"] = args["BaseDir"]
        print_and_log("[!] --EZDirectory not provided. Using --BaseDir.")

    if args.get("ProcessAxiom") and not args.get("AxiomDirectory"):
        args["AxiomDirectory"] = args["BaseDir"]
        print_and_log("[!] AxiomDirectory not provided. Using --BaseDir.")

    if args.get("ProcessHayabusa") and not args.get("HayabusaDirectory"):
        args["HayabusaDirectory"] = args["BaseDir"]
        print_and_log("[!] HayabusaDirectory not provided. Using --BaseDir.")
        
    if args.get("ProcessNirsoft") and not args.get("NirsoftDirectory"):
        args["NirsoftDirectory"] = args["BaseDir"]
        print_and_log("[!] NirsoftDirectory not provided. Using --BaseDir.")

    if args.get("ProcessChainsaw") and not args.get("ChainsawDirectory"):
        args["ChainsawDirectory"] = args["BaseDir"]
        print_and_log("[!] --ChainsawDirectory not provided. Using --BaseDir.")

   
   
    # Start processing artifacts
    if args.get("ProcessEZ"):
        amcache_parser.process_amcache(args["EZDirectory"], args["BatchSize"], args["BaseDir"])
        appcompat_parser.process_appcompat(args["EZDirectory"], args["BatchSize"], args["BaseDir"])
        deleted_parser.process_deleted(args["EZDirectory"], args["BatchSize"], args["BaseDir"])
        eventlog_parser.process_eventlog(args["EZDirectory"], args["BatchSize"], args["BaseDir"])
        jumplist_parser.process_jumplists(args["EZDirectory"], args["BatchSize"], args["BaseDir"])
        lnk_parser.process_lnk(args["EZDirectory"], args["BatchSize"], args["BaseDir"])
        mft_parser.process_mft(args["EZDirectory"], args["BatchSize"], args["BaseDir"], args["MFTExtensionFilter"], args["MFTPathFilter"])
        prefetch_parser.process_prefetch(args["EZDirectory"], args["BatchSize"], args["BaseDir"])
        registry_parser.process_registry(args["EZDirectory"], args["BatchSize"], args["BaseDir"])
        shellbags_parser.process_shellbags(args["EZDirectory"], args["BatchSize"], args["BaseDir"])

    if args.get("ProcessAxiom"):
        axiom_amcache_parser.process_axiom_amcache(args["AxiomDirectory"], args["BatchSize"], args["BaseDir"])
        axiom_appcompat_parser.process_axiom_appcompat(args["AxiomDirectory"], args["BatchSize"], args["BaseDir"])
        axiom_autoruns_parser.process_axiom_autoruns(args["AxiomDirectory"], args["BatchSize"], args["BaseDir"])
        axiom_chromehistory_parser.process_axiom_chromehistory(args["AxiomDirectory"], args["BatchSize"], args["BaseDir"])
        axiom_edge_parser.process_axiom_edge(args["AxiomDirectory"], args["BatchSize"], args["BaseDir"])
        axiom_eventlog_parser.process_axiom_eventlog(args["AxiomDirectory"], args["BatchSize"], args["BaseDir"])
        axiom_iehistory_parser.process_axiom_iehistory(args["AxiomDirectory"], args["BatchSize"], args["BaseDir"])
        axiom_firefox_parser.process_axiom_firefox(args["AxiomDirectory"], args["BatchSize"], args["BaseDir"])
        axiom_jumplist_parser.process_axiom_jumplist(args["AxiomDirectory"], args["BatchSize"], args["BaseDir"])
        axiom_lnk_parser.process_axiom_lnk(args["AxiomDirectory"], args["BatchSize"], args["BaseDir"])
        axiom_mrufolderaccess_parser.process_axiom_mrufolderaccess(args["AxiomDirectory"], args["BatchSize"], args["BaseDir"])
        axiom_mruopensaved_parser.process_axiom_mruopensaved(args["AxiomDirectory"], args["BatchSize"], args["BaseDir"])
        axiom_mrurecent_parser.process_axiom_mrurecent(args["AxiomDirectory"], args["BatchSize"], args["BaseDir"])
        axiom_opera_parser.process_axiom_opera(args["AxiomDirectory"], args["BatchSize"], args["BaseDir"])
        axiom_prefetch_parser.process_axiom_prefetch(args["AxiomDirectory"], args["BatchSize"], args["BaseDir"])
        axiom_recyclebin_parser.process_axiom_recyclebin(args["AxiomDirectory"], args["BatchSize"], args["BaseDir"])
        axiom_shellbags_parser.process_axiom_shellbags(args["AxiomDirectory"], args["BatchSize"], args["BaseDir"])
        axiom_userassist_parser.process_axiom_userassist(args["AxiomDirectory"], args["BatchSize"], args["BaseDir"])


    if args.get("ProcessHayabusa"):
        hayabusa_parser.process_hayabusa(args["HayabusaDirectory"], args["BatchSize"], args["BaseDir"])

    if args.get("ProcessChainsaw"):
        chainsaw_account_tampering_parser.process_chainsaw_account_tampering(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        chainsaw_antivirus_parser.process_chainsaw_antivirus(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        chainsaw_applocker_parser.process_chainsaw_applocker(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        chainsaw_credential_access_parser.process_chainsaw_credential_access(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        chainsaw_defense_evasion_parser.process_chainsaw_defense_evasion(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        chainsaw_indicator_removal_parser.process_chainsaw_indicator_removal(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        chainsaw_lateral_movement_parser.process_chainsaw_lateral_movement(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        chainsaw_log_tampering_parser.process_chainsaw_log_tampering(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        chainsaw_login_attacks_parser.process_chainsaw_login_attacks(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        chainsaw_microsoft_rasvpn_events_parser.process_chainsaw_microsoft_rasvpn_events(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        chainsaw_microsoft_rds_events_parser.process_chainsaw_microsoft_rds_events(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        chainsaw_persistence_parser.process_chainsaw_persistence(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        chainsaw_powershell_parser.process_chainsaw_powershell(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        chainsaw_rdp_events_parser.process_chainsaw_rdp_events(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        chainsaw_service_installation_parser.process_chainsaw_service_installation(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        chainsaw_service_tampering_parser.process_chainsaw_service_tampering(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        chainsaw_sigma_parser.process_chainsaw_sigma(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        chainsaw_mft_parser.process_chainsaw_mft(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])

            

    if args.get("ProcessNirsoft"):
        browsinghistoryview_parser.process_browsinghistoryview(args["NirsoftDirectory"], args["BatchSize"], args["BaseDir"])

    # Gather all processed timeline rows
    timeline_rows = get_all_rows()

    # Apply optional date filtering
    if args.get("StartDate") or args.get("EndDate"):
        before = len(timeline_rows)
        start = args.get("StartDate") or datetime.min
        end = args.get("EndDate") or datetime.max

        print_and_log(f"Filtering rows from {start} to {end}...")
        timeline_rows = filter_rows_by_date(timeline_rows, start, end)
        after = len(timeline_rows)
        print_and_log(f"Filtered out {before - after} rows outside date range.")

    if timeline_rows:
        export_to_csv(timeline_rows, final_output_path)
        rprint(f"[✓] Combined timeline written to: [bold green]{final_output_path}[/]")
        rprint(f"[✓] Log file written to: [bold yellow]{log_path}[/]")
    else:
        print("[!] No timeline data was generated.")



    if args.get("Deduplicate"):
        run_post_export_deduplication(final_output_path)

    print_final_summary()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n[!] Script interrupted by user. Exiting gracefully...")
