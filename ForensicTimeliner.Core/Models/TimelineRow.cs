namespace ForensicTimeliner.Models;

public class TimelineRow
{
    public string DateTime { get; set; } = "";
    public string TimestampInfo { get; set; } = "";
    public string ArtifactName { get; set; } = "";
    public string Tool { get; set; } = "";
    public string Description { get; set; } = "";
    public string DataDetails { get; set; } = "";
    public string DataPath { get; set; } = "";
    public string FileExtension { get; set; } = "";
    public string EvidencePath { get; set; } = "";
    public string EventId { get; set; } = "";
    public string User { get; set; } = "";
    public string Computer { get; set; } = "";
    public long FileSize { get; set; } = 0;
    public string IPAddress { get; set; } = "";
    public string SourceAddress { get; set; } = "";
    public string DestinationAddress { get; set; } = "";
    public string SHA1 { get; set; } = "";
    public string Count { get; set; } = "";
    public string RawData { get; set; }

}

