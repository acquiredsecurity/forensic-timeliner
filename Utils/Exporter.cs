using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using CsvHelper;
using CsvHelper.Configuration;
using ForensicTimeliner.Interfaces;
using ForensicTimeliner.Models;

namespace ForensicTimeliner.Utils;

public static class Exporter
{
    private static readonly List<string> PreferredOrder = new()
    {
        "DateTime", "TimestampInfo", "ArtifactName", "Tool", "Description",
        "DataDetails", "DataPath", "FileExtension", "EventId",
        "User", "Computer", "FileSize", "IPAddress",
        "SourceAddress", "DestinationAddress", "SHA1", "Count",
        "EvidencePath", "RawData"
    };

    public static string Export(List<TimelineRow> data, string outputPath, string format)
    {
        if (data.Count == 0)
            return outputPath;

        var outputDir = Path.GetDirectoryName(outputPath);
        if (!string.IsNullOrWhiteSpace(outputDir) && !Directory.Exists(outputDir))
        {
            Directory.CreateDirectory(outputDir);
        }

        if (File.Exists(outputPath))
        {
            Console.WriteLine($"[#] File already exists. Deleting: {outputPath}", "WARN");
            File.Delete(outputPath);
        }

        if (format.Equals("csv", StringComparison.OrdinalIgnoreCase))
        {
            ExportCsv(data, outputPath);
        }
        else if (format.Equals("json", StringComparison.OrdinalIgnoreCase))
        {
            ExportJson(data, outputPath);
        }
        else if (format.Equals("jsonl", StringComparison.OrdinalIgnoreCase))
        {
            ExportJsonl(data, outputPath);
        }

        return outputPath;
    }

    private static void ExportCsv(List<TimelineRow> data, string outputPath)
    {
        using var writer = new StreamWriter(outputPath, false, new UTF8Encoding(false)) { NewLine = "\r\n" };
        using var csv = new CsvWriter(writer, new CsvConfiguration(CultureInfo.InvariantCulture)
        {
            Quote = '"',
            Delimiter = ",",
            Encoding = Encoding.UTF8,
            ShouldQuote = args => true,
            IgnoreBlankLines = false,
            TrimOptions = TrimOptions.None,
            Mode = CsvMode.NoEscape,
            MissingFieldFound = null,
            HeaderValidated = null
        });

        var allProperties = typeof(TimelineRow).GetProperties().Select(p => p.Name).ToList();
        var orderedColumns = PreferredOrder.Union(allProperties).ToList();

        foreach (var col in orderedColumns)
        {
            csv.WriteField(col);
        }
        csv.NextRecord();

        foreach (var row in data)
        {
            foreach (var col in orderedColumns)
            {
                var prop = typeof(TimelineRow).GetProperty(col);
                var val = prop?.GetValue(row)?.ToString() ?? "";

                if (col is "DataDetails" or "DataPath" or "Description" or "RawData")
                {
                    val = SanitizeCsvField(val);
                }

                if (col == "FileSize" && long.TryParse(val, out long fs) && fs == 0)
                {
                    val = "";
                }

                csv.WriteField(val);
            }
            csv.NextRecord();
        }

        Console.WriteLine($"[<] - Exported {data.Count} rows to {outputPath} (CSV)");
    }

    private static void ExportJson(List<TimelineRow> data, string outputPath)
    {
        var options = new JsonSerializerOptions
        {
            WriteIndented = true,
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
        };

        var json = JsonSerializer.Serialize(data, options);

        File.WriteAllText(outputPath, json, new UTF8Encoding(false));
        Console.WriteLine($"[<] - Exported {data.Count} rows to {outputPath} (JSON)");
    }

    private static void ExportJsonl(List<TimelineRow> data, string outputPath)
    {
        var utf8NoBom = new UTF8Encoding(encoderShouldEmitUTF8Identifier: false);

        using var fs = new FileStream(outputPath, FileMode.Create, FileAccess.Write, FileShare.None);
        using var writer = new StreamWriter(fs, utf8NoBom)
        {
            NewLine = "\n" // enforce LF line endings
        };

        var options = new JsonSerializerOptions
        {
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
        };

        foreach (var row in data)
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
                    Count = row.Count,
                    RawData = row.RawData
                }
            };

            var json = JsonSerializer.Serialize(jsonlEvent, options);
            writer.WriteLine(json);
        }

        Console.WriteLine($"[<] - Exported {data.Count} rows to {outputPath} (JSONL)");
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

        if (DateTime.TryParse(dateTime, CultureInfo.InvariantCulture,
            DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal, out var parsed))
        {
            return parsed.ToString("yyyy-MM-ddTHH:mm:ss.fffffffZ");
        }

        return "1970-01-01T00:00:00Z";
    }

    private static string SanitizeCsvField(string input)
    {
        if (string.IsNullOrEmpty(input))
            return "";

        if (input.Length > 10000)
        {
            input = input.Substring(0, 10000) + "...[truncated]";
        }

        input = input.Replace("\r", " ").Replace("\n", " ").Replace("\t", " ");
        input = input.Replace("\"", "\"\"");

        if (input.Contains(",") || input.Contains("\"") || input.Contains(" "))
        {
            input = $"\"{input}\"";
        }

        return input;
    }
}
