namespace ForensicTimeliner.Interfaces;

using ForensicTimeliner.Models;
using ForensicTimeliner.CLI;

public interface IArtifactParser
{
    List<TimelineRow> Parse(string inputDir, string baseDir, ArtifactDefinition artifact, ParsedArgs args);
}
