import os
import sys
from cli.args import parse_arguments
from tools.ez_tools import amcache_parser, appcompat_parser, deleted_parser, eventlog_parser, jumplist_parser, lnk_parser, mft_parser, prefetch_parser, registry_parser, shellbags_parser 
from tools.nirsoft import browsinghistoryview
from utils.export import export_to_csv
from ui.help import show_help
from ui.banner import print_banner
from ui.interactive import run_interactive_config
from datetime import datetime

def main():
    print_banner()
    args = parse_arguments()

    if args.Interactive:
        print("[*] Launching interactive configuration...")
        interactive_config = run_interactive_config()
        for key, value in interactive_config.items():
            setattr(args, key, value)

    if args.Help:
        show_help()
        return

    timeline_rows = []

    if args.ProcessEZ:
        amcache_parser.process_amcache(args.ProgramExecSubDir, args.BatchSize)
        appcompat_parser.process_appcompat(args.ProgramExecSubDir, args.BatchSize)
        deleted_parser.process_deleted(args.FileDeletionSubDir, args.BatchSize)
        eventlog_parser.process_eventlog(args.EventLogsSubDir, args.BatchSize)
        jumplist_parser.process_jumplists(args.FileFolderSubDir, args.BatchSize, args.BaseDir)
        lnk_parser.process_lnk(args.FileFolderSubDir, args.BatchSize, args.BaseDir)
        mft_parser.process_mft(args.FileSystemSubDir, args.BatchSize, args.MFTExtensionFilter, args.MFTPathFilter)
        prefetch_parser.process_prefetch(args.ProgramExecSubDir, args.BatchSize, args.BaseDir)
        registry_parser.process_registry(args.RegistrySubDir, args.BatchSize, args.BaseDir)
        shellbags_parser.process_shellbags(args.FileFolderSubDir, args.BatchSize, args.BaseDir)

    if args.ProcessNirsoft:
        browsinghistoryview.process_browsinghistoryview(args.NirsoftSubDir, args.BatchSize, args.BaseDir)    

    from collector.collector import get_all_rows
    timeline_rows = get_all_rows()    

    if timeline_rows:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_filename = f"{timestamp}_forensic_timeliner.csv"
        output_dir = os.path.dirname(args.OutputFile)
        final_output_path = os.path.join(output_dir, output_filename)

        export_to_csv(timeline_rows, final_output_path)
        print(f"Combined timeline written to: {final_output_path}")
    else:
        print("No timeline data was generated.")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n[!] Script interrupted by user. Exiting gracefully...")
