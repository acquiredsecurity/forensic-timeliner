using CsvHelper;
using CsvHelper.Configuration;
using ForensicTimeliner.CLI;
using ForensicTimeliner.Interfaces;
using ForensicTimeliner.Models;
using ForensicTimeliner.Utils;
using Spectre.Console;
using System.Globalization;

namespace ForensicTimeliner.Tools.EZTools;

public class JumplistsParser : IArtifactParser
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

        var timestampFields = new Dictionary<string, string>
        {
            { "SourceCreated", "Source Created" },
            { "SourceModified", "Source Modified" },
            { "SourceAccessed", "Source Accessed" },
            { "CreationTime", "Target Created" },
            { "LastModified", "Target Modified" },
            { "TargetAccessed", "Target Accessed" },
            { "TrackerCreatedOn", "Tracker Created" }
        };

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

                    foreach (var pair in timestampFields)
                    {
                        var parsedDt = dict.GetDateTime(pair.Key);
                        if (parsedDt == null) continue;

                        string dtStr = parsedDt.Value.ToString("o").Replace("+00:00", "Z");

                        string dataPath = dict.GetString("Path");
                        string dataDetails = !string.IsNullOrWhiteSpace(dataPath) ? Path.GetFileName(dataPath) : string.Empty;
                        long fileSize = dict.GetLong("FileSize");

                        rows.Add(new TimelineRow
                        {
                            DateTime = dtStr,
                            TimestampInfo = pair.Value,
                            ArtifactName = "JumpLists",
                            Tool = artifact.Tool,
                            Description = artifact.Description,
                            DataDetails = dataDetails,
                            DataPath = dataPath,
                            FileSize = fileSize,
                            EvidencePath = Path.GetRelativePath(baseDir, file)
                        });

                        timelineCount++;
                    }
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
}
