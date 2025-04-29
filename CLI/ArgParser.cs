// CLI/ArgParser.cs
namespace ForensicTimeliner.CLI;

public class ParsedArgs
{
    public string BaseDir { get; set; } = "C:\\triage";
    public string? EZDirectory { get; set; }
    public string? ChainsawDirectory { get; set; }
    public string? HayabusaDirectory { get; set; }
    public string? NirsoftDirectory { get; set; }
    public string? AxiomDirectory { get; set; }
    public string? OutputFile { get; set; }
    public bool ProcessEZ { get; set; } = false;
    public bool ProcessChainsaw { get; set; } = false;
    public bool ProcessHayabusa { get; set; } = false;
    public bool ProcessNirsoft { get; set; } = false;
    public bool ProcessAxiom { get; set; } = false;
    public List<string> MFTExtensionFilter { get; set; } = new() { ".identifier", ".exe", ".ps1", ".zip", ".rar", ".7z" };
    public List<string> MFTPathFilter { get; set; } = new() { "Users" };
    public int BatchSize { get; set; } = 10000;
    public DateTime? StartDate { get; set; } = null;
    public DateTime? EndDate { get; set; } = null;
    public bool Deduplicate { get; set; } = false;
    public bool Interactive { get; set; } = false;
    public bool Preview { get; set; } = false;
    public bool ALL { get; set; } = false;
    public string ExportFormat { get; set; } = "csv";  // Default to CSV
    public string? LoadConfigOverride { get; set; }
    public bool Help { get; set; } = false;
    public bool NoBanner { get; set; } = false;
    public bool IncludeRawData { get; set; } = false;

}

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
                case "--StartDate": parsedArgs.StartDate = DateTime.Parse(args[++i]); break;
                case "--EndDate": parsedArgs.EndDate = DateTime.Parse(args[++i]); break;
                case "--ExportFormat":
                    parsedArgs.ExportFormat = args[++i].ToLower(); // Accepts "csv" or "json"
                    break;

                case "--ProcessEZ": parsedArgs.ProcessEZ = true; break;
                case "--ProcessChainsaw": parsedArgs.ProcessChainsaw = true; break;
                case "--ProcessHayabusa": parsedArgs.ProcessHayabusa = true; break;
                case "--ProcessNirsoft": parsedArgs.ProcessNirsoft = true; break;
                case "--ProcessAxiom": parsedArgs.ProcessAxiom = true; break;

                case "--Deduplicate":
                case "-d": parsedArgs.Deduplicate = true; break;
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

            }
        }
        return parsedArgs;
    }
}
