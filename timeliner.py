import os
import sys
from cli.args import parse_arguments
from tools.ez_tools import amcache_parser, appcompat_parser, eventlog_parser, mft_parser 
from utils.export import export_to_csv
from ui.help import show_help
from datetime import datetime

def main():
    args = parse_arguments()

    if args.Help:
        show_help()
        return

    timeline_rows = []

    if args.ProcessEZ:
        amcache_parser.process_amcache(args.ProgramExecSubDir, args.BatchSize)
        appcompat_parser.process_appcompat(args.ProgramExecSubDir, args.BatchSize)
        eventlog_parser.process_eventlog(args.EventLogsSubDir, args.BatchSize)
        mft_parser.process_mft(args.FileSystemSubDir, args.BatchSize, args.MFTExtensionFilter, args.MFTPathFilter)
        

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
    main()