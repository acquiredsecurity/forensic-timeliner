import os
import sys
from datetime import datetime
import re
from cli.args import parse_arguments
from tools.ez_tools import (
    amcache_parser, appcompat_parser, deleted_parser, eventlog_parser,
    jumplist_parser, lnk_parser, mft_parser, prefetch_parser,
    registry_parser, shellbags_parser
)
from tools.axiom import amcache_parser_axiom
from tools.chainsaw import (
    antivirus_parser, applocker_parser, chainsaw_account_tampering_parser, chainsaw_persistence_parser, credential_access_parser,
    defense_evasion_parser, indicator_removal_parser, lateral_movement_parser, log_tampering_parser,
    login_attacks_parser, microsoft_rasvpn_events_parser, microsoft_rds_events_parser,
    mft_chainsaw_parser, powershell_parser, rdp_attacks_parser,
    service_installation_parser, service_tampering_parser, sigma_chainsaw_parser
)
from tools.hayabusa import hayabusa_parser
from tools.nirsoft import browsinghistoryview_parser
from utils.export import export_to_csv
from ui.help import show_help
from ui.banner import print_banner
from ui.interactive import run_interactive_config
from collector.collector import get_all_rows
from utils.logger import setup_logger, print_and_log, log_info
from utils.datefilter import filter_rows_by_date
from utils.dedup import deduplicate_rows
from rich import print as rprint


def resolve_output_path(output_arg: str) -> str:
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    if output_arg.lower().endswith(".csv"):
        return output_arg
    else:
        return os.path.join(output_arg, f"{timestamp}_forensic_timeliner.csv")

def main():
    print_banner()
    args = parse_arguments()

    if args.get("Help"):
        show_help()
        return

    if args.get("Interactive"):
        print("[*] Launching interactive configuration...")
        interactive_config = run_interactive_config()
        args.update(interactive_config)

    if not args.get("OutputFile"):
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
    # Set fallback input directories
    if args.get("ProcessEZ") and not args.get("EZDirectory"):
        args["EZDirectory"] = args["BaseDir"]
        print("[!] --EZDirectory not provided. Using --BaseDir.")

    if args.get("ProcessAxiom") and not args.get("AxiomDirectory"):
        args["AxiomDirectory"] = args["BaseDir"]

    if args.get("ProcessHayabusa") and not args.get("HayabusaDirectory"):
        args["HayabusaDirectory"] = args["BaseDir"]

    if args.get("ProcessNirsoft") and not args.get("NirsoftDirectory"):
        args["NirsoftDirectory"] = args["BaseDir"]

    if args.get("ProcessChainsaw") and not args.get("ChainsawDirectory"):
        args["ChainsawDirectory"] = args["BaseDir"]
        print("[!] --ChainsawDirectory not provided. Using --BaseDir.")

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
        amcache_parser_axiom.process_amcache_axiom(args["AxiomDirectory"], args["BatchSize"], args["BaseDir"])

    if args.get("ProcessHayabusa"):
        hayabusa_parser.process_hayabusa(args["HayabusaDirectory"], args["BatchSize"], args["BaseDir"])

    if args.get("ProcessChainsaw"):
        chainsaw_account_tampering_parser.process_chainsaw_account_tampering(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        antivirus_parser.process_antivirus(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        applocker_parser.process_applocker(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        credential_access_parser.process_credential_access(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        defense_evasion_parser.process_defense_evasion(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        indicator_removal_parser.process_indicator_removal(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        lateral_movement_parser.process_lateral_movement(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        log_tampering_parser.process_log_tampering(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        login_attacks_parser.process_login_attacks(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        microsoft_rasvpn_events_parser.process_microsoft_rasvpn_events(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        microsoft_rds_events_parser.process_microsoft_rds_events(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        chainsaw_persistence_parser.process_chainsaw_persistence(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        powershell_parser.process_powershell(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        rdp_attacks_parser.process_rdp_attacks(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        service_installation_parser.process_service_installation(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        service_tampering_parser.process_service_tampering(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        sigma_chainsaw_parser.process_chainsaw_sigma(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
        mft_chainsaw_parser.process_mft_chainsaw(args["ChainsawDirectory"], args["BatchSize"], args["BaseDir"])
            

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

    # Apply deduplication if enabled
    if args.get("Deduplicate"):
        print_and_log("Applying deduplication based on all timeline fields...")
        before = len(timeline_rows)
        timeline_rows = deduplicate_rows(timeline_rows)
        after = len(timeline_rows)
        print_and_log(f"Deduplicated {before - after} rows (final count: {after})")

    if timeline_rows:
        export_to_csv(timeline_rows, final_output_path)
        rprint(f"[✓] Combined timeline written to: [bold green]{final_output_path}[/]")
        rprint(f"[✓] Log file written to: [bold yellow]{log_path}[/]")
    else:
        print("[!] No timeline data was generated.")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n[!] Script interrupted by user. Exiting gracefully...")
