// Tools/EZTools/ShellbagsParser.cs
using CsvHelper;
using CsvHelper.Configuration;
using ForensicTimeliner.CLI;
using ForensicTimeliner.Interfaces;
using ForensicTimeliner.Models;
using ForensicTimeliner.Utils;
using System.Globalization;

namespace ForensicTimeliner.Tools.EZTools;

public class ShellbagsParser : IArtifactParser
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
            Logger.PrintAndLog($"[+] - [{artifact.Artifact}] Processing: {Path.GetRelativePath(baseDir, file)}", "PROCESS");
            int timelineCount = 0;

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

                    var dateFields = new Dictionary<string, string>
                    {
                        { "LastWriteTime", "Last Write" },
                        { "FirstInteracted", "First Interacted" },
                        { "LastInteracted", "Last Interacted" }
                    };

                    foreach (var pair in dateFields)
                    {
                        if (!dict.ContainsKey(pair.Key)) continue;

                        string rawTs = dict[pair.Key]?.ToString() ?? "";
                        if (string.IsNullOrWhiteSpace(rawTs)) continue;
                        if (!DateTime.TryParse(rawTs, out DateTime dt)) continue;

                        string dtStr = dt.ToString("o").Replace("+00:00", "Z");

                        string absPath = dict.TryGetValue("AbsolutePath", out var ap) ? ap?.ToString() ?? "" : "";
                        string val = dict.TryGetValue("Value", out var valObj) ? valObj?.ToString() ?? "" : "";

                        rows.Add(new TimelineRow
                        {
                            DateTime = dtStr,
                            TimestampInfo = pair.Value,
                            ArtifactName = artifact.Artifact,
                            Tool = artifact.Tool,
                            Description = artifact.Description,
                            DataPath = absPath,
                            DataDetails = val,
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
