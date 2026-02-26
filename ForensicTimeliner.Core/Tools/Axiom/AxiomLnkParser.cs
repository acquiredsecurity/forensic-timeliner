using CsvHelper;
using CsvHelper.Configuration;
using ForensicTimeliner.Models;
using ForensicTimeliner.Interfaces;
using ForensicTimeliner.Models;
using ForensicTimeliner.Utils;
using Spectre.Console;
using System.Globalization;

namespace ForensicTimeliner.Tools.Axiom;

public class AxiomLnkParser : IArtifactParser
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

        // Define all the date columns and corresponding labels
        var dateColumns = new Dictionary<string, string>
        {
            { "Created Date/Time - UTC+00:00 (M/d/yyyy)", "Source Created" },
            { "Last Modified Date/Time - UTC+00:00 (M/d/yyyy)", "Source Modified" },
            { "Accessed Date/Time - UTC+00:00 (M/d/yyyy)", "Source Accessed" },
            { "Target File Created Date/Time - UTC+00:00 (M/d/yyyy)", "Target Created" },
            { "Target File Last Modified Date/Time - UTC+00:00 (M/d/yyyy)", "Target Modified" },
            { "Target File Last Accessed Date/Time - UTC+00:00 (M/d/yyyy)", "Target Accessed" }
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

                    foreach (var field in dateColumns)
                    {
                        var parsedDt = dict.GetDateTime(field.Key);
                        if (parsedDt == null) continue;

                        string dtStr = parsedDt.Value.ToString("o").Replace("+00:00", "Z");


                        string dataPath = dict.GetString("Linked Path") ??
                                          dict.GetString("Source") ??
                                          dict.GetString("Location") ?? "";

                        string dataDetails;
                        if (!string.IsNullOrWhiteSpace(dataPath))
                        {
                            if (Path.HasExtension(dataPath))
                            {
                                dataDetails = Path.GetFileName(dataPath);
                            }
                            else
                            {
                                dataDetails = Path.GetFileName(Path.GetDirectoryName(dataPath));
                            }
                        }
                        else
                        {
                            dataDetails = "";
                        }

                        rows.Add(new TimelineRow
                        {
                            DateTime = dtStr,
                            TimestampInfo = field.Value,
                            ArtifactName = "LNK",
                            Tool = artifact.Tool,
                            Description = "File & Folder Access",
                            DataPath = dataPath,
                            DataDetails = dataDetails,
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
