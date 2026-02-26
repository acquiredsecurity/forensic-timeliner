using CsvHelper;
using CsvHelper.Configuration;
using ForensicTimeliner.Models;
using ForensicTimeliner.Interfaces;
using ForensicTimeliner.Models;
using ForensicTimeliner.Utils;
using Spectre.Console;
using System.Globalization;

namespace ForensicTimeliner.Tools.EZTools;

public class RegistryParser : IArtifactParser
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
                    var parsedDt = dict.GetDateTime("LastWriteTimestamp");
                    if (parsedDt == null) continue;

                    string dtStr = parsedDt.Value.ToString("o").Replace("+00:00", "Z");

                    string valueName = dict.GetString("ValueName");
                    string valueData1 = dict.GetString("ValueData");
                    string valueData2 = dict.GetString("ValueData2");
                    string valueData3 = dict.GetString("ValueData3");

                    string description = dict.GetString("Description");
                    string comment = dict.GetString("Comment");
                    string fullDescription = string.IsNullOrWhiteSpace(comment) ? description : $"{description} - {comment}";

                    string keyPath = dict.GetString("KeyPath");
                    string relativePath = Path.GetRelativePath(baseDir, file);
                    string evidencePath = string.IsNullOrWhiteSpace(keyPath) ? relativePath : $"{relativePath} | {keyPath}";

                    rows.Add(new TimelineRow
                    {
                        DateTime = dtStr,
                        TimestampInfo = "Last Write",
                        ArtifactName = "Registry",
                        Tool = artifact.Tool,
                        Description = fullDescription,
                        DataDetails = fullDescription,
                        DataPath = $"{valueName}\\{valueData1}\\{valueData2}\\{valueData3}",
                        EvidencePath = evidencePath
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
}
