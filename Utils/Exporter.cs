// Utils/Exporter.cs
using System.Globalization;
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
            Console.WriteLine($"[!] File already exists. Deleting: {outputPath}");
            File.Delete(outputPath);
        }

        using var writer = new StreamWriter(outputPath);
        using var csv = new CsvWriter(writer, new CsvConfiguration(CultureInfo.InvariantCulture)
        {
            Quote = '"',
            Delimiter = ",",
            Encoding = System.Text.Encoding.UTF8,
            NewLine = "\r\n",
            ShouldQuote = args => true,
            IgnoreBlankLines = false,
            TrimOptions = TrimOptions.None,
            Mode = CsvMode.NoEscape,
            MissingFieldFound = null,
            HeaderValidated = null
        });

        var allProperties = typeof(TimelineRow).GetProperties().Select(p => p.Name).ToList();
        var orderedColumns = PreferredOrder.Union(allProperties).ToList();

        // Write Header
        foreach (var col in orderedColumns)
        {
            csv.WriteField(col);
        }
        csv.NextRecord();

        // Write Data
        foreach (var row in data)
        {
            foreach (var col in orderedColumns)
            {
                var prop = typeof(TimelineRow).GetProperty(col);
                var val = prop?.GetValue(row)?.ToString() ?? "";

                // Special handling for problematic fields
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
        return outputPath;
    }

  
    private static string SanitizeCsvField(string input)
    {
        if (string.IsNullOrEmpty(input))
            return "";

        // Truncate very large fields (optional, 10,000 characters max)
        if (input.Length > 10000)
        {
            input = input.Substring(0, 10000) + "...[truncated]";
        }

        // Replace CR, LF, and tabs with spaces
        input = input.Replace("\r", " ").Replace("\n", " ").Replace("\t", " ");

        // Escape quotes correctly by doubling them
        input = input.Replace("\"", "\"\"");

        // If field contains commas, quotes, spaces, wrap it in quotes
        if (input.Contains(",") || input.Contains("\"") || input.Contains(" "))
        {
            input = $"\"{input}\"";
        }

        return input;
    }
}
