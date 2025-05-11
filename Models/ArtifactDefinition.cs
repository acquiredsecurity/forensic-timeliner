// Models/ArtifactDefinition.cs
namespace ForensicTimeliner.Models;

public class ArtifactDefinition
{
    public string Artifact { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string Tool { get; set; } = string.Empty;
    public bool Enabled { get; set; } = true;
    public Filters Filters { get; set; } = new();
    public DiscoveryRule Discovery { get; set; } = new();
    public bool StrictFilenameMatch { get; set; } = true;
    public bool StrictFolderMatch { get; set; } = true;

    public bool IgnoreFilters { get; set; } = false;
    public Dictionary<string, string> TimestampFields { get; set; } = new();
    public Dictionary<string, List<int>> EventChannelFilters { get; set; } = new();
    


}

public class Filters
{
    public List<string> Extensions { get; set; } = new();
    public List<string> Paths { get; set; } = new();
    public Dictionary<string, List<int>> EventChannelFilters { get; set; } = new();
    public Dictionary<string, List<int>>? ProviderFilters { get; set; }

}


public class DiscoveryRule
{
    public List<string> FilenamePatterns { get; set; } = new();
    public List<string> FoldernamePatterns { get; set; } = new();
    public List<string> RequiredHeaders { get; set; } = new();
    public bool StrictFilenameMatch { get; set; }
    public bool StrictFolderMatch { get; set; }
    public bool StrictHeaderMatch { get; set; }
    

}
