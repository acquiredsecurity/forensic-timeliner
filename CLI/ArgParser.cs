// CLI/ArgParser.cs
using ForensicTimeliner.Models;

namespace ForensicTimeliner.CLI;

public static class ArgParser
{
    public static ParsedArgs Parse(string[] args)
    {
        var parsedArgs = new ParsedArgs();
        for (int i = 0; i < args.Length; i++)
        {
            switch (args[i])
            {
                case "--BaseDir": parsedArgs.BaseDir = args[++i]; break;
                case "--OutputFile": parsedArgs.OutputFile = args[++i]; break;
                case "--MFTExtensionFilter": parsedArgs.MFTExtensionFilter = args[++i].Split(',').ToList(); break;
                case "--MFTPathFilter": parsedArgs.MFTPathFilter = args[++i].Split(',').ToList(); break;
                case "--StartDate": parsedArgs.StartDate = DateTime.Parse(args[++i], System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.AssumeUniversal | System.Globalization.DateTimeStyles.AdjustToUniversal); break;
                case "--EndDate": parsedArgs.EndDate = DateTime.Parse(args[++i], System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.AssumeUniversal | System.Globalization.DateTimeStyles.AdjustToUniversal); break;
                case "--ExportFormat":
                    parsedArgs.ExportFormat = args[++i].ToLower(); // Accepts "csv" or "json"
                    break;

                case "--ProcessEZ": parsedArgs.ProcessEZ = true; break;
                case "--ProcessChainsaw": parsedArgs.ProcessChainsaw = true; break;
                case "--ProcessHayabusa": parsedArgs.ProcessHayabusa = true; break;
                case "--ProcessNirsoft": parsedArgs.ProcessNirsoft = true; break;
                case "--ProcessAxiom": parsedArgs.ProcessAxiom = true; break;
                case "--ProcessBrowserHistory": parsedArgs.ProcessBrowserHistory = true; break;
                case "--ProcessEvtxForensic": parsedArgs.ProcessEvtxForensic = true; break;
                case "--ProcessAS": parsedArgs.ProcessAS = true; break;
                case "--Deduplicate":
                case "-d": parsedArgs.Deduplicate = true; break;
                case "--EnableTagger": parsedArgs.EnableTagger = true;  break;
                case "--NoPrompt": parsedArgs.NoPrompt = true; break;
                case "--Interactive":
                case "--i":
                case "-i": parsedArgs.Interactive = true; break;
                case "--ALL":
                case "--a":
                case "-a": parsedArgs.ALL = true; break;
                case "--Help":
                case "--help":
                case "-h":
                case "--h":
                case "-H": parsedArgs.Help = true; break;
                case "--NoBanner": parsedArgs.NoBanner = true; break;
                case "--IncludeRawData": parsedArgs.IncludeRawData = true; break;
                case "--Silent": parsedArgs.NoBanner = true; parsedArgs.NoPrompt = true; break;

            }
        }
        return parsedArgs;
    }
}
