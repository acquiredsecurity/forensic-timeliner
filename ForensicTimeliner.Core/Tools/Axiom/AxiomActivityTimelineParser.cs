using CsvHelper;
using CsvHelper.Configuration;
using ForensicTimeliner.Models;
using ForensicTimeliner.Interfaces;
using ForensicTimeliner.Models;
using ForensicTimeliner.Utils;
using Spectre.Console;
using System.Globalization;

namespace ForensicTimeliner.Tools.Axiom;

public class AxiomActivityTimelineParser : IArtifactParser
{
    private static readonly Dictionary<string, string> TimestampFields = new()
    {
        { "Start Date/Time - UTC+00:00 (M/d/yyyy)", "Start Time" },
        { "End Date/Time - UTC+00:00 (M/d/yyyy)", "End Time" },
        { "Created Date/Time - UTC+00:00 (M/d/yyyy)", "Created" },
        { "Created In Cloud Date/Time - UTC+00:00 (M/d/yyyy)", "Cloud Created" },
        { "Last Modified Date/Time - UTC+00:00 (M/d/yyyy)", "Last Modified" },
        { "Last Modified On Client Date/Time - UTC+00:00 (M/d/yyyy)", "Client Modified" }
    };

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

                    foreach (var pair in TimestampFields)
                    {
                        var parsedDt = dict.GetDateTime(pair.Key);
                        if (parsedDt == null) continue;

                        string dtStr = parsedDt.Value.ToString("o").Replace("+00:00", "Z");

                        string dataPath = dict.GetString("Application Name");
                        if (string.IsNullOrWhiteSpace(dataPath))
                            dataPath = dict.GetString("Display Name");
                        if (string.IsNullOrWhiteSpace(dataPath))
                            dataPath = dict.GetString("Content");

                        string activityType = dict.GetString("Activity Type");

                        rows.Add(new TimelineRow
                        {
                            DateTime = dtStr,
                            TimestampInfo = pair.Value,
                            ArtifactName = "WindowsTimelineActivity",
                            Tool = artifact.Tool,
                            Description = $"{dataPath} + {activityType}".TrimEnd('+', ' '),
                            DataPath = dataPath,
                            DataDetails = activityType,
                            EvidencePath = Path.GetRelativePath(baseDir, file)
                        });

                        timelineCount++;
                    }
                }

                Logger.PrintAndLog($"[\u2713] - [{artifact.Artifact}] Parsed {timelineCount} timeline rows from: {Path.GetFileName(file)}", "SUCCESS");
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
