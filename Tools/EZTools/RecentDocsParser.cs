using CsvHelper;
using CsvHelper.Configuration;
using ForensicTimeliner.CLI;
using ForensicTimeliner.Interfaces;
using ForensicTimeliner.Models;
using ForensicTimeliner.Utils;
using Spectre.Console;
using System.Globalization;

namespace ForensicTimeliner.Tools.EZTools;

public class RecentDocsParser : IArtifactParser
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

                    // Try OpenedOn first, then ExtensionLastOpened - either could be the timestamp
                    var parsedDt = dict.GetDateTime("OpenedOn");
                    var timestampInfo = "Last Opened";

                    if (parsedDt == null)
                    {
                        parsedDt = dict.GetDateTime("ExtensionLastOpened");
                        timestampInfo = "Extension Last Opened";

                        // Skip if both date fields are null
                        if (parsedDt == null) continue;
                    }

                    string dtStr = parsedDt.Value.ToString("o").Replace("+00:00", "Z");

                    rows.Add(new TimelineRow
                    {
                        DateTime = dtStr,
                        TimestampInfo = timestampInfo,
                        ArtifactName = "Registry",
                        Tool = artifact.Tool,
                        Description = artifact.Description,
                        DataDetails = dict.GetString("TargetName"),
                        DataPath = dict.GetString("LnkName"),
                        EvidencePath = dict.GetString("BatchKeyPath"),
                        FileExtension = dict.GetString("Extension"),
                        Computer = ExtractComputerName(file)
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

    // Helper method to extract computer name from the file path
    private string ExtractComputerName(string filePath)
    {
        // Attempt to extract computer name from file path like:
        // 20250403121648_RecentDocs__C_Users_arnolds_NTUSER.DAT.csv
        string fileName = Path.GetFileNameWithoutExtension(filePath);

        int userIndex = fileName.IndexOf("_Users_");
        if (userIndex > 0)
        {
            int startIndex = userIndex + 7; // Length of "_Users_"
            int endIndex = fileName.IndexOf("_", startIndex);
            if (endIndex > startIndex)
            {
                return fileName.Substring(startIndex, endIndex - startIndex);
            }
        }

        return "";
    }
}