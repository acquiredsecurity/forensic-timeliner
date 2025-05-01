using System.Text.Json;
using System.Text.Json.Serialization;
using ForensicTimeliner.Models;

namespace ForensicTimeliner.Utils;

public static class JsonlExporter
{
    public static void ExportJsonl(List<TimelineRow> timeline, string outputPath)
    {
        using var writer = new StreamWriter(outputPath);

        foreach (var row in timeline)
        {
            var jsonlEvent = new
            {
                datetime = NormalizeDateTime(row.DateTime),
                timestamp_desc = row.TimestampInfo ?? "Unknown",
                message = BuildMessage(row),
                source_short = row.ArtifactName ?? "Unknown",
                source = row.Tool ?? "Unknown",
                hostname = row.Computer ?? "Unknown",
                user = row.User ?? "Unknown",
                extra = new
                {
                    DataPath = row.DataPath,
                    DataDetails = row.DataDetails,
                    EvidencePath = row.EvidencePath,
                    FileExtension = row.FileExtension,
                    EventId = row.EventId,
                    IPAddress = row.IPAddress,
                    SourceAddress = row.SourceAddress,
                    DestinationAddress = row.DestinationAddress,
                    SHA1 = row.SHA1,
                    FileSize = row.FileSize,
                    Count = row.Count
                }
            };

            var json = JsonSerializer.Serialize(jsonlEvent, new JsonSerializerOptions
            {
                DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
            });

            writer.WriteLine(json);
        }
    }

    private static string BuildMessage(TimelineRow row)
    {
        if (!string.IsNullOrWhiteSpace(row.Description) && !string.IsNullOrWhiteSpace(row.DataDetails))
        {
            return $"{row.Description} - {row.DataDetails}";
        }

        if (!string.IsNullOrWhiteSpace(row.Description))
        {
            return row.Description;
        }

        if (!string.IsNullOrWhiteSpace(row.DataPath))
        {
            return row.DataPath;
        }

        return "No message available";
    }

    private static string NormalizeDateTime(string dateTime)
    {
        if (string.IsNullOrWhiteSpace(dateTime))
            return "1970-01-01T00:00:00Z";

        if (DateTime.TryParse(dateTime, out var parsed))
        {
            return parsed.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ");
        }

        return "1970-01-01T00:00:00Z";
    }
}
