using CsvHelper;
using CsvHelper.Configuration;
using ForensicTimeliner.Interfaces;
using ForensicTimeliner.Models;
using ForensicTimeliner.Utils;
using ConsoleProgress = Spectre.Console.Progress;
using System.Globalization;
using ForensicTimeliner.CLI;

namespace ForensicTimeliner.Tools.Hayabusa;

public class HayabusaParser : IArtifactParser
{
    private static readonly string[] FallbackTimestamps = [
        "timestamp", "datetime", "date", "time", "event_time", "eventtime"
    ];

    public List<TimelineRow> Parse(string inputDir, string baseDir, ArtifactDefinition artifact, ParsedArgs args)
    {
        var rows = new List<TimelineRow>();
        Logger.PrintAndLog($"[>] - [{artifact.Artifact}] Scanning for relevant CSVs under: [{inputDir}", "SCAN");

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
                ProgressUtils.ProcessCsvWithProgress(file, artifact.Artifact, (dict, task) =>
                {
                    string timestampKey = "Timestamp";

                    if (!dict.ContainsKey(timestampKey))
                    {
                        string? fallbackKey = FallbackTimestamps.FirstOrDefault(dict.ContainsKey);
                        if (string.IsNullOrEmpty(fallbackKey))
                        {
                            Logger.PrintAndLog($"[{artifact.Artifact}] Skipping row due to missing timestamp column in: {file}", "WARN");
                            return;  // Exit current lambda iteration safely
                        }

                        timestampKey = fallbackKey;
                    }

                    var parsedDt = dict.GetDateTime(timestampKey);
                    if (parsedDt == null) return;

                    string dtStr = parsedDt.Value.ToString("o").Replace("+00:00", "Z");

                    rows.Add(new TimelineRow
                    {
                        DateTime = dtStr,
                        TimestampInfo = "Event Time",
                        ArtifactName = "Event Logs",
                        Tool = artifact.Tool,
                        Description = dict.GetString("Channel"),
                        EventId = dict.GetString("EventID"),
                        DataPath = dict.GetString("Details"),
                        DataDetails = dict.GetString("RuleTitle"),
                        Computer = dict.GetString("Computer"),
                        EvidencePath = Path.GetRelativePath(baseDir, file)
                    });

                    timelineCount++;
                    task.Increment(1);
                });

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
