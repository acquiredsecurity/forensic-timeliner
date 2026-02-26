namespace ForensicTimeliner.Interfaces;

using ForensicTimeliner.Models;
using ForensicTimeliner.Models;

public interface IArtifactParser
{
    List<TimelineRow> Parse(string inputDir, string baseDir, ArtifactDefinition artifact, ParsedArgs args);
}
