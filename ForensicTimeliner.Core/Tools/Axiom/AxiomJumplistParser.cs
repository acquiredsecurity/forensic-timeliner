using CsvHelper;
using CsvHelper.Configuration;
using ForensicTimeliner.Models;
using ForensicTimeliner.Interfaces;
using ForensicTimeliner.Models;
using ForensicTimeliner.Utils;
using Spectre.Console;
using System.Globalization;

namespace ForensicTimeliner.Tools.Axiom;

public class AxiomJumpListsParser : IArtifactParser
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

                    var dateColumns = new Dictionary<string, string>
                    {
                        { "Target File Created Date/Time - UTC+00:00 (M/d/yyyy)", "Target Created" },
                        { "Target File Last Modified Date/Time - UTC+00:00 (M/d/yyyy)", "Target Modified" },
                        { "Target File Last Accessed Date/Time - UTC+00:00 (M/d/yyyy)", "Target Accessed" },
                        { "Last Access Date/Time - UTC+00:00 (M/d/yyyy)", "Source Accessed" }
                    };

                    foreach (var field in dateColumns)
                    {
                        var parsedDt = dict.GetDateTime(field.Key);
                        if (parsedDt == null) continue;

                        string dtStr = parsedDt.Value.ToString("o").Replace("+00:00", "Z");

                        // Determine best available DataPath
                        string target = dict.GetString("Linked Path") ??
                                        dict.GetString("Location") ??
                                        dict.GetString("Source") ?? "";

                        string details;
                        if (!string.IsNullOrWhiteSpace(target))
                        {
                            if (Path.HasExtension(target))
                            {
                                details = Path.GetFileName(target);
                            }
                            else
                            {
                                details = Path.GetFileName(Path.GetDirectoryName(target));
                            }
                        }
                        else
                        {
                            details = dict.GetString("Potential App Name");
                        }

                        rows.Add(new TimelineRow
                        {
                            DateTime = dtStr,
                            TimestampInfo = field.Value,
                            ArtifactName = "JumpLists",
                            Tool = artifact.Tool,
                            Description = "File & Folder Access",
                            DataPath = target,
                            DataDetails = details,
                            FileSize = dict.GetLong("Target File Size (Bytes)"),
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


