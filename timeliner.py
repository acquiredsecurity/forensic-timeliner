import os
import sys
from datetime import datetime
from cli.args import parse_arguments
from tools.ez_tools import (
    amcache_parser, appcompat_parser, deleted_parser, eventlog_parser,
    jumplist_parser, lnk_parser, mft_parser, prefetch_parser,
    registry_parser, shellbags_parser
)
from tools.axiom import amcache_parser_axiom
from tools.hayabusa import hayabusa_parser
from tools.nirsoft import browsinghistoryview_parser
from utils.export import export_to_csv
from ui.help import show_help
from ui.banner import print_banner
from ui.interactive import run_interactive_config
from collector.collector import get_all_rows


def resolve_output_path(output_arg: str) -> str:
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    if output_arg.lower().endswith(".csv"):
        return output_arg
    else:
        return os.path.join(output_arg, f"{timestamp}_forensic_timeliner.csv")


def setup_dual_logger(output_path: str):
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_name = f"{timestamp}_forensic_timeliner_log.txt"
    log_dir = os.path.dirname(output_path)
    log_path = os.path.join(log_dir, log_name)

    class TeeLogger:
        def __init__(self, file_path):
            self.terminal = sys.stdout
            self.log = open(file_path, "w", encoding="utf-8", errors="ignore")

        def write(self, message):
            self.terminal.write(message)
            self.log.write(message)

        def flush(self):
            self.terminal.flush()
            self.log.flush()

    sys.stdout = TeeLogger(log_path)
    print(f"[Log] Console output is being saved to: {log_path}")


def main():
    print_banner()
    args = parse_arguments()

    if args.ALL:
        args.ProcessEZ = True
        args.ProcessNirsoft = True
        args.ProcessHayabusa = True
        args.ProcessChainsaw = True
        args.ProcessAxiom = True

    if args.Interactive:
        print("[*] Launching interactive configuration...")
        interactive_config = run_interactive_config()
        for key, value in interactive_config.items():
            setattr(args, key, value)

    if args.Help:
        show_help()
        return

    # Set fallback input directories
    if args.ProcessEZ and not args.EZDirectory:
        args.EZDirectory = args.BaseDir
        print("[!] --EZDirectory not provided. Using --BaseDir.")
    if args.ProcessAxiom and not args.AxiomDirectory:
        args.AxiomDirectory = args.BaseDir
    if args.ProcessHayabusa and not args.HayabusaDirectory:
        args.HayabusaDirectory = args.BaseDir
    if args.ProcessNirsoft and not args.NirsoftDirectory:
        args.NirsoftDirectory = args.BaseDir

    # Resolve and set up logging
    final_output_path = resolve_output_path(args.OutputFile)
    setup_dual_logger(final_output_path)

    # Start processing artifacts
    if args.ProcessEZ:
        amcache_parser.process_amcache(args.EZDirectory, args.BatchSize, args.BaseDir)
        appcompat_parser.process_appcompat(args.EZDirectory, args.BatchSize, args.BaseDir)
        deleted_parser.process_deleted(args.EZDirectory, args.BatchSize, args.BaseDir)
        eventlog_parser.process_eventlog(args.EZDirectory, args.BatchSize, args.BaseDir)
        jumplist_parser.process_jumplists(args.EZDirectory, args.BatchSize, args.BaseDir)
        lnk_parser.process_lnk(args.EZDirectory, args.BatchSize, args.BaseDir)
        mft_parser.process_mft(args.EZDirectory, args.BatchSize, args.MFTExtensionFilter, args.MFTPathFilter)
        prefetch_parser.process_prefetch(args.EZDirectory, args.BatchSize, args.BaseDir)
        registry_parser.process_registry(args.EZDirectory, args.BatchSize, args.BaseDir)
        shellbags_parser.process_shellbags(args.EZDirectory, args.BatchSize, args.BaseDir)

    if args.ProcessAxiom:
        amcache_parser_axiom.process_amcache_axiom(args.AxiomDirectory, args.BatchSize, args.BaseDir)

    if args.ProcessHayabusa:
        hayabusa_parser.process_hayabusa(args.HayabusaDirectory, args.BatchSize, args.BaseDir)

    if args.ProcessNirsoft:
        browsinghistoryview_parser.process_browsinghistoryview(args.NirsoftDirectory, args.BatchSize, args.BaseDir)

    # Gather all processed timeline rows
    timeline_rows = get_all_rows()

    if timeline_rows:
        export_to_csv(timeline_rows, final_output_path)
        print(f"\n[✓] Combined timeline written to: {final_output_path}")
    else:
        print("[!] No timeline data was generated.")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n[!] Script interrupted by user. Exiting gracefully...")
