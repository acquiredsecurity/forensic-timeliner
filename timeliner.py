from args import parse_arguments
from ez_tools import amcache_parser, mft_parser
from ui.help import show_help
import sys

def main():
    args = parse_arguments()

    # Show help and exit if requested
    if args.Help:
        show_help()
        sys.exit(0)

    if args.ProcessEZ:
        amcache_parser.process_amcache(args)
        mft_parser.process_mft(args)

    # Add more processing calls as you build them out
    # if args.ProcessAxiom:
    #     axiom_parser.process_...()

if __name__ == "__main__":
    main()
