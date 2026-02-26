using CsvHelper;
using CsvHelper.Configuration;
using ForensicTimeliner.Models;
using ForensicTimeliner.Interfaces;
using ForensicTimeliner.Models;
using ForensicTimeliner.Utils;
using Spectre.Console;
using System.Globalization;
using System.IO;
using System.Text.RegularExpressions; // Make sure this is included

namespace ForensicTimeliner.Tools.EZTools;

public class PrefetchParser : IArtifactParser
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

        // Regex pattern to match the volume prefix
        var volumePattern = @"\\VOLUME\{[^}]+\}\\";

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

                    var parsedDt = dict.GetDateTime("RunTime");
                    if (parsedDt == null) continue;

                    string dtStr = parsedDt.Value.ToString("o").Replace("+00:00", "Z");
                    string exe = dict.GetString("ExecutableName");

                    // Extract just the filename from the full path
                    string exeFileName = Path.GetFileName(exe);

                    // Remove the volume prefix pattern using regex
                    string cleanPath = Regex.Replace(exe, volumePattern, "", RegexOptions.IgnoreCase);

                    rows.Add(new TimelineRow
                    {
                        DateTime = dtStr,            // RunTime mapped to DateTime
                        TimestampInfo = "Run Time",
                        ArtifactName = artifact.Artifact,
                        Tool = artifact.Tool,
                        Description = artifact.Description,
                        DataPath = cleanPath,        // Path without volume prefix
                        DataDetails = exeFileName,   // Just the filename
                        EvidencePath = Path.GetRelativePath(baseDir, file)
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