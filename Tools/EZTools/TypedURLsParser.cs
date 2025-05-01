using CsvHelper;
using CsvHelper.Configuration;
using ForensicTimeliner.CLI;
using ForensicTimeliner.Interfaces;
using ForensicTimeliner.Models;
using ForensicTimeliner.Utils;
using Spectre.Console;
using System.Globalization;

namespace ForensicTimeliner.Tools.EZTools;

public class TypedURLsParser : IArtifactParser
{
    public List<TimelineRow> Parse(string inputDir, string baseDir, ArtifactDefinition artifact, ParsedArgs args)
    {
        var rows = new List<TimelineRow>();

        Logger.PrintAndLog($"[>] - [{artifact.Artifact}] Scanning for relevant CSVs under: [{inputDir}]", "SCAN");

        var files = Discovery.FindArtifactFiles(inputDir, baseDir, artifact.Artifact);
        if (!files.Any())
        {
            Logger.PrintAndLog($"[!] - [{artifact.Artifact}] No matching files found in: {inputDir}", "WARN");
            return rows;
        }

        foreach (var file in files)
        {
            int timelineCount = 0;
            Logger.PrintAndLog($"[+] - [{artifact.Artifact}] Processing: {Path.GetRelativePath(baseDir, file)}", "PROCESS");

            try
            {
                using var reader = new StreamReader(file);
                using var csv = new CsvReader(reader, new CsvConfiguration(CultureInfo.InvariantCulture)
                {
                    HeaderValidated = null,
                    MissingFieldFound = null
                });

                var records = csv.GetRecords<dynamic>();
                foreach (var record in records)
                {
                    var dict = (IDictionary<string, object>)record;
                    var parsedDt = dict.GetDateTime("Timestamp");
                    if (parsedDt == null) continue;

                    string dtStr = parsedDt.Value.ToString("o").Replace("+00:00", "Z");
                    string url = dict.GetString("Url");

                    rows.Add(new TimelineRow
                    {
                        DateTime = dtStr,
                        TimestampInfo = "Last Write",
                        ArtifactName = "Registry",
                        Tool = artifact.Tool,
                        Description = "Typed URL",
                        DataPath = url,
                        DataDetails = url,
                        EvidencePath = dict.GetString("BatchKeyPath"),
                        User = ExtractUserName(file),
                        IPAddress = ExtractHostFromUrl(url)
                    });

                    timelineCount++;
                }

                Logger.PrintAndLog($"[✓] - [{artifact.Artifact}] Parsed {timelineCount} timeline rows from: {Path.GetFileName(file)}", "SUCCESS");
                LoggerSummary.TrackSummary(artifact.Tool, artifact.Artifact, timelineCount);
            }
            catch (Exception ex)
            {
                Logger.PrintAndLog($"[{artifact.Artifact}] Failed to parse {file}: {ex.Message}", "ERROR");
            }
        }

        return rows;
    }

    // Helper method to extract username from the file path
    private string ExtractUserName(string filePath)
    {
        // Attempt to extract username from file path like:
        // 20250403121648_TypedURLs__C_Users_admin0x_NTUSER.DAT.csv
        string fileName = Path.GetFileNameWithoutExtension(filePath);

        int userIndex = fileName.IndexOf("_Users_");
        if (userIndex > 0)
        {
            int startIndex = userIndex + 7; // Length of "_Users_"
            int endIndex = fileName.IndexOf("_NTUSER", startIndex);
            if (endIndex > startIndex)
            {
                return fileName.Substring(startIndex, endIndex - startIndex);
            }
        }

        return "";
    }

    // Helper method to extract the host domain from a URL
    private string ExtractHostFromUrl(string url)
    {
        if (string.IsNullOrEmpty(url)) return "";

        try
        {
            // Try to parse the URL to get the host
            if (Uri.TryCreate(url, UriKind.Absolute, out Uri? uri) && uri != null)
            {
                return uri.Host;
            }
        }
        catch
        {
            // Ignore parsing errors
        }

        return "";
    }
}
