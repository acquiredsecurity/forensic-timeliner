using CsvHelper;
using CsvHelper.Configuration;
using ForensicTimeliner.Models;
using ForensicTimeliner.Interfaces;
using ForensicTimeliner.Models;
using ForensicTimeliner.Utils;
using Spectre.Console;
using System.Globalization;

namespace ForensicTimeliner.Tools.Axiom;

public class AxiomPrefetchParser : IArtifactParser
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

        var dateColumns = new List<(string ColumnName, string Label)>
        {
            ("File Created Date/Time - UTC+00:00 (M/d/yyyy)", "Source Created"),
            ("Last Run Date/Time - UTC+00:00 (M/d/yyyy)", "Last Run"),
            ("2nd Last Run Date/Time - UTC+00:00 (M/d/yyyy)", "Previous Run 1"),
            ("3rd Last Run Date/Time - UTC+00:00 (M/d/yyyy)", "Previous Run 2"),
            ("4th Last Run Date/Time - UTC+00:00 (M/d/yyyy)", "Previous Run 3"),
            ("5th Last Run Date/Time - UTC+00:00 (M/d/yyyy)", "Previous Run 4"),
            ("6th Last Run Date/Time - UTC+00:00 (M/d/yyyy)", "Previous Run 5"),
            ("7th Last Run Date/Time - UTC+00:00 (M/d/yyyy)", "Previous Run 6"),
            ("8th Last Run Date/Time - UTC+00:00 (M/d/yyyy)", "Previous Run 7"),
            ("Volume Created Date/Time - UTC+00:00 (M/d/yyyy)", "Volume Created")
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

                    foreach (var (col, label) in dateColumns)
                    {
                        var parsedDt = dict.GetDateTime(col);
                        if (parsedDt == null) continue;

                        string dtStr = parsedDt.Value.ToString("o").Replace("+00:00", "Z");

                        rows.Add(new TimelineRow
                        {
                            DateTime = dtStr,
                            TimestampInfo = label,
                            ArtifactName = "Prefetch",
                            Tool = artifact.Tool,
                            Description = "Program Execution",
                            DataPath = dict.GetString("Application Path"),
                            DataDetails = dict.GetString("Application Name"),
                            EvidencePath = Path.GetRelativePath(baseDir, file),
                            Count = dict.GetString("Application Run Count")
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

