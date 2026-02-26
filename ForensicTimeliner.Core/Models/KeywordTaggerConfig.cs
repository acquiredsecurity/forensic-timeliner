namespace ForensicTimeliner.Models;

public class KeywordTaggerConfig
{
    public List<TagDefinition> Tags { get; set; } = new();
}

public class TagDefinition
{
    public string Label { get; set; } = string.Empty;
    public List<string> Keywords { get; set; } = new();
}
