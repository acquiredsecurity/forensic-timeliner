namespace ForensicTimeliner.Models;

public class ParsedArgs
{
    public string BaseDir { get; set; } = "C:\\triage";
    public string? OutputFile { get; set; }
    public bool ProcessEZ { get; set; } = false;
    public bool ProcessChainsaw { get; set; } = false;
    public bool ProcessHayabusa { get; set; } = false;
    public bool ProcessNirsoft { get; set; } = false;
    public bool ProcessAxiom { get; set; } = false;
    public bool ProcessBrowserHistory { get; set; } = false;
    public bool ProcessEvtxForensic { get; set; } = false;
    public bool ProcessAS { get; set; } = false;
    public List<string> MFTExtensionFilter { get; set; } = new() { ".identifier", ".exe", ".ps1", ".zip", ".rar", ".7z" };
    public List<string> MFTPathFilter { get; set; } = new() { "Users" };
    public bool EnableTagger { get; set; } = false;
    public bool NoPrompt { get; set; } = false;

    public DateTime? StartDate { get; set; } = null;
    public DateTime? EndDate { get; set; } = null;
    public bool Deduplicate { get; set; } = false;
    public bool Interactive { get; set; } = false;
    public bool ALL { get; set; } = false;
    public string ExportFormat { get; set; } = "csv";
    public string? LoadConfigOverride { get; set; }
    public bool Help { get; set; } = false;
    public bool NoBanner { get; set; } = false;
    public bool IncludeRawData { get; set; } = false;
}
