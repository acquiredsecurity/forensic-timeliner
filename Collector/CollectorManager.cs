// Utils/CollectorManager.cs

using ForensicTimeliner.CLI;
using ForensicTimeliner.Models;
using ForensicTimeliner.Utils;

namespace ForensicTimeliner.Collector;

public static class CollectorManager
{
    public static List<TimelineRow> GetAllRows(ParsedArgs args)
    {
        var allRows = new List<TimelineRow>();

        foreach (var def in DiscoveryConfig.ARTIFACT_DEFINITIONS.Values)
        {
            if (!ShouldProcessArtifact(def, args))
                continue;

            if (!DiscoveryConfig.ARTIFACT_PARSERS.TryGetValue(def.Artifact, out var parser))
            {
                Logger.LogError($"[!] No parser registered for: {def.Artifact}");
                continue;
            }

            try
            {
                var parsedRows = parser.Parse(args.BaseDir, args.BaseDir, def, args);

                if (args.StartDate.HasValue || args.EndDate.HasValue)
                    parsedRows = DateFilter.FilterByDateRange(parsedRows, args.StartDate, args.EndDate);

                var sanitizedRows = SanitizeRows(parsedRows);
                allRows.AddRange(sanitizedRows);
            }
            catch (Exception ex)
            {
                Logger.LogError($"[!] Error processing {def.Artifact}: {ex.Message}");
            }
        }

        return allRows;
    }

    private static bool ShouldProcessArtifact(ArtifactDefinition def, ParsedArgs args)
    {
        var tool = def.Tool.ToLower();
        return (tool.Contains("ez") && args.ProcessEZ) ||
               (tool.Contains("axiom") && args.ProcessAxiom) ||
               (tool.Contains("hayabusa") && args.ProcessHayabusa) ||
               (tool.Contains("chainsaw") && args.ProcessChainsaw) ||
               (tool.Contains("nirsoft") && args.ProcessNirsoft) ||
               args.ALL;
    }

    private static List<TimelineRow> SanitizeRows(List<TimelineRow> rows)
{
    List<TimelineRow> sanitized = new();

    foreach (var row in rows)
    {


        var sanitizedRow = new TimelineRow
        {
            DateTime = row.DateTime,
            TimestampInfo = SanitizeField(row.TimestampInfo),
            ArtifactName = SanitizeField(row.ArtifactName),
            Tool = SanitizeField(row.Tool),
            Description = SanitizeField(row.Description),
            DataDetails = SanitizeField(row.DataDetails),
            DataPath = SanitizeField(row.DataPath),
            FileExtension = SanitizeField(row.FileExtension),
            EventId = SanitizeField(row.EventId),
            User = SanitizeField(row.User),
            Computer = SanitizeField(row.Computer),
            FileSize = row.FileSize,
            IPAddress = SanitizeField(row.IPAddress),
            SourceAddress = SanitizeField(row.SourceAddress),
            DestinationAddress = SanitizeField(row.DestinationAddress),
            SHA1 = SanitizeField(row.SHA1),
            Count = SanitizeField(row.Count),
            EvidencePath = SanitizeField(row.EvidencePath),
            RawData = SanitizeField(row.RawData),
        };

        sanitized.Add(sanitizedRow);
    }

    return sanitized;
}


    private static string SanitizeField(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return string.Empty;

        if (value.Trim().ToLowerInvariant() == "nan")
            return string.Empty;

        return value
            .Replace("\r\n", " ") // Replace CRLF
            .Replace("\r", " ")   // Replace CR
            .Replace("\n", " ")   // Replace LF
            .Replace("\\", "/")   // Normalize backslashes to forward slashes
            .Replace("\"", "'")   // Replace double quotes with single quotes
            .Trim();
    }
}
