import argparse
from datetime import datetime

# Helper to parse ISO 8601 or simple date format
def parse_iso_datetime(d):
    try:
        return datetime.strptime(d, "%Y-%m-%dT%H:%M:%SZ")
    except ValueError:
        try:
            return datetime.strptime(d, "%Y-%m-%d")
        except ValueError:
            raise argparse.ArgumentTypeError(
                "Date must be in ISO 8601 format: YYYY-MM-DD or YYYY-MM-DDTHH:MM:SSZ"
            )

# This is your main argument parser setup
def parse_arguments():
    parser = argparse.ArgumentParser(description="Forensic Timeliner Python")

    parser.add_argument('--BaseDir', default='C:\\triage', help='Base directory for triage data')
    parser.add_argument('--EZDirectory', default=None, help='Directory for EZ Tools output (default = BaseDir\\kape_out)')
    parser.add_argument('--ChainsawDirectory', default=None)
    parser.add_argument('--HayabusaDirectory', default=None)
    parser.add_argument('--NirsoftDirectory', default=None)
    parser.add_argument('--AxiomDirectory', default=None)
    parser.add_argument('--OutputFile', default=None)
    parser.add_argument('--ExportFormat', choices=['csv', 'json', 'xlsx'], default='csv')
    parser.add_argument('--SkipEventLogs', action='store_true')
    parser.add_argument('--ProcessEZ', action='store_true')
    parser.add_argument('--ProcessChainsaw', action='store_true')
    parser.add_argument('--ProcessHayabusa', action='store_true')
    parser.add_argument('--ProcessAxiom', action='store_true')
    parser.add_argument('--ProcessNirsoftWebHistory', action='store_true')
    parser.add_argument('--FileDeletionSubDir', default='FileDeletion')
    parser.add_argument('--RegistrySubDir', default='Registry')
    parser.add_argument('--ProgramExecSubDir', default='ProgramExecution')
    parser.add_argument('--FileFolderSubDir', default='FileFolderAccess')
    parser.add_argument('--FileSystemSubDir', default='FileSystem')
    parser.add_argument('--EventLogsSubDir', default='EventLogs')
    parser.add_argument('--MFTExtensionFilter', nargs='+', default=[".identifier", ".exe", ".ps1", ".zip", ".rar", ".7z"])
    parser.add_argument('--MFTPathFilter', nargs='+', default=["Users", "tmp"])
    parser.add_argument('--BatchSize', type=int, default=10000)
    parser.add_argument('--StartDate', type=parse_iso_datetime, help="Format: YYYY-MM-DD or YYYY-MM-DDTHH:MM:SSZ (UTC)")
    parser.add_argument('--EndDate', type=parse_iso_datetime, help="Format: YYYY-MM-DD or YYYY-MM-DDTHH:MM:SSZ (UTC)")
    parser.add_argument('--Deduplicate', action='store_true')
    parser.add_argument('--Interactive', action='store_true', help='Enable interactive configuration mode')
    parser.add_argument('--Help', action='store_true')

    return parser.parse_args()
